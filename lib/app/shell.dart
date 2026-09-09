import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/chats/chat_service.dart';
import '../features/chats/chat_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/nearby/bluetooth_screen.dart';
import '../features/nearby/mesh_screens.dart';
import '../features/calls/calls_screen.dart';
import 'theme.dart';

const destinations = [
  ('chats', 'Chats', Icons.chat_bubble_outline),
  ('nearby', 'Nearby', Icons.radar),
  ('calls', 'Calls', Icons.call_outlined),
];

class MiiShell extends StatelessWidget {
  const MiiShell({
    super.key,
    required this.service,
    required this.section,
    this.chatId,
  });
  final ChatService service;
  final String section;
  final String? chatId;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    final index = destinations.indexWhere((d) => d.$1 == section);
    final selected = index < 0 ? 0 : index;
    final page = switch (section) {
      'chats' =>
        chatId == null
            ? SimpleChats(service: service)
            : chatId!.startsWith('mesh:')
            ? MeshConversationScreen(
                service: service,
                peerId: chatId!.substring(5),
              )
            : ChatsPage(service: service, chatId: chatId),
      'settings' => SettingsScreen(service: service),
      'nearby' => MeshNearbyScreen(service: service),
      'laptop' => BluetoothScreen(service: service),
      'diagnostics' => MeshDiagnostics(service: service),
      'calls' => CallsPage(service: service),
      _ => ChatsPage(service: service),
    };
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 226,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: .15),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: _Brand(),
                      ),
                      const SizedBox(height: 48),
                      const Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 14),
                        child: Text(
                          'YOUR SPACE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                      for (var i = 0; i < destinations.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              selected: selected == i,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: .45),
                              leading: Icon(destinations[i].$3, size: 21),
                              title: Text(
                                destinations[i].$2,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => context.go('/${destinations[i].$1}'),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Pill('LOCAL FOUNDATION', icon: Icons.spa_outlined),
                            SizedBox(height: 10),
                            Text(
                              'Small beginnings.\nMeaningful connections.',
                              style: TextStyle(fontSize: 12, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xffeddfcb),
                            child: Text(
                              service.profile!.displayName.characters.first
                                  .toUpperCase(),
                              style: const TextStyle(color: ink),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              service.profile!.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.lock_outline, size: 15),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 32 : 22,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!wide)
                              const _Brand()
                            else
                              Text(
                                'A little closer, wherever you are.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Settings',
                              onPressed: () => context.go('/settings'),
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ListenableBuilder(
                          listenable: service.mesh,
                          builder: (_, _) => Text(
                            service.mesh.summary,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (service.backgroundError != null)
                    MaterialBanner(
                      content: Text(service.backgroundError!),
                      actions: [
                        TextButton(
                          onPressed: () => runAction(context, service.pump),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  Expanded(child: page),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide || chatId != null
          ? null
          : NavigationBar(
              selectedIndex: selected,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (i) =>
                  context.go('/${destinations[i].$1}'),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(icon: Icon(d.$3), label: d.$2),
              ],
            ),
    );
  }
}

/// Human-readable mesh status shown under the title. Networking terminology
/// stays out of this line by design; it maps internal transport state into
/// plain words. Phase 2 replaces the static state with a live listener on the
/// mesh service (green + nearby count / amber searching / red Bluetooth off).
class MeshStatusLine extends StatelessWidget {
  const MeshStatusLine({super.key, this.color, this.label});
  final Color? color;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final dot = color ?? const Color(0xff9aa5a0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label ?? 'Bluetooth mesh not started',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: teal,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.hub_outlined, color: Colors.white, size: 21),
      ),
      const SizedBox(width: 10),
      const Text(
        'mii',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
      ),
      const SizedBox(width: 6),
      const Text(
        'mesh',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      ),
    ],
  );
}

class CapabilityPage extends StatelessWidget {
  const CapabilityPage({super.key, required this.kind});
  final String kind;
  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon, phase, detail) = switch (kind) {
      'nearby' => (
        'Good connections\nstart nearby.',
        'Your neighborhood, within reach.',
        Icons.radar,
        'PHASE 02',
        'Bluetooth discovery is not included in this build. No scan is running and no nearby devices are being detected. Android BLE discovery and direct messaging are the next phase.',
      ),
      'channels' => (
        'Find your\ncommon ground.',
        'Spaces for the things you share.',
        Icons.tag,
        'PHASE 04',
        'Public channels and encrypted groups are not available yet. Group membership, verification, and key rotation must be implemented and tested before channels can open.',
      ),
      _ => (
        'Look out for\none another.',
        'Stay thoughtful. Stay prepared.',
        Icons.health_and_safety_outlined,
        'PHASE 07',
        'SOS broadcasting is not available in this build. Mii Mesh cannot send an emergency alert or contact emergency services. Use your phone’s normal emergency calling feature when you need help.',
      ),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Pill('$phase  /  PLANNED', warm: true),
              const SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 14),
              Text(subtitle, style: const TextStyle(fontSize: 17)),
              const Center(child: MeshArt(size: 280)),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Not active in the local foundation',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(detail),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (kind == 'nearby')
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      Text('0 observed peers'),
                      Text('Bluetooth: not started'),
                      Text('Internet relay: not implemented'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
