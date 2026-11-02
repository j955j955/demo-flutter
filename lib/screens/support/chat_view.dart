import 'package:flutter/material.dart';

import '../../support/support_session.dart';
import '../../theme.dart';
import 'widgets/action_line.dart';
import 'widgets/chat_widgets.dart';

/// A connecting or live chat.
class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.session});

  final SupportSession session;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _scroll = ScrollController();
  late final TextEditingController _input;
  int _shownEntries = 0;

  SupportSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: _session.draft)
      ..addListener(() => _session.saveDraft(_input.text));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _send() {
    if (_session.send(_input.text)) {
      _input.clear();
    } else if (_input.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Not connected. Your message was kept.')));
    }
  }

  void _followNewEntries() {
    final count = _session.chat.length;
    if (count == _shownEntries) return;
    final animate = _shownEntries > 0;
    _shownEntries = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(end, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _followNewEntries();
    final entries = _session.chat;
    final live = _session.state is SessionLive;
    final status = switch (_session.state) {
      SessionLive() when _session.awaitingReply => 'Typing…',
      SessionLive() => null,
      _ => 'Connecting…',
    };
    final lastAgentIndex = entries.lastIndexWhere((e) => e is ChatMessage && !e.fromUser);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: entries.length + (status == null ? 0 : 1),
            itemBuilder: (context, i) {
              if (i == entries.length) return ChatStatus(label: status!);
              return switch (entries[i]) {
                ChatMessage(:final fromUser, :final text) => ChatBubble(
                  text: text,
                  fromUser: fromUser,
                  announce: i == lastAgentIndex,
                ),
                ChatActionEntry(:final action) => Center(
                  child: ActionLine(action: action, compact: true),
                ),
                ChatDivider(:final label) => ChatDividerLine(label: label),
              };
            },
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: context.colors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: live,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: live ? 'Message' : 'Connecting…',
                      filled: true,
                      fillColor: context.colors.canvas,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Send',
                  onPressed: live ? _send : null,
                  icon: const Icon(Icons.send_rounded),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
