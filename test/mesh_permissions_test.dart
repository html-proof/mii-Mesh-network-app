import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mii_mesh/core/crypto/vault.dart';
import 'package:mii_mesh/core/database/database.dart';
import 'package:mii_mesh/features/chats/chat_service.dart';
import 'package:mii_mesh/transports/fake/fake_transport.dart';
import 'package:mii_mesh/transports/mesh/mesh_service.dart';
import 'package:sodium/sodium.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Denied or unavailable Bluetooth preserves notes and does not enable mesh',
    () async {
      final sodium = await SodiumInit.init();
      final vault = Vault(sodium, MemorySecretStore());
      final service = ChatService(
        MeshDatabase(NativeDatabase.memory()),
        vault,
        FakeTransport(sodium, await vault.laboratoryKey()),
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      try {
        await service.createIdentity('Permission test');
        await service.send('notes', 'Notes stay available');
        messenger.setMockMethodCallHandler(
          MeshService.channel,
          (_) async => false,
        );
        await service.mesh.start();
        expect(service.mesh.running, false);
        expect(service.mesh.status, contains('denied'));
        expect(service.mesh.router, isNull);
        messenger.setMockMethodCallHandler(MeshService.channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });
        await service.mesh.start();
        expect(service.mesh.running, false);
        expect(service.mesh.status, contains('unavailable'));
        expect(service.messages.single.body, 'Notes stay available');
        expect(service.preferences['meshEnabled'], isNot('true'));
      } finally {
        messenger.setMockMethodCallHandler(MeshService.channel, null);
        await service.close();
      }
    },
  );
}
