import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:mii_mesh/app/theme.dart';
import 'package:mii_mesh/app/shell.dart';
import 'package:mii_mesh/core/crypto/vault.dart';
import 'package:mii_mesh/core/database/database.dart';
import 'package:mii_mesh/features/chats/chat_service.dart';
import 'package:mii_mesh/features/onboarding/onboarding_screen.dart';
import 'package:sodium/sodium.dart';
import 'package:mii_mesh/transports/fake/fake_transport.dart';

import 'support.dart';

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
  });
  tearDown(() async {
    await service.close();
  });
  testWidgets('Onboarding requires deliberate acknowledgement', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: miiTheme(Brightness.light),
        home: OnboardingScreen(service: service),
      ),
    );
    expect(find.text('Make yourself at home'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Mii tester');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Phone, tablet and large text layouts do not overflow', (
    tester,
  ) async {
    await service.createIdentity('Tester');
    for (final size in [
      const Size(390, 844),
      const Size(1280, 900),
      const Size(320, 740),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final section in [
        'chats',
        'nearby',
        'calls',
        'diagnostics',
        'settings',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: miiTheme(Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: MiiShell(service: service, section: section),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$section at $size');
      }
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
  testWidgets('Onboarding golden', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: miiTheme(Brightness.light),
        home: OnboardingScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding.png'),
    );
  });
  testWidgets('Conversation tablet and phone dark goldens', (tester) async {
    await service.createIdentity('Alex');
    await service.send(
      'notes',
      'A little space for thoughts, ideas and the people who matter.',
    );
    await service.db
        .update(service.db.messages)
        .write(
          MessagesCompanion(
            createdAt: Value(
              DateTime(2026, 1, 1, 9, 41).millisecondsSinceEpoch,
            ),
          ),
        );
    await service.refresh();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1440, 980);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: miiTheme(Brightness.light),
        home: MiiShell(service: service, section: 'chats'),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/conversations.png'),
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: miiTheme(Brightness.dark),
        home: MiiShell(service: service, section: 'chats', chatId: 'notes'),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/notes-dark.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
