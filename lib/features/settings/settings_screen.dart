import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../chats/chat_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.service});
  final ChatService service;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListenableBuilder(
              listenable: service.mesh,
              builder: (_, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nearby messaging'),
                subtitle: const Text(
                  'Reconnect automatically and remain available in the background.',
                ),
                value: service.mesh.running,
                onChanged: service.mesh.busy
                    ? null
                    : (value) => runAction(
                        context,
                        value ? service.mesh.start : service.mesh.stop,
                      ),
              ),
            ),
            ListTile(
              title: const Text('Mesh diagnostics'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/diagnostics'),
            ),
            ListTile(
              title: const Text('Laptop companion (original connection)'),
              trailing: const Icon(Icons.computer),
              onTap: () => context.go('/laptop'),
            ),
            Text(
              'Make it yours.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text('A few thoughtful choices for your local space.'),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xffeadbc6),
                          child: Text(
                            service.profile!.displayName.characters.first
                                .toUpperCase(),
                            style: const TextStyle(color: ink, fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.profile!.displayName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Text(
                                'Local identity · no registration',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'YOUR IDENTITY FINGERPRINT',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      service.fingerprint,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Display names are not unique or verified. This fingerprint identifies your local public key. Contact verification arrives with secure peer messaging.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    const Pill('Backup not available in Phase 1', warm: true),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep your app data. Losing the protected keys permanently loses access to this identity and encrypted database.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final mode in ['system', 'light', 'dark'])
                          ChoiceChip(
                            label: Text(
                              '${mode[0].toUpperCase()}${mode.substring(1)}',
                            ),
                            selected:
                                (service.preferences['theme'] ?? 'system') ==
                                mode,
                            onSelected: (_) => runAction(
                              context,
                              () => service.setPreference('theme', mode),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Pill(
                      'LOCAL LABORATORY',
                      icon: Icons.science_outlined,
                      warm: true,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'See the foundation in action.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Try encrypted test messages, pause the simulator, and restart the app to check the queue. No other device participates. This does not test Bluetooth or real end-to-end delivery.',
                    ),
                    const SizedBox(height: 16),
                    if (!service.conversations.any((c) => c.id == 'laboratory'))
                      FilledButton.icon(
                        onPressed: () => runAction(context, () async {
                          await service.enableLaboratory();
                          if (context.mounted) context.go('/chats/laboratory');
                        }),
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('Enable local test chat'),
                      )
                    else ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Local simulator connected'),
                        subtitle: const Text(
                          'Pause to test persistent offline queuing.',
                        ),
                        value: service.transport.available,
                        onChanged: (value) => runAction(
                          context,
                          () => service.setLaboratoryConnected(value),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/chats/laboratory'),
                        child: const Text('Open local test chat'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Local diagnostics',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      'Encrypted database',
                      'Schema v1 · SQLite3MultipleCiphers',
                    ),
                    _row(
                      'Stored messages',
                      '${service.messages.length} / 10,000',
                    ),
                    _row('Pending or failed', '${service.queuedCount}'),
                    _row('Bluetooth', 'Direct laptop link · Nearby'),
                    _row('Internet relay', 'Not implemented'),
                    _row('Sensitive permissions', 'None requested'),
                    _row('Analytics & cloud backup', 'Not enabled'),
                    const Divider(height: 30),
                    const Text(
                      'Mii Mesh · 0.1.0 · Phase 1',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Experimental and not independently audited. The current encryption protects local storage and simulator traffic. Real peer sessions, forward secrecy, groups, media, and emergency broadcasting are future work.',
                      style: TextStyle(fontSize: 12),
                    ),
                    TextButton(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: 'Mii Mesh',
                        applicationVersion: '0.1.0 experimental',
                      ),
                      child: const Text('Open-source licenses'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    ),
  );
  Widget _row(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        SizedBox(
          width: 185,
          child: Text(title, style: const TextStyle(fontSize: 12)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
