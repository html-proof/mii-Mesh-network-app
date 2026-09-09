import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';
import 'package:mii_mesh/transports/mesh/mesh_protocol.dart';
import 'package:mii_mesh/transports/mesh/mesh_router.dart';

void main() {
  late Sodium sodium;
  final identities = <MeshIdentity>[];
  setUp(() async {
    sodium = await SodiumInit.init();
  });
  tearDown(() {
    for (final i in identities) {
      i.dispose();
    }
    identities.clear();
  });
  MeshIdentity identity() {
    final i = MeshIdentity(
      sodium,
      sodium.crypto.sign.keyPair(),
      sodium.crypto.box.keyPair(),
    );
    identities.add(i);
    return i;
  }

  test('Sealed text is authenticated, recipient-only and resistant to header edits', () {
    final a = identity(), b = identity(), relay = identity();
    final peer = MeshPeer(b.id, 'B', b.box.publicKey, 0, 0, 'b');
    final p = a.privatePacket(peer, 'text', 'private hello');
    expect(utf8.decode(p.encode()).contains('private hello'), false);
    expect(
      b.decrypt(MeshPacket.decode(sodium, p.encode())).body,
      'private hello',
    );
    expect(() => relay.decrypt(p), throwsFormatException);
    final altered = p.fields.toList()..[3] = relay.id;
    expect(
      () => MeshPacket.decode(
        sodium,
        MeshPacket(altered, p.signature, 0).encode(),
      ),
      throwsA(anything),
    );
    expect(
      () => MeshPacket.decode(
        sodium,
        p.encode(),
        now: p.timestamp + meshLifetime + 1,
      ),
      throwsFormatException,
    );
    expect(
      () => meshList(Uint8List.fromList(utf8.encode('[' * 1000)), 10),
      throwsFormatException,
    );
  });
  test('Four nodes relay opaque packets, acknowledge once and survive alternate paths', () async {
    final nodes = <String, MeshRouter>{};
    final wire = <(String, String, Uint8List)>[];
    final delivered = <String, Set<String>>{};
    final receipts = <String>[];
    final stored = <String, Map<String, MeshPacket>>{};
    for (final name in ['a', 'b', 'c', 'd']) {
      delivered[name] = {};
      stored[name] = {};
      nodes[name] = MeshRouter(
        identity: identity(),
        name: name,
        write: (link, bytes) async {
          wire.add((name, link, bytes));
        },
        persist: (p) async {
          stored[name]![p.id] = p;
        },
        remove: (id) async {
          stored[name]!.remove(id);
        },
        remember: (_) async {},
        deliver: (p, c) async {
          delivered[name]!.add(p.id);
        },
        receipt: (id) async {
          receipts.add(id);
        },
      );
    }
    void connect(String a, String b) {
      nodes[a]!.links.add(b);
      nodes[b]!.links.add(a);
    }

    Future<void> drain() async {
      var count = 0;
      while (wire.isNotEmpty) {
        expect(count++, lessThan(2000), reason: 'Relay loop');
        final (from, to, bytes) = wire.removeAt(0);
        if (nodes[to]!.links.contains(from)) {
          await nodes[to]!.accept(from, bytes);
        }
      }
    }

    connect('a', 'b');
    connect('b', 'c');
    connect('c', 'd');
    for (final n in nodes.values) {
      await n.announce();
    }
    await drain();
    final a = nodes['a']!, d = nodes['d']!;
    expect(a.peers[d.identity.id]!.hops, 2);
    final packet = a.identity.privatePacket(
      a.peers[d.identity.id]!,
      'text',
      'Hello across three links',
    );
    await a.enqueue(packet);
    await a.flush();
    await drain();
    expect(delivered['d'], contains(packet.id));
    expect(receipts, contains(packet.id));
    expect(a.pending, isEmpty);
    expect(delivered['b'], isEmpty);
    expect(delivered['c'], isEmpty);
    // Duplicate arrivals do not create another recipient message.
    await d.accept('c', packet.relayed().relayed().encode());
    await drain();
    expect(delivered['d']!.length, 1);
    // Lose B-C, create alternate A-C path, and deliver another queued packet.
    nodes['b']!.disconnected('c');
    nodes['c']!.disconnected('b');
    connect('a', 'c');
    final next = a.identity.privatePacket(
      a.peers[d.identity.id]!,
      'sticker',
      'wave',
    );
    await a.enqueue(next);
    await a.flush();
    await drain();
    expect(delivered['d'], contains(next.id));
    // A disconnected recipient can later receive a courier's stored envelope.
    nodes['c']!.disconnected('d');
    d.disconnected('c');
    final later = a.identity.privatePacket(
      a.peers[d.identity.id]!,
      'text',
      'Save until D returns',
    );
    await a.enqueue(later);
    await a.flush();
    await drain();
    expect(delivered['d'], isNot(contains(later.id)));
    expect(stored['c'], contains(later.id));
    connect('c', 'd');
    await nodes['c']!.flush();
    await drain();
    expect(delivered['d'], contains(later.id));
    expect(receipts, contains(later.id));
    final burst = <String>[];
    for (var i = 0; i < 100; i++) {
      final p = a.identity.privatePacket(
        a.peers[d.identity.id]!,
        'text',
        'Burst $i',
      );
      burst.add(p.id);
      await a.enqueue(p);
    }
    await a.flush();
    await drain();
    expect(delivered['d'], containsAll(burst));
    expect(receipts, containsAll(burst));
  });
  test(
    'Corruption, hop limit, key replacement and invalid stickers are rejected',
    () async {
      final a = identity(), b = identity();
      final outgoing = <Uint8List>[];
      final router = MeshRouter(
        identity: b,
        name: 'B',
        write: (_, p) async {
          outgoing.add(p);
        },
        persist: (_) async {},
        remove: (_) async {},
        remember: (_) async {},
        deliver: (_, _) async {},
        receipt: (_) async {},
      );
      router.links.addAll(['a', 'c']);
      final presence = a.create(
        '*',
        'presence',
        meshBytes(['A', base64UrlEncode(a.box.publicKey)]),
      );
      await router.accept(
        'a',
        MeshPacket(presence.fields, presence.signature, 7).encode(),
      );
      expect(outgoing, isEmpty);
      final changed = a.create(
        '*',
        'presence',
        meshBytes(['A', base64UrlEncode(b.box.publicKey)]),
      );
      await router.accept('a', changed.encode());
      expect(router.dropped, 1);
      final corrupt = presence.encode()..[30] ^= 1;
      await router.accept('a', corrupt);
      expect(router.dropped, 2);
      expect(
        () => a.privatePacket(
          MeshPeer(b.id, 'B', b.box.publicKey, 0, 0, ''),
          'sticker',
          'arbitrary-file',
        ),
        throwsFormatException,
      );
    },
  );
}
