import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/database/database.dart';
import '../../features/chats/chat_service.dart';
import 'mesh_protocol.dart';
import 'mesh_router.dart';

class MeshService extends ChangeNotifier {
  MeshService(this.chat);
  final ChatService chat;
  static const channel = MethodChannel('mii/mesh');
  static const events = EventChannel('mii/mesh/events');
  MeshRouter? router;
  bool running = false, busy = false, _closed = false;
  String status = 'Enable Bluetooth to find nearby people';
  StreamSubscription<dynamic>? _subscription;
  Timer? _timer;
  Future<void>? _work;
  final Map<String, Future<void>> _writes = {};
  int _queuedEvents = 0, _ticks = 0;
  List<MeshPeer> get peers => router?.peers.values.toList() ?? [];
  String get summary {
    if (!running || status.contains('off') || status.contains('unavailable')) {
      return status;
    }
    final count = peers.where((p) => p.reachable).length;
    return count == 0
        ? 'Searching for nearby people…'
        : 'Connected · $count nearby';
  }

  void changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> initialize() async {
    if (router != null) return;
    final identity = await MeshIdentity.open(chat.vault);
    router = MeshRouter(
      identity: identity,
      name: chat.profile!.displayName,
      write: (link, bytes) {
        final future = (_writes[link] ?? Future.value())
            .catchError((Object _) {})
            .then((_) async {
              if (!running || _closed) throw StateError('Bluetooth paused');
              await channel.invokeMethod<void>('send', {
                'link': link,
                'bytes': bytes,
              });
            });
        _writes[link] = future;
        return future;
      },
      persist: (p) async {
        await chat.db.customStatement(
          'INSERT OR REPLACE INTO mesh_packets (id, packet, expires) VALUES (?, ?, ?)',
          [p.id, p.encode(), p.expires],
        );
      },
      remove: (id) async {
        await chat.db.customStatement('DELETE FROM mesh_packets WHERE id = ?', [
          id,
        ]);
        await (chat.db.update(chat.db.messages)
              ..where((m) => m.id.equals(id) & m.status.equals('queued')))
            .write(const MessagesCompanion(status: Value('expired')));
      },
      receipt: (id) async {
        await (chat.db.update(chat.db.messages)
              ..where((m) => m.id.equals(id) & m.status.equals('queued')))
            .write(const MessagesCompanion(status: Value('delivered')));
        await chat.refresh();
      },
      remember: (p) async {
        await chat.db.customStatement(
          'INSERT OR REPLACE INTO mesh_peers (id, name, box_key) VALUES (?, ?, ?)',
          [p.id, p.name, p.boxKey],
        );
      },
      deliver: (p, content) async {
        final peer = router!.peers[p.sender];
        // A valid signed announcement establishes the pinned encryption key first.
        if (peer == null) throw StateError('Waiting for sender announcement');
        await chat.db.transaction(() async {
          await ensureConversation(peer);
          final existing = await (chat.db.select(
            chat.db.messages,
          )..where((m) => m.id.equals(p.id))).getSingleOrNull();
          if (existing != null) {
            if (existing.conversationId != 'mesh:${p.sender}' ||
                existing.body != content.stored ||
                existing.status != 'received') {
              throw const FormatException('Conflicting message');
            }
            return;
          }
          if (await chat.db.messages.count().getSingle() >= 10000) {
            throw StateError('Message limit reached');
          }
          if (content.kind == 'reaction') {
            final target =
                await (chat.db.select(chat.db.messages)..where(
                      (m) =>
                          m.id.equals(content.reference) &
                          m.conversationId.equals('mesh:${p.sender}'),
                    ))
                    .getSingleOrNull();
            if (target == null) {
              throw const FormatException('Unknown reaction target');
            }
          }
          await chat.db
              .into(chat.db.messages)
              .insert(
                MessagesCompanion.insert(
                  id: p.id,
                  conversationId: 'mesh:${p.sender}',
                  body: content.stored,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                  expiresAt: p.expires,
                  status: 'received',
                  sequence: p.timestamp,
                ),
              );
        });
        await chat.refresh();
      },
    );
    for (final row
        in await chat.db.customSelect('SELECT * FROM mesh_peers').get()) {
      final peer = MeshPeer(
        row.read<String>('id'),
        row.read<String>('name'),
        row.read<Uint8List>('box_key'),
        0,
        0,
        '',
      );
      router!.peers[peer.id] = peer;
    }
    await chat.db.customStatement(
      'DELETE FROM mesh_packets WHERE expires <= ?',
      [DateTime.now().millisecondsSinceEpoch],
    );
    for (final row
        in await chat.db
            .customSelect('SELECT packet FROM mesh_packets LIMIT 500')
            .get()) {
      try {
        final p = MeshPacket.decode(
          identity.sodium,
          row.read<Uint8List>('packet'),
        );
        router!.pending[p.id] = p;
      } catch (_) {
        router!.dropped++;
      }
    }
  }

  Future<void> ensureConversation(MeshPeer peer) async {
    await chat.db
        .into(chat.db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: 'mesh:${peer.id}',
            title: peer.name,
            kind: 'mesh',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> start() async {
    if (busy || running || _closed) return;
    busy = true;
    changed();
    try {
      if (await channel.invokeMethod<bool>('permissions') != true) {
        status =
            'Nearby access was denied. You can enable it in phone settings.';
        return;
      }
      await initialize();
      _subscription ??= events.receiveBroadcastStream().listen(
        (dynamic event) {
          final map = event as Map;
          if (map['type'] == 'status') {
            status = map['value'] as String;
            changed();
            return;
          }
          if (_queuedEvents >= 128) {
            router!.dropped++;
            return;
          }
          _queuedEvents++;
          _work = (_work ?? Future<void>.value())
              .then((_) async {
                if (_closed || !running) return;
                final link = map['link'] as String;
                if (map['type'] == 'connected') {
                  if (map['value'] == true) {
                    router!.links.add(link);
                    await router!.announce();
                    await router!.flush();
                  } else {
                    router!.disconnected(link);
                    _writes.remove(link);
                  }
                } else if (map['type'] == 'packet') {
                  await router!.accept(link, map['value'] as Uint8List);
                }
                changed();
              })
              .catchError((Object _) {
                status = 'Connection interrupted — retrying…';
                changed();
              })
              .whenComplete(() {
                _queuedEvents--;
              });
        },
        onError: (Object _) {
          status = 'Bluetooth unavailable. Reopen the app to retry.';
          changed();
        },
      );
      running = true;
      await channel.invokeMethod<void>('start');
      await chat.setPreference('meshEnabled', 'true');
      _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
        if (_queuedEvents > 8 || !running) return;
        _work = (_work ?? Future<void>.value())
            .then((_) async {
              if (_closed || !running) return;
              if (_ticks++ % 3 == 0) await router!.announce();
              await router!.flush();
              changed();
            })
            .catchError((Object _) {
              status = 'Waiting for connection';
              changed();
            });
      });
    } catch (_) {
      running = false;
      status = 'Bluetooth unavailable. Check Nearby devices access.';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> stop() async {
    running = false;
    _timer?.cancel();
    _timer = null;
    for (final link in router?.links.toList() ?? <String>[]) {
      router!.disconnected(link);
    }
    await channel.invokeMethod<void>('stop');
    await chat.setPreference('meshEnabled', 'false');
    status = 'Bluetooth paused';
    changed();
  }

  Future<void> send(
    MeshPeer peer,
    String body, {
    String kind = 'text',
    String reference = '',
  }) async {
    await initialize();
    final p = router!.identity.privatePacket(
      peer,
      kind,
      body.trim(),
      reference: reference,
    );
    final content = MeshContent(kind, body.trim(), reference);
    if (router!.pending.length >= 500) {
      throw StateError('Message queue is full');
    }
    await chat.db.transaction(() async {
      await ensureConversation(peer);
      if (await chat.db.messages.count().getSingle() >= 10000) {
        throw StateError('Message limit reached');
      }
      await chat.db
          .into(chat.db.messages)
          .insert(
            MessagesCompanion.insert(
              id: p.id,
              conversationId: 'mesh:${peer.id}',
              body: content.stored,
              createdAt: p.timestamp,
              expiresAt: p.expires,
              status: 'queued',
              sequence: p.timestamp,
            ),
          );
      await router!.persist(p);
    });
    router!.pending[p.id] = p;
    await chat.refresh();
    // UI returns after durable queue insertion, never waits for the radio.
    unawaited(
      router!.flush().catchError((Object _) {
        changed();
      }),
    );
  }

  Future<void> close() async {
    _closed = true;
    running = false;
    _timer?.cancel();
    await _subscription?.cancel();
    try {
      if (_subscription != null) await channel.invokeMethod<void>('stop');
    } catch (_) {}
    if (_work != null) await _work;
    await Future.wait(_writes.values.map((f) => f.catchError((Object _) {})));
    router?.identity.dispose();
    super.dispose();
  }
}
