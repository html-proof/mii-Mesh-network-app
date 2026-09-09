import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/database/database.dart';
import 'chat_service.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key, required this.service, this.chatId});
  final ChatService service;
  final String? chatId;
  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final selected = service.conversations
        .where((c) => c.id == widget.chatId)
        .firstOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    if (selected != null && !wide) {
      return ConversationView(
        key: ValueKey(selected.id),
        service: service,
        conversation: selected,
      );
    }
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Conversations',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const Pill('ON DEVICE', icon: Icons.lock_outline),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            onChanged: (v) => setState(() => query = v.toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Search your local conversations',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'YOUR CONVERSATIONS  ·  ${service.conversations.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              for (final c in service.conversations.where(
                (c) =>
                    c.title.toLowerCase().contains(query) ||
                    service.messages.any(
                      (m) =>
                          m.conversationId == c.id &&
                          m.body.toLowerCase().contains(query),
                    ),
              ))
                Card(
                  color: c.id == widget.chatId
                      ? Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: .4)
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: c.kind == 'notes'
                          ? const Color(0xffe9eddf)
                          : const Color(0xfff7e7d7),
                      child: Icon(
                        c.kind == 'notes'
                            ? Icons.bookmark_border
                            : c.kind == 'bluetooth'
                            ? Icons.bluetooth
                            : Icons.science_outlined,
                        color: ink,
                      ),
                    ),
                    title: Text(
                      c.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        service.messages
                                .where((m) => m.conversationId == c.id)
                                .lastOrNull
                                ?.body ??
                            (c.kind == 'notes'
                                ? 'A little space for your thoughts'
                                : c.kind == 'bluetooth'
                                ? 'Direct Bluetooth · laptop companion'
                                : 'Simulation · no remote device'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.go(
                      c.kind == 'bluetooth' ? '/nearby' : '/chats/${c.id}',
                    ),
                  ),
                ),
              if (query.isNotEmpty &&
                  !service.conversations.any(
                    (c) =>
                        c.title.toLowerCase().contains(query) ||
                        service.messages.any(
                          (m) =>
                              m.conversationId == c.id &&
                              m.body.toLowerCase().contains(query),
                        ),
                  ))
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('No local conversations match your search.'),
                ),
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.eco_outlined, size: 25),
                    const SizedBox(height: 14),
                    const Text(
                      'Your space, from the start.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Save a thought or try a local test chat. Your data stays on this device.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.arrow_forward, size: 17),
                      label: const Text('Explore the foundation'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 13),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${service.queuedCount} pending · encrypted local storage',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (!wide) return list;
    return Row(
      children: [
        SizedBox(width: 400, child: list),
        VerticalDivider(
          width: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: .15),
        ),
        Expanded(
          child: selected != null
              ? ConversationView(
                  key: ValueKey(selected.id),
                  service: service,
                  conversation: selected,
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Pill('LESS NOISE. MORE CONNECTION.'),
                        const MeshArt(size: 290),
                        Text(
                          'A space to stay close.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Open a conversation to begin.\nFor now, everything stays right here.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 26),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/chats/notes'),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Write a note'),
                        ),
                        const SizedBox(height: 36),
                        const Pill(
                          'Experimental · not security audited',
                          warm: true,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.service,
    required this.conversation,
  });
  final ChatService service;
  final Conversation conversation;
  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  late final TextEditingController controller = TextEditingController(
    text: widget.conversation.draft,
  );
  bool busy = false;
  bool get local => widget.conversation.kind == 'notes';
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || controller.text.trim().isEmpty) return;
    setState(() => busy = true);
    await runAction(context, () async {
      await widget.service.send(widget.conversation.id, controller.text);
      controller.clear();
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final messages = service.messages
        .where((m) => m.conversationId == widget.conversation.id)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.go('/chats'),
                tooltip: 'Back to conversations',
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                backgroundColor: const Color(0xffe6eddf),
                child: Icon(
                  local ? Icons.bookmark_border : Icons.science_outlined,
                  color: ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.conversation.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      local
                          ? 'Only on this device'
                          : 'Simulation · no remote identity',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!local)
                IconButton(
                  tooltip: service.transport.available
                      ? 'Pause test transport'
                      : 'Resume test transport',
                  onPressed: () => runAction(
                    context,
                    () => service.setLaboratoryConnected(
                      !service.transport.available,
                    ),
                  ),
                  icon: Icon(
                    service.transport.available
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: Theme.of(context).colorScheme.primaryContainer
              .withValues(alpha: .25),
          child: Text(
            local
                ? 'Encrypted on this device. Notes are never transmitted.'
                : service.transport.available
                ? 'Local test only · delivery means the simulator decrypted your message. Messages expire in 24 hours.'
                : 'Test transport paused · messages stay queued here, including after restart. Messages expire in 24 hours.',
            style: const TextStyle(fontSize: 11, height: 1.6),
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          local ? Icons.edit_note : Icons.forum_outlined,
                          size: 52,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          local
                              ? 'Room for a thought.'
                              : 'Try your first test message.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          local
                              ? 'Notes, ideas, little reminders.\nThey all belong here.'
                              : 'This conversation runs entirely on your device.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(24),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[messages.length - 1 - i];
                    final time = TimeOfDay.fromDateTime(
                      DateTime.fromMillisecondsSinceEpoch(m.createdAt),
                    ).format(context);
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 480),
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(17, 12, 8, 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                  bottomRight: Radius.circular(5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: SelectableText(
                                      m.body,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Message actions',
                                    padding: EdgeInsets.zero,
                                    iconSize: 16,
                                    constraints: const BoxConstraints(
                                      minWidth: 160,
                                    ),
                                    onSelected: (action) => runAction(
                                      context,
                                      () => switch (action) {
                                        'retry' => service.retry(m.id),
                                        'cancel' => service.cancel(m.id),
                                        _ => service.deleteMessage(m.id),
                                      },
                                    ),
                                    itemBuilder: (_) => [
                                      if (m.status == 'failed')
                                        const PopupMenuItem(
                                          value: 'retry',
                                          child: Text('Retry'),
                                        ),
                                      if (m.status == 'queued' ||
                                          m.status == 'failed')
                                        const PopupMenuItem(
                                          value: 'cancel',
                                          child: Text('Cancel delivery'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete locally'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$time · ${m.status == 'delivered' ? 'Delivered to local simulator' : m.status}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2048,
                  onChanged: (value) => runAction(
                    context,
                    () => service.saveDraft(widget.conversation.id, value),
                  ),
                  decoration: InputDecoration(
                    hintText: local
                        ? 'Save a thought…'
                        : 'Write a test message…',
                    counterText: '',
                    helperText: local
                        ? 'Saved locally · no expiration'
                        : 'Text only · local test transport',
                    helperStyle: const TextStyle(fontSize: 10),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 23),
                child: IconButton.filled(
                  onPressed: busy ? null : send,
                  tooltip: local ? 'Save note' : 'Send test message',
                  icon: Icon(busy ? Icons.hourglass_empty : Icons.arrow_upward),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
