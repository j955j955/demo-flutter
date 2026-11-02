import 'package:flutter/material.dart';

import '../../../util/format.dart';
import '../../../wallet/models.dart';

class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key, required this.transaction, required this.onReport});

  final Transaction transaction;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tx = transaction;
    return Card(
      elevation: 0,
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unusual charge detected',
                    style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ['${formatCents(tx.amountCents.abs())} at ${tx.merchant}', ?tx.detail].join(' · '),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onReport,
              icon: const Icon(Icons.report_outlined),
              label: const Text("This wasn't me"),
            ),
          ],
        ),
      ),
    );
  }
}
