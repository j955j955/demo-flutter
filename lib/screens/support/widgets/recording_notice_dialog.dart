import 'package:flutter/material.dart';

import '../../../support/support_transport.dart';
import '../../../theme.dart';

/// Shown once per app session before the first chat or call, because the
/// conversation is recorded and processed by service providers.
class RecordingNoticeDialog extends StatelessWidget {
  const RecordingNoticeDialog({super.key, required this.channel});

  final SupportChannel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = channel == SupportChannel.chat ? 'chatting' : 'calling';
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Recording notice', textAlign: TextAlign.center),
      content: Text.rich(
        TextSpan(
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
          children: [
            TextSpan(
              text:
                  'By $action with our AI assistant, you agree that this '
                  'conversation is recorded, stored and processed by Demo Wallet '
                  'and its service providers to resolve your request, as described in our ',
            ),
            const TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(decoration: TextDecoration.underline),
            ),
            const TextSpan(text: ". If you'd rather not be recorded, please don't continue."),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: context.colors.ink),
          child: const Text('Agree'),
        ),
      ],
    );
  }
}
