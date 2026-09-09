import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chats/chat_service.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'shell.dart';
import 'theme.dart';

final serviceProvider = FutureProvider<ChatService>((ref) async {
  final service = await ChatService.open();
  ref.onDispose(() {
    service.close();
  });
  return service;
});

class MiiApp extends ConsumerStatefulWidget {
  const MiiApp({super.key});
  @override
  ConsumerState<MiiApp> createState() => _MiiAppState();
}

class _MiiAppState extends ConsumerState<MiiApp> {
  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const _Gate(section: 'chats'),
      ),
      GoRoute(
        path: '/:section',
        builder: (_, state) => _Gate(section: state.pathParameters['section']!),
      ),
      GoRoute(
        path: '/chats/:id',
        builder: (_, state) =>
            _Gate(section: 'chats', chatId: state.pathParameters['id']),
      ),
    ],
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncService = ref.watch(serviceProvider);
    final service = asyncService.asData?.value;
    Widget app() => MaterialApp.router(
      title: 'Mii Mesh',
      debugShowCheckedModeBanner: false,
      theme: miiTheme(Brightness.light),
      darkTheme: miiTheme(Brightness.dark),
      themeMode: switch (service?.preferences['theme']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      routerConfig: router,
    );
    return service == null
        ? app()
        : ListenableBuilder(listenable: service, builder: (_, _) => app());
  }
}

class _Gate extends ConsumerWidget {
  const _Gate({required this.section, this.chatId});
  final String section;
  final String? chatId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(serviceProvider)
      .when(
        loading: () => const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MeshArt(size: 150),
                SizedBox(height: 20),
                Text('Opening your local space…'),
                SizedBox(height: 20),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
        error: (_, _) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 44),
                    const SizedBox(height: 20),
                    const Text(
                      'Your local vault could not be opened.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Secure storage or the encryption library is unavailable. Your existing data has not been replaced. If this continues, keep your app data and seek support.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => ref.invalidate(serviceProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        data: (service) => ListenableBuilder(
          listenable: service,
          builder: (_, _) => service.profile == null
              ? OnboardingScreen(service: service)
              : MiiShell(service: service, section: section, chatId: chatId),
        ),
      );
}
