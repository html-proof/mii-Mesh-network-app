import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sodium/sodium.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../features/chats/chat_service.dart';
import 'ble_packet.dart';

class BleLink extends ChangeNotifier {
  BleLink(this.service);
  final ChatService service;
  static const channel = MethodChannel('mii/ble');
  static const events = EventChannel('mii/ble/events');
  SecureKey? _key;
  StreamSubscription<dynamic>? _subscription;
  String status = 'Bluetooth stopped';
  String? pairingSecret;
  bool connected = false, running = false, busy = false;
  bool _disposed = false;
  Future<void> _processing = Future.value();
  final Map<String, Timer> _timeouts = {};
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (busy || running) return;
    busy = true;
    changed();
    try {
      final granted = await channel.invokeMethod<bool>('permissions') ?? false;
      if (!granted) {
        status =
            'Nearby devices permission denied. You can still use local notes.';
        return;
      }
      await _processing;
      _key?.dispose();
      _key = service.vault.sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
      final bytes = _key!.extractBytes();
      try {
        pairingSecret = base64UrlEncode(bytes);
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      await service.db
          .into(service.db.conversations)
          .insert(
            ConversationsCompanion.insert(
              id: 'bluetooth',
              title: 'Laptop Bluetooth',
              kind: 'bluetooth',
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await (service.db.update(service.db.messages)..where(
            (m) =>
                m.conversationId.equals('bluetooth') &
                m.status.equals('sending'),
          ))
          .write(const MessagesCompanion(status: Value('failed')));
      await service.refresh();
      _subscription ??= events.receiveBroadcastStream().listen(
        (event) {
          final map = event as Map;
          if (map['type'] == 'packet') {
            _processing = _processing
                .then((_) => _receive(map['value'] as Uint8List))
                .catchError((Object _) {
                  status = 'Rejected an invalid Bluetooth packet';
                  changed();
                });
          } else if (map['type'] == 'connected') {
            connected = map['value'] == true;
            changed();
          } else {
            status = map['value'] as String;
            if (status == 'Bluetooth stopped') {
              running = false;
              connected = false;
              pairingSecret = null;
            }
            changed();
          }
        },
        onError: (Object _) {
          status = 'Bluetooth event stream unavailable';
          connected = false;
          running = false;
          changed();
        },
      );
      await channel.invokeMethod<void>('start');
      running = true;
      status = 'Starting Bluetooth…';
    } on PlatformException catch (e) {
      status = e.message ?? 'Bluetooth unavailable';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> _receive(Uint8List bytes) async {
    if (_key == null || _disposed) return;
    final packet = BlePacket.decrypt(
      service.vault.sodium,
      _key!,
      bytes,
      fromPhone: false,
    );
    if (packet.type == 'ack') {
      await (service.db.update(service.db.messages)..where(
            (m) =>
                m.id.equals(packet.id) &
                m.conversationId.equals('bluetooth') &
                (m.status.equals('sending') | m.status.equals('failed')),
          ))
          .write(const MessagesCompanion(status: Value('delivered')));
      _timeouts.remove(packet.id)?.cancel();
    } else {
      await service.db.transaction(() async {
        final existing = await (service.db.select(
          service.db.messages,
        )..where((m) => m.id.equals(packet.id))).getSingleOrNull();
        if (existing != null) {
          if (existing.conversationId != 'bluetooth' ||
              existing.status != 'received' ||
              existing.body != packet.body) {
            throw const FormatException('Conflicting message ID');
          }
          return;
        }
        if (await service.db.messages.count().getSingle() >= 10000) {
          throw StateError('Local message limit reached');
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        await service.db
            .into(service.db.messages)
            .insert(
              MessagesCompanion.insert(
                id: packet.id,
                conversationId: 'bluetooth',
                body: packet.body,
                createdAt: now,
                expiresAt: now + 86400000,
                status: 'received',
                sequence: now,
              ),
            );
      });
      // Persist before acknowledging. No relay receipt is interpreted as delivery.
      await channel.invokeMethod<void>(
        'send',
        BlePacket(
          packet.id,
          'ack',
          '',
          DateTime.now().millisecondsSinceEpoch,
        ).encrypt(service.vault.sodium, _key!, fromPhone: true),
      );
    }
    status = 'Bluetooth connected · authenticated message received';
    await service.refresh();
    changed();
  }

  Future<void> send(String text, {String? retryId}) async {
    if (!connected || _key == null || !running) {
      throw StateError('Laptop is not connected');
    }
    text = text.trim();
    if (text.isEmpty || utf8.encode(text).length > 2048) {
      throw ArgumentError('Use 1–2048 UTF-8 bytes.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = retryId ?? const Uuid().v7();
    await service.db.transaction(() async {
      if (retryId == null) {
        if (await service.db.messages.count().getSingle() >= 10000) {
          throw StateError('Local message limit reached');
        }
        await service.db
            .into(service.db.messages)
            .insert(
              MessagesCompanion.insert(
                id: id,
                conversationId: 'bluetooth',
                body: text,
                createdAt: now,
                expiresAt: now + 86400000,
                status: 'sending',
                sequence: now,
              ),
            );
      } else {
        await (service.db.update(service.db.messages)..where(
              (m) =>
                  m.id.equals(id) &
                  m.conversationId.equals('bluetooth') &
                  m.status.equals('failed'),
            ))
            .write(const MessagesCompanion(status: Value('sending')));
      }
    });
    await service.refresh();
    try {
      _timeouts.remove(id)?.cancel();
      _timeouts[id] = Timer(const Duration(seconds: 20), () {
        _markFailed(id);
      });
      await channel.invokeMethod<void>(
        'send',
        BlePacket(
          id,
          'text',
          text,
          now,
        ).encrypt(service.vault.sodium, _key!, fromPhone: true),
      );
    } catch (_) {
      await _markFailed(id);
      rethrow;
    }
  }

  Future<void> _markFailed(String id) async {
    if (_disposed) return;
    _timeouts.remove(id)?.cancel();
    try {
      await (service.db.update(service.db.messages)
            ..where((m) => m.id.equals(id) & m.status.equals('sending')))
          .write(const MessagesCompanion(status: Value('failed')));
      await service.refresh();
      changed();
    } catch (_) {
      status = 'Could not update delivery state';
      changed();
    }
  }

  Future<void> stop() async {
    await channel.invokeMethod<void>('stop');
    running = false;
    connected = false;
    status = 'Bluetooth stopped';
    pairingSecret = null;
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    _subscription?.cancel();
    channel.invokeMethod<void>('stop').catchError((Object _) {});
    _processing.whenComplete(() {
      _key?.dispose();
      _key = null;
    });
    super.dispose();
  }
}
