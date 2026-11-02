import 'package:flutter/material.dart';

import '../../../support/support_transport.dart';
import '../../../util/format.dart';
import '../../../wallet/models.dart';

/// Chat or call, chosen before anything connects, so a support button never
/// starts a voice call by surprise.
class SupportOptionsSheet extends StatelessWidget {
  const SupportOptionsSheet({super.key, this.transaction});

  final Transaction? transaction;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How would you like to get help?', style: theme.textTheme.titleLarge),
            if (tx != null) ...[
              const SizedBox(height: 4),
              Text(
                'About ${formatCents(tx.amountCents.abs())} at ${tx.merchant}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.chat_bubble_outline,
              title: 'Chat',
              onTap: () => Navigator.pop(context, SupportChannel.chat),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.call_outlined,
              title: 'Call',
              onTap: () => Navigator.pop(context, SupportChannel.voice),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
