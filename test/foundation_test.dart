import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mii_mesh/core/crypto/vault.dart';
import 'package:mii_mesh/core/database/database.dart';
import 'package:mii_mesh/core/protocol/envelope.dart';
import 'package:mii_mesh/features/chats/chat_service.dart';
import 'package:mii_mesh/transports/fake/fake_transport.dart';
import 'package:sodium/sodium.dart';

import 'support.dart';

Uint8List unhex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);

void main() {
  late Sodium sodium;
  setUpAll(() async {
    sodium = await SodiumInit.init();
  });

  test('Ed25519 RFC 8032 test vector 1: public key and signature', () {
    final seed = sodium.secureCopy(
      unhex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'),
    );
    final pair = sodium.crypto.sign.seedKeyPair(seed);
    try {
      expect(
        pair.publicKey,
        unhex(
          'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
        ),
      );
      final signature = sodium.crypto.sign.detached(
        message: Uint8List(0),
        secretKey: pair.secretKey,
      );
      expect(
        signature,
        unhex(
          'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555f'
          'b8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
        ),
      );
      expect(
        sodium.crypto.sign.verifyDetached(
          signature: signature,
          message: Uint8List(0),
          publicKey: pair.publicKey,
        ),
        isTrue,
      );
      expect(
        sodium.crypto.sign.verifyDetached(
          signature: signature,
          message: Uint8List.fromList([1]),
          publicKey: pair.publicKey,
        ),
        isFalse,
      );
    } finally {
      seed.dispose();
      pair.secretKey.dispose();
    }
  });

  test('Identity and database key persist; missing key fails closed', () async {
    final store = MemorySecretStore();
    final vault = Vault(sodium, store);
    expect(
      await vault.identityPublicKey(),
      await Vault(sodium, store).identityPublicKey(),
    );
    expect(
      vault.fingerprint(await vault.identityPublicKey()).split(' '),
      hasLength(8),
    );
    final key = await vault.databaseKey(databaseExists: false);
    expect(await vault.databaseKey(databaseExists: true), key);
    store.values.remove('database');
    await expectLater(
      vault.databaseKey(databaseExists: true),
      throwsStateError,
    );
  });

  test(
    'Authenticated envelope, duplicate suppression, bound acknowledgement',
    () async {
      final key = sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
      final transport = FakeTransport(sodium, key);
      await transport.connect();
      var envelope = Envelope(
        id: '019932ab-7b10-7000-8000-000000000001',
        sender: 'a' * 64,
        recipient: 'laboratory',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
        sequence: 1,
        nonce: base64Encode(sodium.randombytes.buf(24)),
        ciphertext: '',
      );
      envelope = envelope.copyWith(
        ciphertext: base64Encode(
          sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
            message: Uint8List.fromList(utf8.encode('private content')),
            nonce: base64Decode(envelope.nonce),
            key: key,
            additionalData: envelope.additionalData,
          ),
        ),
      );
      final received = <Uint8List>[];
      final subscription = transport.receiveEnvelopes.listen(received.add);
      final ack = await transport.sendEnvelope(envelope.encode());
      await transport.sendEnvelope(envelope.encode());
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      expect(transport.verifyAck(envelope, ack), isTrue);
      expect(transport.verifyAck(envelope.copyWith(sequence: 2), ack), isFalse);
      expect(
        utf8.decode(envelope.encode(), allowMalformed: true),
        isNot(contains('private content')),
      );
      expect(
        Envelope.decode(
          envelope.encode(),
          DateTime.now().millisecondsSinceEpoch,
        ),
        envelope,
      );
      await expectLater(
        transport.sendEnvelope(envelope.copyWith(sequence: 2).encode()),
        throwsA(anything),
      );
      final altered = base64Decode(envelope.ciphertext)..[0] ^= 1;
      await expectLater(
        transport.sendEnvelope(
          envelope.copyWith(ciphertext: base64Encode(altered)).encode(),
        ),
        throwsA(anything),
      );
      expect(
        () => Envelope.decode(
          envelope.copyWith(hops: 4).encode(),
          DateTime.now().millisecondsSinceEpoch,
        ),
        throwsFormatException,
      );
      expect(
        () => Envelope.decode(envelope.encode(), envelope.expiresAt),
        throwsFormatException,
      );
      await subscription.cancel();
      await transport.dispose();
    },
  );

  test(
    'Parser rejects nesting, huge lengths, trailing bytes and randomized input',
    () {
      final random = Random(42);
      final malformed = [
        Uint8List.fromList([0x8c, 0x9f]),
        Uint8List.fromList([0x8c, 0x7b, ...List.filled(8, 255)]),
        Uint8List(4097),
      ];
      for (var i = 0; i < 1500; i++) {
        malformed.add(
          Uint8List.fromList(
            List.generate(random.nextInt(500), (_) => random.nextInt(256)),
          ),
        );
      }
      for (final bytes in malformed) {
        expect(() => Envelope.decode(bytes, 100), throwsFormatException);
      }
    },
  );

  test(
    'Encrypted schema v1, draft and outbox survive restart; resume and expiry',
    () async {
      final directory = await Directory.systemTemp.createTemp('mii-test-');
      final file = File('${directory.path}/vault.sqlite');
      final store = MemorySecretStore();
      final vault = Vault(sodium, store);
      final key = await vault.databaseKey(databaseExists: false);
      Future<ChatService> reopen() async {
        final service = ChatService(
          MeshDatabase.encrypted(file, key),
          vault,
          FakeTransport(sodium, await vault.laboratoryKey()),
        );
        await service.initialize(startTimer: false);
        return service;
      }

      var service = await reopen();
      try {
        await service.createIdentity('Test identity');
        await service.send('notes', 'TOP_SECRET_NOTE_76543');
        await service.saveDraft('notes', 'surviving draft');
        await service.enableLaboratory();
        await service.setLaboratoryConnected(false);
        await service.send('laboratory', 'queued private text');
        expect(service.queuedCount, 1);
        final id = service.messages.last.id;
        final fingerprint = service.fingerprint;
        await service.close();
        expect(
          utf8.decode(await file.readAsBytes(), allowMalformed: true),
          isNot(contains('TOP_SECRET_NOTE_76543')),
        );
        expect(
          (await file.readAsBytes()).take(15).toList(),
          isNot(utf8.encode('SQLite format 3')),
        );
        service = await reopen();
        expect(service.fingerprint, fingerprint);
        expect(
          service.conversations.firstWhere((c) => c.id == 'notes').draft,
          'surviving draft',
        );
        expect(service.queuedCount, 1);
        await service.setLaboratoryConnected(true);
        expect(
          service.messages.firstWhere((m) => m.id == id).status,
          'delivered',
        );
        await service.pump();
        expect(service.messages.where((m) => m.id == id), hasLength(1));
        expect(await service.db.select(service.db.outbox).get(), isEmpty);
        await service.db.purgeExpired(
          DateTime.now().millisecondsSinceEpoch + 86400001,
        );
        await service.refresh();
        expect(service.messages, hasLength(1));
        expect(service.messages.single.conversationId, 'notes');
        expect(
          (await service.db.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          2,
        );
        await service.close();
        final wrong = MeshDatabase.encrypted(file, '0' * 64);
        await expectLater(
          wrong.select(wrong.profiles).get(),
          throwsA(anything),
        );
        await wrong.close();
        service = await reopen();
      } finally {
        await service.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('Retry backoff is bounded and has jitter', () {
    for (var i = 0; i < 30; i++) {
      expect(
        ChatService.retryDelay(i, Random(i)).inMilliseconds,
        inInclusiveRange(1000, 60999),
      );
    }
    expect(
      ChatService.retryDelay(2, Random(1)),
      isNot(ChatService.retryDelay(2, Random(2))),
    );
  });
}
