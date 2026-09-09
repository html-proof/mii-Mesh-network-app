import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../transports/ble/ble_link.dart';
import '../chats/chat_service.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key, required this.service});
  final ChatService service;
  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  late final BleLink link = BleLink(widget.service);
  final input = TextEditingController();
  bool sending = false, reveal = false;
  @override
  void dispose() {
    input.dispose();
    link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: link,
    builder: (_, _) {
      final messages = widget.service.messages
          .where((m) => m.conversationId == 'bluetooth')
          .toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Laptop Bluetooth',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Pill(
                  link.connected ? 'Connected' : 'Direct BLE',
                  icon: Icons.bluetooth,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect this phone to the laptop companion. Nearby devices access lets the phone advertise and communicate over Bluetooth. Keep this screen open; leaving stops the radio.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  link.status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: link.busy
                          ? null
                          : () => runAction(
                              context,
                              link.running ? link.stop : link.start,
                            ),
                      icon: Icon(link.running ? Icons.stop : Icons.bluetooth),
                      label: Text(
                        link.running ? 'Stop Bluetooth' : 'Start Bluetooth',
                      ),
                    ),
                    if (link.pairingSecret != null)
                      TextButton(
                        onPressed: () => setState(() => reveal = !reveal),
                        child: Text(
                          reveal
                              ? 'Hide pairing secret'
                              : 'Show pairing secret',
                        ),
                      ),
                  ],
                ),
                if (reveal && link.pairingSecret != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Enter this secret in your own laptop companion. Anyone with it can read and send messages for this session. Starting again creates a new secret.',
                    style: TextStyle(fontSize: 11),
                  ),
                  SelectableText(
                    link.pairingSecret!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('Your Bluetooth messages will appear here.'),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(18),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[messages.length - i - 1];
                      final incoming = m.status == 'received';
                      return Align(
                        alignment: incoming
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: incoming
                                ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                : Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(m.body),
                              const SizedBox(height: 5),
                              Text(
                                incoming
                                    ? 'Received from laptop · Bluetooth'
                                    : '${m.status} · Bluetooth',
                                style: const TextStyle(fontSize: 10),
                              ),
                              if (m.status == 'failed')
                                TextButton(
                                  onPressed: link.connected
                                      ? () => runAction(
                                          context,
                                          () =>
                                              link.send(m.body, retryId: m.id),
                                        )
                                      : null,
                                  child: const Text('Retry'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 2048,
                    decoration: const InputDecoration(
                      hintText: 'Reply to laptop…',
                      counterText: '',
                    ),
                    enabled: !sending,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send Bluetooth message',
                  onPressed: !link.connected || sending
                      ? null
                      : () async {
                          setState(() => sending = true);
                          await runAction(context, () async {
                            await link.send(input.text);
                            input.clear();
                          });
                          if (mounted) setState(() => sending = false);
                        },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
