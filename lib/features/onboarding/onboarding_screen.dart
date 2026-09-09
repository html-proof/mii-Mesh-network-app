import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../chats/chat_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.service});
  final ChatService service;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final name = TextEditingController();
  bool accepted = false;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: LayoutBuilder(
              builder: (context, box) {
                final intro = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Pill(
                      'MII MESH  /  EXPERIMENTAL',
                      icon: Icons.hub_outlined,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'A little closer.\nEven offline.',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: 46),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Your conversations. Your device.\nA quieter way to stay connected.',
                      style: TextStyle(fontSize: 18, height: 1.6),
                    ),
                    const Center(child: MeshArt(size: 240)),
                    const Text(
                      'PHASE 01  ·  LOCAL FOUNDATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                );
                final form = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Make yourself at home',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No phone number. No account to create. Your identity is generated and protected on this device.',
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: name,
                          maxLength: 40,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Your display name',
                            hintText: 'What should we call you?',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _Feature(
                          Icons.lock_outline,
                          'A private local space',
                          'Your notes and drafts are encrypted on disk.',
                        ),
                        const _Feature(
                          Icons.bluetooth_disabled,
                          'No permissions needed yet',
                          'Bluetooth messaging arrives in Phase 2. This build only saves locally and runs optional tests.',
                        ),
                        const _Feature(
                          Icons.key_outlined,
                          'Keep this device safe',
                          'Identity backup is not available yet. Uninstalling or losing your keys can permanently lose your identity and chats.',
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: accepted,
                          onChanged: (v) => setState(() => accepted = v!),
                          title: const Text(
                            'I understand this is an unaudited experimental build.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: accepted && !busy
                                ? () async {
                                    setState(() => busy = true);
                                    await runAction(
                                      context,
                                      () => widget.service.createIdentity(
                                        name.text,
                                      ),
                                    );
                                    if (mounted) setState(() => busy = false);
                                  }
                                : null,
                            child: Text(
                              busy
                                  ? 'Creating your local identity…'
                                  : 'Create my local identity',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'No analytics. No cloud backup. No registration.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                return box.maxWidth >= 750
                    ? Row(
                        children: [
                          Expanded(child: intro),
                          const SizedBox(width: 48),
                          Expanded(child: form),
                        ],
                      )
                    : Column(
                        children: [intro, const SizedBox(height: 28), form],
                      );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.6)),
            ],
          ),
        ),
      ],
    ),
  );
}
