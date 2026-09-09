import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium.dart';
import 'package:uuid/uuid.dart';

import '../../core/crypto/vault.dart';
import '../../core/database/database.dart';
import '../../core/protocol/envelope.dart';
import '../../transports/fake/fake_transport.dart';
import '../../transports/mesh/mesh_service.dart';

class ChatService extends ChangeNotifier {
  ChatService(this.db, this.vault, this.transport);
  final MeshDatabase db;
  final Vault vault;
  final FakeTransport transport;
  late final MeshService mesh = MeshService(this);
  Profile? profile;
  List<Conversation> conversations = [];
  List<Message> messages = [];
  Map<String, String> preferences = {};
  Timer? _timer;
  bool _pumping = false;
  bool _closed = false;
  String? backgroundError;
  int get queuedCount => messages
      .where((m) => m.status == 'queued' || m.status == 'failed')
      .length;
  String get fingerprint =>
      profile == null ? '' : vault.fingerprint(profile!.publicKey);

  static Future<ChatService> open() async {
    final sodium = await SodiumInit.init();
    final vault = Vault(sodium, PlatformSecretStore());
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'mii-v1.sqlite'));
    final key = await vault.databaseKey(databaseExists: await file.exists());
    final db = MeshDatabase.encrypted(file, key);
    ChatService? service;
    try {
      await db.customSelect('SELECT count(*) FROM sqlite_master').get();
      service = ChatService(
        db,
        vault,
        FakeTransport(sodium, await vault.laboratoryKey()),
      );
      await service.initialize();
      if (service.profile != null) {
        await service.mesh.initialize();
        if (service.preferences['meshEnabled'] == 'true') {
          await service.mesh.start();
        }
      }
      return service;
    } catch (_) {
      if (service != null) {
        await service.close();
      } else {
        await db.close();
      }
      rethrow;
    }
  }

  Future<void> initialize({bool startTimer = true}) async {
    await db.purgeExpired(DateTime.now().millisecondsSinceEpoch);
    await refresh();
    if (profile != null) {
      if (await vault.store.read('identity') == null ||
          !bytesEqual(await vault.identityPublicKey(), profile!.publicKey)) {
        throw StateError('Local identity key unavailable or changed');
      }
    }
    if (preferences['laboratoryConnected'] == 'true') await transport.connect();
    if (startTimer) {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          await pump();
        } catch (_) {
          backgroundError =
              'Local storage is unavailable. Reopen the app to retry.';
          if (!_closed) notifyListeners();
        }
      });
    }
    await pump();
  }

  Future<void> refresh() async {
    profile = await db.select(db.profiles).getSingleOrNull();
    conversations = await db.select(db.conversations).get();
    messages =
        await (db.select(db.messages)..orderBy([
              (m) => OrderingTerm.asc(m.createdAt),
              (m) => OrderingTerm.asc(m.sequence),
            ]))
            .get();
    preferences = {
      for (final row in await db.select(db.preferences).get())
        row.key: row.value,
    };
    if (!_closed) notifyListeners();
  }

  Future<void> createIdentity(String name) async {
    name = name.trim();
    if (name.isEmpty ||
        name.length > 40 ||
        RegExp(r'[\x00-\x1f\u202a-\u202e\u2066-\u2069]').hasMatch(name)) {
      throw ArgumentError(
        'Choose a display name of 1–40 characters without control characters.',
      );
    }
    final publicKey = await vault.identityPublicKey();
    await db.transaction(() async {
      if (await db.select(db.profiles).getSingleOrNull() != null) {
        throw StateError('Identity already exists');
      }
      await db
          .into(db.profiles)
          .insert(
            ProfilesCompanion.insert(
              id: const Value(1),
              displayName: name,
              publicKey: publicKey,
            ),
          );
      await db
          .into(db.conversations)
          .insert(
            ConversationsCompanion.insert(
              id: 'notes',
              title: 'Saved notes',
              kind: 'notes',
            ),
          );
    });
    await refresh();
  }

  Future<void> setPreference(String key, String value) async {
    await db
        .into(db.preferences)
        .insertOnConflictUpdate(
          PreferencesCompanion.insert(key: key, value: value),
        );
    await refresh();
  }

  Future<void> enableLaboratory() async {
    await db
        .into(db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: 'laboratory',
            title: 'Local test chat',
            kind: 'laboratory',
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await setLaboratoryConnected(true);
  }

  Future<void> setLaboratoryConnected(bool connected) async {
    await setPreference('laboratoryConnected', '$connected');
    if (connected) {
      await transport.connect();
    } else {
      await transport.disconnect();
    }
    notifyListeners();
    await pump();
  }

  Future<void> saveDraft(String id, String text) async {
    if (text.length > 2048) return;
    await (db.update(db.conversations)..where((c) => c.id.equals(id))).write(
      ConversationsCompanion(draft: Value(text)),
    );
  }

  Future<void> send(String conversationId, String body) async {
    body = body.trim();
    if (body.isEmpty || utf8.encode(body).length > 2048) {
      throw ArgumentError('Messages must be 1–2048 UTF-8 bytes.');
    }
    if (profile == null) throw StateError('Create an identity first');
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const Uuid().v7();
    await db.transaction(() async {
      final conversation = await (db.select(
        db.conversations,
      )..where((c) => c.id.equals(conversationId))).getSingle();
      final count = await db.messages.count().getSingle();
      if (count >= 10000) {
        throw StateError(
          'Local message limit reached. Delete old notes first.',
        );
      }
      final sequenceRow = await (db.select(
        db.preferences,
      )..where((p) => p.key.equals('sequence'))).getSingleOrNull();
      final sequence = (int.tryParse(sequenceRow?.value ?? '') ?? 0) + 1;
      await db
          .into(db.preferences)
          .insertOnConflictUpdate(
            PreferencesCompanion.insert(key: 'sequence', value: '$sequence'),
          );
      await db
          .into(db.messages)
          .insert(
            MessagesCompanion.insert(
              id: id,
              conversationId: conversationId,
              body: body,
              createdAt: now,
              expiresAt: conversation.kind == 'notes'
                  ? 8640000000000000
                  : now + 86400000,
              status: conversation.kind == 'notes' ? 'saved' : 'queued',
              sequence: sequence,
            ),
          );
      if (conversation.kind == 'laboratory') {
        final pendingCount = await db.outbox.count().getSingle();
        if (pendingCount >= 500) {
          throw StateError('Outbox full. Cancel pending messages first.');
        }
        var envelope = Envelope(
          id: id,
          sender: profile!.publicKey
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(),
          recipient: 'laboratory',
          createdAt: now,
          expiresAt: now + 86400000,
          sequence: sequence,
          nonce: base64Encode(vault.sodium.randombytes.buf(24)),
          ciphertext: '',
        );
        final encrypted = vault.sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
          message: Uint8List.fromList(utf8.encode(body)),
          nonce: base64Decode(envelope.nonce),
          key: transport.key,
          additionalData: envelope.additionalData,
        );
        envelope = envelope.copyWith(ciphertext: base64Encode(encrypted));
        await db
            .into(db.outbox)
            .insert(
              OutboxCompanion.insert(
                messageId: id,
                envelope: envelope.encode(),
                nextAttempt: now,
              ),
            );
      }
      await (db.update(db.conversations)
            ..where((c) => c.id.equals(conversationId)))
          .write(const ConversationsCompanion(draft: Value('')));
    });
    await refresh();
    await pump();
  }

  Future<void> pump() async {
    if (_pumping || _closed) return;
    _pumping = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.purgeExpired(now);
      if (transport.available) {
        final pending =
            await (db.select(db.outbox)
                  ..where(
                    (o) =>
                        o.nextAttempt.isSmallerOrEqualValue(now) &
                        o.attempts.isSmallerThanValue(5),
                  )
                  ..limit(20))
                .get();
        for (final item in pending) {
          if (!transport.available) break;
          try {
            final envelope = Envelope.decode(item.envelope, now);
            final ack = await transport.sendEnvelope(item.envelope);
            if (!transport.verifyAck(envelope, ack)) {
              throw StateError('Invalid acknowledgement');
            }
            await db.transaction(() async {
              await (db.update(db.messages)..where(
                    (m) =>
                        m.id.equals(item.messageId) & m.status.equals('queued'),
                  ))
                  .write(const MessagesCompanion(status: Value('delivered')));
              await (db.delete(
                db.outbox,
              )..where((o) => o.messageId.equals(item.messageId))).go();
            });
          } catch (_) {
            final attempts = item.attempts + 1;
            await (db.update(
              db.outbox,
            )..where((o) => o.messageId.equals(item.messageId))).write(
              OutboxCompanion(
                attempts: Value(attempts),
                nextAttempt: Value(
                  now + retryDelay(attempts, Random.secure()).inMilliseconds,
                ),
              ),
            );
            if (attempts >= 5) {
              await (db.update(db.messages)..where(
                    (m) =>
                        m.id.equals(item.messageId) & m.status.equals('queued'),
                  ))
                  .write(const MessagesCompanion(status: Value('failed')));
            }
          }
        }
      }
      backgroundError = null;
      await refresh();
    } finally {
      _pumping = false;
    }
  }

  static Duration retryDelay(int attempt, Random random) => Duration(
    milliseconds:
        min(60000, 1000 * (1 << min(attempt, 6))) + random.nextInt(1000),
  );

  Future<void> retry(String id) async {
    await db.transaction(() async {
      await (db.update(db.messages)
            ..where((m) => m.id.equals(id) & m.status.equals('failed')))
          .write(const MessagesCompanion(status: Value('queued')));
      await (db.update(db.outbox)..where((o) => o.messageId.equals(id))).write(
        const OutboxCompanion(attempts: Value(0), nextAttempt: Value(0)),
      );
    });
    await pump();
  }

  Future<void> cancel(String id) async {
    await db.transaction(() async {
      await (db.delete(db.outbox)..where((o) => o.messageId.equals(id))).go();
      await (db.update(db.messages)..where(
            (m) =>
                m.id.equals(id) &
                (m.status.equals('queued') | m.status.equals('failed')),
          ))
          .write(const MessagesCompanion(status: Value('cancelled')));
    });
    await refresh();
  }

  Future<void> deleteMessage(String id) async {
    await (db.delete(db.messages)..where((m) => m.id.equals(id))).go();
    await refresh();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    while (_pumping) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await transport.dispose();
    await mesh.close();
    await db.close();
    super.dispose();
  }
}
