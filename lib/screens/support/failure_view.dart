import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

class FailureView extends StatelessWidget {
  const FailureView({
    super.key,
    required this.message,
    required this.diagnostics,
    required this.onRetry,
  });

  final String message;

  /// Copyable details for support. Contains nothing that identifies the
  /// customer.
  final String diagnostics;
  final VoidCallback onRetry;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: diagnostics));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Details copied')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.wifi_off, color: colors.muted, size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.ink, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'You can try again, or copy the details below and send them to us.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(color: colors.canvas, borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              diagnostics,
              style: AppTheme.mono.copyWith(color: colors.ink, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copy details'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
