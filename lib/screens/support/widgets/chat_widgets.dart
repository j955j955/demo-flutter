import 'package:flutter/material.dart';

import '../../../theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text, required this.fromUser, this.announce = false});

  final String text;
  final bool fromUser;

  /// Read out by screen readers as soon as it appears (the newest reply).
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${fromUser ? 'You' : 'Support'}: $text',
      liveRegion: announce,
      excludeSemantics: true,
      child: Align(
        alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: fromUser ? scheme.primary : scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: fromUser ? null : Border.all(color: colors.border),
          ),
          child: Text(
            text,
            style: TextStyle(color: fromUser ? scheme.onPrimary : colors.ink, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class ChatStatus extends StatelessWidget {
  const ChatStatus({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      label,
      style: TextStyle(color: context.colors.muted, fontStyle: FontStyle.italic),
    ),
  );
}

class ChatDividerLine extends StatelessWidget {
  const ChatDividerLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(label, style: TextStyle(color: context.colors.muted, fontSize: 12)),
        ),
        const Expanded(child: Divider()),
      ],
    ),
  );
}
