import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../chats/chat_service.dart';

/// Calls tab. Voice calling establishes a direct high-bandwidth peer-to-peer
/// transport once both sides accept over the mesh; that transport and the
/// call history store are later phases. For now this surfaces the feature
/// honestly with an empty state rather than pretending calls already work.
class CallsPage extends StatelessWidget {
  const CallsPage({super.key, required this.service});
  final ChatService service;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Calls',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const Pill('DIRECT AUDIO', icon: Icons.call_outlined),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MeshArt(size: 220),
                    const SizedBox(height: 8),
                    Text(
                      'Voice calls are not available yet.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Messaging and stickers are available through Nearby. '
                      'Direct audio and incoming-call handling still need implementation and device testing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Voice will need a separate direct connection. '
                                'This build does not transmit call audio over the mesh.',
                                style: TextStyle(fontSize: 12, height: 1.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
