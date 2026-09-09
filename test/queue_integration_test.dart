import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mii_mesh/core/crypto/vault.dart';
import 'package:mii_mesh/core/database/database.dart';
import 'package:mii_mesh/features/chats/chat_service.dart';
import 'package:mii_mesh/transports/fake/fake_transport.dart';
import 'package:sodium/sodium.dart';

import 'support.dart';

class CorruptAckTransport extends FakeTransport {
  CorruptAckTransport(super.sodium, super.key, this.db);
  final MeshDatabase db;
  bool corrupt = true;
  bool observedPersistedBeforeSend = false;
  @override
  Future<Uint8List> sendEnvelope(Uint8List bytes) async {
    observedPersistedBeforeSend =
        (await db.select(db.outbox).get()).isNotEmpty &&
        (await db.select(db.messages).get()).any((m) => m.status == 'queued');
    final ack = await super.sendEnvelope(bytes);
    if (corrupt) ack[24] ^= 1;
    return ack;
  }
}

void main() {
  late ChatService service;
  late CorruptAckTransport transport;
  setUp(() async {
    final sodium = await SodiumInit.init();
    final vault = Vault(sodium, MemorySecretStore());
    final db = MeshDatabase(NativeDatabase.memory());
    transport = CorruptAckTransport(sodium, await vault.laboratoryKey(), db);
    service = ChatService(db, vault, transport);
    await service.createIdentity('Queue tester');
    await service.enableLaboratory();
  });
  tearDown(() => service.close());

  test(
    'Invalid acknowledgements never deliver; bounded retry and manual recovery',
    () async {
      await service.send('laboratory', 'Message written before transport');
      expect(transport.observedPersistedBeforeSend, isTrue);
      expect(service.messages.single.status, 'queued');
      for (var i = 0; i < 4; i++) {
        await service.db
            .update(service.db.outbox)
            .write(const OutboxCompanion(nextAttempt: Value(0)));
        await service.pump();
      }
      expect(service.messages.single.status, 'failed');
      expect(
        (await service.db.select(service.db.outbox).get()).single.attempts,
        5,
      );
      await service.pump();
      expect(service.messages.single.status, 'failed');
      transport.corrupt = false;
      await service.retry(service.messages.single.id);
      expect(service.messages.single.status, 'delivered');
      expect(await service.db.select(service.db.outbox).get(), isEmpty);
    },
  );

  test(
    'Cancel removes outbox; invalid text rolls back without a message',
    () async {
      await service.setLaboratoryConnected(false);
      await service.send('laboratory', 'Cancel me');
      final id = service.messages.single.id;
      await service.cancel(id);
      transport.corrupt = false;
      await service.setLaboratoryConnected(true);
      expect(service.messages.single.status, 'cancelled');
      expect(await service.db.select(service.db.outbox).get(), isEmpty);
      await expectLater(service.send('notes', '😀' * 600), throwsArgumentError);
      await expectLater(
        service.send('missing', 'invalid destination'),
        throwsStateError,
      );
      expect(
        (await service.db.select(service.db.messages).get()),
        hasLength(1),
      );
      await service.deleteMessage(id);
      expect(service.messages, isEmpty);
    },
  );

  test(
    'Missing identity seed on reopen fails without silently creating a key',
    () async {
      final store = service.vault.store as MemorySecretStore;
      store.values.remove('identity');
      await expectLater(
        service.initialize(startTimer: false),
        throwsStateError,
      );
      expect(await store.read('identity'), isNull);
    },
  );
}
