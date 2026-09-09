@Tags(['report'])
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mii_mesh/app/shell.dart';
import 'package:mii_mesh/app/theme.dart';
import 'package:mii_mesh/core/crypto/vault.dart';
import 'package:mii_mesh/core/database/database.dart';
import 'package:mii_mesh/features/chats/chat_service.dart';
import 'package:mii_mesh/transports/fake/fake_transport.dart';
import 'package:mii_mesh/transports/mesh/mesh_protocol.dart';
import 'package:sodium/sodium.dart';

import 'support.dart';

/// Captures interface screenshots for the project report.
/// Run with:  flutter test test/report_screens_test.dart --update-goldens
void main() {
  setUpAll(() async {
    final fonts = FontLoader('Roboto');
    for (final name in ['regular', 'medium', 'bold']) {
      fonts.addFont(
        File('assets/fonts/roboto-$name.ttf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)),
      );
    }
    // Emoji fallback: the harness has no system emoji font, so stickers and
    // reactions would otherwise render as missing-glyph boxes.
    for (final path in [
      r'C:\Windows\Fonts\seguiemj.ttf',
      '/System/Library/Fonts/Apple Color Emoji.ttc',
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    ]) {
      if (File(path).existsSync()) {
        fonts.addFont(
          File(path).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
        break;
      }
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  late ChatService service;
  setUp(() async {
    final sodium = await SodiumInit.init();
    final vault = Vault(sodium, MemorySecretStore());
    service = ChatService(
      MeshDatabase(NativeDatabase.memory()),
      vault,
      FakeTransport(sodium, await vault.laboratoryKey()),
    );
    await service.createIdentity('Alex');
  });
  tearDown(() async => service.close());

  Future<void> shoot(
    WidgetTester tester,
    String section,
    Size size,
    String file, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: miiTheme(brightness),
        home: MiiShell(service: service, section: section),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/$file.png'),
    );
  }

  Future<void> shootChat(
    WidgetTester tester,
    String chatId,
    Size size,
    String file,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: miiTheme(Brightness.light),
        home: MiiShell(service: service, section: 'chats', chatId: chatId),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/$file.png'),
    );
  }

  testWidgets('Conversation with sticker and reaction', (tester) async {
    await service.mesh.initialize();
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = service.mesh.router!;
    service.mesh.running = true;
    service.mesh.status = 'Connected';
    r.links.add('link-a');
    final peer = MeshPeer('a', 'Maya', Uint8List(32), now, 0, 'link-a');
    r.peers['a'] = peer;
    await service.mesh.ensureConversation(peer);

    const m1 = '11111111-1111-4111-8111-111111111111';
    const m2 = '22222222-2222-4222-8222-222222222222';
    const m3 = '33333333-3333-4333-8333-333333333333';
    const m4 = '44444444-4444-4444-8444-444444444444';

    Future<void> add(String id, String stored, String status, int t) => service
        .db
        .into(service.db.messages)
        .insert(
          MessagesCompanion.insert(
            id: id,
            conversationId: 'mesh:a',
            body: stored,
            createdAt: t,
            expiresAt: t + 86400000,
            status: status,
            sequence: t,
          ),
        );

    await add(
      m1,
      const MeshContent('text', 'Are you still at the festival?', '').stored,
      'received',
      now - 400000,
    );
    await add(
      m2,
      const MeshContent('text', 'Yes! No signal here at all.', '').stored,
      'delivered',
      now - 300000,
    );
    await add(
      m3,
      const MeshContent(
        'text',
        'Same here. This is going through two phones between us.',
        '',
      ).stored,
      'received',
      now - 200000,
    );
    await add(
      m4,
      const MeshContent('text', 'Mesh really works then.', '').stored,
      'queued',
      now - 100000,
    );
    await service.refresh();
    await shootChat(tester, 'mesh:a', const Size(390, 844), 'conversation');
  });

  testWidgets('Nearby — permission explainer', (tester) async {
    await shoot(tester, 'nearby', const Size(390, 844), 'nearby-start');
  });

  testWidgets('Calls', (tester) async {
    await shoot(tester, 'calls', const Size(390, 844), 'calls');
  });

  testWidgets('Nearby — peers discovered', (tester) async {
    await service.mesh.initialize();
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = service.mesh.router!;
    service.mesh.running = true;
    service.mesh.status = 'Connected';
    r.links.add('link-a');
    r.peers['a'] = MeshPeer('a', 'Maya', Uint8List(32), now, 0, 'link-a');
    r.peers['b'] = MeshPeer('b', 'John', Uint8List(32), now, 2, 'link-a');
    r.peers['c'] = MeshPeer(
      'c',
      'Priya',
      Uint8List(32),
      now - 300000,
      1,
      'link-a',
    );
    await shoot(tester, 'nearby', const Size(390, 844), 'nearby-peers');
  });

  testWidgets('Mesh diagnostics', (tester) async {
    await service.mesh.initialize();
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = service.mesh.router!;
    service.mesh.running = true;
    service.mesh.status = 'Connected';
    r.links.addAll(['link-a', 'link-b', 'link-c']);
    r.peers['a'] = MeshPeer('a', 'Maya', Uint8List(32), now, 0, 'link-a');
    r.peers['b'] = MeshPeer('b', 'John', Uint8List(32), now, 2, 'link-b');
    r.relayed = 41;
    r.dropped = 0;
    await shoot(tester, 'diagnostics', const Size(390, 844), 'diagnostics');
  });

  testWidgets('Settings', (tester) async {
    await shoot(tester, 'settings', const Size(390, 844), 'settings');
  });
}
