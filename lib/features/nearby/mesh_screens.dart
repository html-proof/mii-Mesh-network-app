import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/database/database.dart';
import '../../transports/mesh/mesh_protocol.dart';
import '../../transports/mesh/mesh_service.dart';
import '../chats/chat_service.dart';

class MeshNearbyScreen extends StatelessWidget {
  const MeshNearbyScreen({super.key, required this.service});
  final ChatService service;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service.mesh,
    builder: (_, _) {
      final mesh = service.mesh;
      final peers = mesh.peers
        ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Nearby', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          if (!mesh.running) ...[
            const SizedBox(height: 24),
            const Icon(Icons.bluetooth, size: 44),
            const SizedBox(height: 16),
            const Text(
              'Mii uses Bluetooth to find and communicate with nearby people. Private messages stay encrypted between participating devices.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: mesh.busy
                  ? null
                  : () => runAction(context, mesh.start),
              child: const Text('Enable Bluetooth'),
            ),
            const SizedBox(height: 12),
            Text(mesh.status),
          ] else if (mesh.status.contains('off')) ...[
            const Text(
              'Bluetooth is off. Turn it on to discover nearby people.',
            ),
            FilledButton(
              onPressed: () => runAction(
                context,
                () => MeshService.channel.invokeMethod<void>('enable'),
              ),
              child: const Text('Turn on Bluetooth'),
            ),
          ] else if (peers.isEmpty) ...[
            const SizedBox(height: 60),
            const Icon(Icons.people_outline, size: 48),
            const SizedBox(height: 16),
            const Text('No one nearby yet.', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Open Mii Mesh on another phone and enable Bluetooth. People appear automatically.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(mesh.summary, textAlign: TextAlign.center),
          ],
          for (final peer in peers)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              leading: CircleAvatar(
                child: Text(peer.name.characters.first.toUpperCase()),
              ),
              title: Text(peer.name),
              subtitle: Text(peer.availability),
              trailing: Icon(
                Icons.circle,
                size: 10,
                color: peer.reachable ? teal : Colors.grey,
              ),
              onTap: () async {
                await mesh.ensureConversation(peer);
                await service.refresh();
                if (context.mounted) {
                  context.go(
                    '/chats/${Uri.encodeComponent('mesh:${peer.id}')}',
                  );
                }
              },
            ),
        ],
      );
    },
  );
}

String messagePreview(Message message) {
  if (!message.conversationId.startsWith('mesh:')) return message.body;
  try {
    final c = MeshContent.fromStored(message.body);
    return c.kind == 'sticker'
        ? '${meshStickers[c.body]} Sticker'
        : c.kind == 'reaction'
        ? '${c.body} Reaction'
        : c.body;
  } catch (_) {
    return 'Message unavailable';
  }
}

class SimpleChats extends StatefulWidget {
  const SimpleChats({super.key, required this.service});
  final ChatService service;
  @override
  State<SimpleChats> createState() => _SimpleChatsState();
}

class _SimpleChatsState extends State<SimpleChats> {
  String query = '';
  ChatService get service => widget.service;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Chats',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          IconButton(
            tooltip: 'Find nearby people',
            onPressed: () => context.go('/nearby'),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        onChanged: (value) => setState(() => query = value.toLowerCase()),
        decoration: const InputDecoration(
          hintText: 'Search conversations',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 12),
      for (final conversation in service.conversations.where(
        (c) =>
            c.title.toLowerCase().contains(query) ||
            service.messages.any(
              (m) =>
                  m.conversationId == c.id &&
                  messagePreview(m).toLowerCase().contains(query),
            ),
      ))
        Builder(
          builder: (context) {
            final history = service.messages
                .where((m) => m.conversationId == conversation.id)
                .toList();
            final last = history.lastOrNull;
            final peer = service
                .mesh
                .router
                ?.peers[conversation.id.replaceFirst('mesh:', '')];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              leading: CircleAvatar(
                child: Icon(
                  conversation.kind == 'notes'
                      ? Icons.bookmark_outline
                      : conversation.kind == 'laboratory'
                      ? Icons.science_outlined
                      : Icons.person_outline,
                ),
              ),
              title: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                last == null
                    ? (peer?.availability ?? 'Open conversation')
                    : '${messagePreview(last)}\n${last.status == 'queued'
                          ? 'Queued · waiting for connection'
                          : last.status == 'delivered'
                          ? 'Delivered'
                          : peer?.availability ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(
                conversation.kind == 'bluetooth'
                    ? '/laptop'
                    : '/chats/${Uri.encodeComponent(conversation.id)}',
              ),
            );
          },
        ),
    ],
  );
}

class MeshConversationScreen extends StatefulWidget {
  const MeshConversationScreen({
    super.key,
    required this.service,
    required this.peerId,
  });
  final ChatService service;
  final String peerId;
  @override
  State<MeshConversationScreen> createState() => _MeshConversationScreenState();
}

class _MeshConversationScreenState extends State<MeshConversationScreen> {
  final input = TextEditingController();
  bool sending = false;
  MeshService get mesh => widget.service.mesh;
  @override
  void initState() {
    super.initState();
    input.text =
        widget.service.conversations
            .where((c) => c.id == 'mesh:${widget.peerId}')
            .firstOrNull
            ?.draft ??
        '';
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send(
    MeshPeer peer,
    String body, {
    String kind = 'text',
    String reference = '',
  }) async {
    if (sending) return;
    setState(() => sending = true);
    await runAction(context, () async {
      await mesh.send(peer, body, kind: kind, reference: reference);
      if (kind == 'text') {
        input.clear();
        await widget.service.saveDraft('mesh:${peer.id}', '');
      }
    });
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: mesh,
    builder: (_, _) {
      final peer = mesh.router?.peers[widget.peerId];
      if (peer == null) {
        return const Center(
          child: Text(
            'This person is not available yet. Open Nearby to reconnect.',
          ),
        );
      }
      final history = widget.service.messages
          .where((m) => m.conversationId == 'mesh:${peer.id}')
          .toList();
      final texts = history
          .where((m) => MeshContent.fromStored(m.body).kind != 'reaction')
          .toList();
      return Column(
        children: [
          ListTile(
            leading: IconButton(
              tooltip: 'Back to chats',
              onPressed: () => context.go('/chats'),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(peer.name),
            subtitle: Text(peer.availability),
            trailing: IconButton(
              tooltip: 'View identity',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(peer.name),
                  content: SelectableText(
                    'Compare this fingerprint in person.\n\n${widget.service.vault.fingerprint(peer.boxKey)}\n\nA nearby name does not verify who owns a phone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.info_outline),
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: texts.length,
              itemBuilder: (_, index) {
                final message = texts[texts.length - index - 1];
                final content = MeshContent.fromStored(message.body);
                final incoming = message.status == 'received';
                final reactions = <String, String>{};
                for (final m in history) {
                  final c = MeshContent.fromStored(m.body);
                  if (c.kind == 'reaction' && c.reference == message.id) {
                    reactions[m.status == 'received' ? 'peer' : 'self'] =
                        c.body;
                  }
                }
                return Align(
                  alignment: incoming
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Semantics(
                    label:
                        '${incoming ? peer.name : 'You'}: ${messagePreview(message)}. ${message.status}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onLongPress: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (sheet) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                for (final reaction in meshReactions)
                                  IconButton(
                                    tooltip: 'React $reaction',
                                    onPressed: () {
                                      Navigator.pop(sheet);
                                      send(
                                        peer,
                                        reaction,
                                        kind: 'reaction',
                                        reference: message.id,
                                      );
                                    },
                                    icon: Text(
                                      reaction,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: incoming
                              ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                              : Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              content.kind == 'sticker'
                                  ? meshStickers[content.body]!
                                  : content.body,
                              style: TextStyle(
                                fontSize: content.kind == 'sticker' ? 56 : 16,
                              ),
                            ),
                            if (reactions.isNotEmpty)
                              Text(reactions.values.join(' ')),
                            const SizedBox(height: 5),
                            Text(
                              incoming
                                  ? 'Received'
                                  : message.status == 'queued'
                                  ? 'Queued · waiting for receipt'
                                  : message.status,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Stickers',
                    onPressed: sending
                        ? null
                        : () => showModalBottomSheet<void>(
                            context: context,
                            builder: (sheet) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Mii essentials · available offline',
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 12,
                                      children: [
                                        for (final sticker
                                            in meshStickers.entries)
                                          IconButton(
                                            tooltip: sticker.key,
                                            onPressed: () {
                                              Navigator.pop(sheet);
                                              send(
                                                peer,
                                                sticker.key,
                                                kind: 'sticker',
                                              );
                                            },
                                            icon: Text(
                                              sticker.value,
                                              style: const TextStyle(
                                                fontSize: 32,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2048,
                      enabled: !sending,
                      onChanged: (value) =>
                          widget.service.saveDraft('mesh:${peer.id}', value),
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: sending ? null : () => send(peer, input.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class MeshDiagnostics extends StatelessWidget {
  const MeshDiagnostics({super.key, required this.service});
  final ChatService service;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service.mesh,
    builder: (_, _) {
      final m = service.mesh;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Mesh diagnostics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Bluetooth: ${m.status}\nDirect links: ${m.router?.links.length ?? 0}\nKnown peers: ${m.peers.length}\nPending envelopes: ${m.router?.pending.length ?? 0}\nRelayed: ${m.router?.relayed ?? 0}\nRejected: ${m.router?.dropped ?? 0}',
          ),
          const SizedBox(height: 20),
          for (final p in m.peers)
            ListTile(
              title: Text(p.name),
              subtitle: SelectableText(
                '${p.id}\n${p.availability} · ${p.hops} relay hops\nLast seen: ${p.lastSeen == 0 ? 'Offline' : DateTime.fromMillisecondsSinceEpoch(p.lastSeen)}',
              ),
            ),
        ],
      );
    },
  );
}
