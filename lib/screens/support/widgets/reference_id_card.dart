import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme.dart';

class ReferenceIdCard extends StatelessWidget {
  const ReferenceIdCard({super.key, required this.id});

  final String id;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Reference ID copied')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _copy(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reference ID', style: TextStyle(color: colors.muted, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(id, style: AppTheme.mono.copyWith(color: colors.ink, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to copy. Mention it if you contact us again.',
                      style: TextStyle(color: colors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy, color: colors.muted, semanticLabel: 'Copy'),
            ],
          ),
        ),
      ),
    );
  }
}
