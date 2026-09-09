import 'dart:convert';
import 'dart:typed_data';

import 'mesh_protocol.dart';

/// Bounded controlled flooding with recipient receipts and durable couriers.
/// Persistence completes before forwarding or acknowledging incoming content.
class MeshRouter {
  MeshRouter({
    required this.identity,
    required this.name,
    required this.write,
    required this.persist,
    required this.remove,
    required this.deliver,
    required this.remember,
    required this.receipt,
  });
  final MeshIdentity identity;
  final String name;
  final Future<void> Function(String link, Uint8List packet) write;
  final Future<void> Function(MeshPacket packet) persist;
  final Future<void> Function(String id) remove;
  final Future<void> Function(MeshPacket packet, MeshContent content) deliver;
  final Future<void> Function(MeshPeer peer) remember;
  final Future<void> Function(String id) receipt;
  final Map<String, MeshPeer> peers = {};
  final Map<String, MeshPacket> pending = {};
  final Set<String> links = {};
  final Map<String, int> _seen = {};
  final Map<String, int> _sent = {};
  int relayed = 0, dropped = 0;
  bool _flushing = false;

  Future<void> announce() async {
    final p = identity.create(
      '*',
      'presence',
      meshBytes([name, base64UrlEncode(identity.box.publicKey)]),
    );
    for (final link in links.toList()) {
      await _safeWrite(link, p);
    }
  }

  Future<void> _safeWrite(String link, MeshPacket p) async {
    try {
      await write(link, p.encode());
    } catch (_) {
      /* retained for retry */
    }
  }

  Future<void> enqueue(MeshPacket p) async {
    if (pending.length >= 500 && !pending.containsKey(p.id)) {
      throw StateError('Message queue is full');
    }
    await persist(p);
    pending[p.id] = p;
  }

  void disconnected(String link) {
    links.remove(link);
    for (final p in peers.values.where((p) => p.via == link)) {
      p.lastSeen = 0;
    }
    _sent.removeWhere((key, _) => key.startsWith('$link:'));
  }

  Future<void> accept(String link, Uint8List bytes) async {
    try {
      final p = MeshPacket.decode(identity.sodium, bytes);
      if (p.sender == identity.id) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      _seen.removeWhere((_, until) => until <= now);
      if (p.kind == 'presence') {
        final a = meshList(p.payload, 2, limit: 512);
        final displayName = a[0] as String;
        final box = base64Url.decode(a[1] as String);
        if (displayName.trim().isEmpty ||
            displayName.length > 40 ||
            RegExp(r'[\x00-\x1f\u202a-\u202e\u2066-\u2069]')
                .hasMatch(displayName) ||
            box.length != 32) {
          throw const FormatException('Invalid presence');
        }
        final old = peers[p.sender];
        if (old != null && base64UrlEncode(old.boxKey) != a[1]) {
          throw const FormatException('Peer key changed');
        }
        if (old == null && peers.length >= 256) throw StateError('Peer limit');
        if (old == null || !old.reachable || p.hops <= old.hops) {
          final peer = MeshPeer(
            p.sender,
            displayName,
            box,
            p.timestamp,
            p.hops,
            link,
          );
          await remember(peer);
          peers[p.sender] = peer;
        }
      }
      if (p.destination == identity.id) {
        final content = identity.decrypt(p);
        if (content.kind == 'ack') {
          final sent = pending[content.reference];
          if (sent != null &&
              sent.sender == identity.id &&
              sent.destination == p.sender) {
            await receipt(sent.id);
            await remove(sent.id);
            pending.remove(sent.id);
          }
          return;
        }
        // Database dedup is authoritative; replayed text gets another receipt.
        await deliver(p, content);
        final peer = peers[p.sender];
        if (peer != null) {
          final ack = identity.privatePacket(peer, 'ack', '', reference: p.id);
          for (final l in links.toList()) {
            await _safeWrite(l, ack);
          }
        }
        return;
      }
      if (_seen.containsKey(p.id)) return;
      if (_seen.length >= 4000) _seen.remove(_seen.keys.first);
      _seen[p.id] = p.expires;
      if (p.hops >= 7) return;
      final next = p.relayed();
      if (p.kind == 'sealed' && !pending.containsKey(p.id)) await enqueue(next);
      for (final l in links.toList().where((l) => l != link)) {
        await _safeWrite(l, next);
        _sent['$l:${p.id}'] = now;
        relayed++;
      }
      // Never bounce stored packets directly back to their ingress link.
      _sent['$link:${p.id}'] = now;
    } catch (_) {
      dropped++;
    }
  }

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      _sent.removeWhere((_, time) => now - time > meshLifetime);
      if (_sent.length > 8000) _sent.clear();
      for (final p in pending.values.toList()) {
        if (p.expires <= now) {
          await remove(p.id);
          pending.remove(p.id);
          continue;
        }
        // A bounded batch keeps app work responsive between radio operations.
        for (final link in links.toList()) {
          final key = '$link:${p.id}';
          if (now - (_sent[key] ?? 0) < 15000) continue;
          try {
            await write(link, p.encode());
            _sent[key] = now;
          } catch (_) {
            break;
          }
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
