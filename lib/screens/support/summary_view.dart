import 'package:flutter/material.dart';

import '../../support/support_action.dart';
import '../../support/support_transport.dart';
import '../../theme.dart';
import '../../util/format.dart';
import 'widgets/action_line.dart';
import 'widgets/reference_id_card.dart';

class SummaryView extends StatelessWidget {
  const SummaryView({
    super.key,
    required this.channel,
    required this.duration,
    required this.actions,
    required this.referenceId,
    required this.onStillNeedHelp,
  });

  final SupportChannel channel;
  final Duration duration;
  final List<SupportAction> actions;
  final String? referenceId;
  final VoidCallback onStillNeedHelp;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = switch (channel) {
      SupportChannel.chat => 'Chat ended',
      SupportChannel.voice => 'Call ended · ${formatDuration(duration)}',
    };
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 56),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.ink, fontSize: 20),
              ),
              const SizedBox(height: 20),
              if (actions.isEmpty)
                Text(
                  'No account changes were made.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.muted),
                )
              else
                for (final action in actions) ActionLine(action: action),
              const SizedBox(height: 20),
              if (referenceId case final id?) ReferenceIdCard(id: id),
            ],
          ),
        ),
        // Fixed at the bottom: the secondary action sits above the primary
        // one, which stays closest to the thumb.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: onStillNeedHelp,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Still need help?'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Back to wallet'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
