import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mii_mesh/core/crypto/vault.dart';
import 'package:mii_mesh/core/database/database.dart';
import 'package:mii_mesh/features/chats/chat_service.dart';
import 'package:mii_mesh/transports/fake/fake_transport.dart';
import 'package:mii_mesh/transports/mesh/mesh_protocol.dart';
import 'package:sodium/sodium.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Upgrade keeps v1 identity/history and mesh outbox survives restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('mii-mesh-upgrade-');
      final file = File('${dir.path}/vault.sqlite');
      final sodium = await SodiumInit.init();
      final vault = Vault(sodium, MemorySecretStore());
      final key = await vault.databaseKey(databaseExists: false);
      Future<ChatService> open() async {
        final service = ChatService(
          MeshDatabase.encrypted(file, key),
          vault,
          FakeTransport(sodium, await vault.laboratoryKey()),
        );
        await service.initialize(startTimer: false);
        return service;
      }

      final remote = MeshIdentity(
        sodium,
        sodium.crypto.sign.keyPair(),
        sodium.crypto.box.keyPair(),
      );
      try {
        var service = await open();
        await service.createIdentity('Existing person');
        await service.send('notes', 'Preserve my existing note');
        final fingerprint = service.fingerprint;
        // Recreate the exact old schema state: the original five tables, version 1.
        await service.db.customStatement('DROP TABLE mesh_peers');
        await service.db.customStatement('DROP TABLE mesh_packets');
        await service.db.customStatement('PRAGMA user_version = 1');
        await service.close();
        service = await open();
        expect(service.fingerprint, fingerprint);
        expect(service.messages.single.body, 'Preserve my existing note');
        await service.mesh.initialize();
        final peer = MeshPeer(
          remote.id,
          'Other phone',
          remote.box.publicKey,
          0,
          0,
          '',
        );
        await service.mesh.router!.remember(peer);
        service.mesh.router!.peers[peer.id] = peer;
        await service.mesh.send(peer, 'Deliver when the other phone returns');
        final id = service.mesh.router!.pending.keys.single;
        expect(service.messages.last.status, 'queued');
        await service.close();
        service = await open();
        await service.mesh.initialize();
        expect(service.mesh.router!.pending, contains(id));
        expect(service.mesh.peers.single.name, 'Other phone');
        expect(
          remote.decrypt(service.mesh.router!.pending[id]!).body,
          'Deliver when the other phone returns',
        );
        expect(service.fingerprint, fingerprint);
        final local = service.mesh.router!.identity;
        final localPeer = MeshPeer(
          local.id,
          'Local',
          local.box.publicKey,
          0,
          0,
          '',
        );
        final incoming = remote.privatePacket(
          localPeer,
          'text',
          'One incoming message',
        );
        await service.mesh.router!.accept('remote', incoming.encode());
        await service.mesh.router!.accept('remote', incoming.encode());
        expect(
          service.messages.where((m) => m.id == incoming.id),
          hasLength(1),
        );
        final conflict = remote.privatePacket(
          localPeer,
          'text',
          'Conflicting content',
          id: incoming.id,
        );
        await service.mesh.router!.accept('remote', conflict.encode());
        expect(service.mesh.router!.dropped, 1);
        await service.close();
      } finally {
        remote.dispose();
        await dir.delete(recursive: true);
      }
    },
  );
}
