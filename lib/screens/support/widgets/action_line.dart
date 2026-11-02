import 'package:flutter/material.dart';

import '../../../support/support_action.dart';
import '../../../theme.dart';

/// One-line receipt for an action that really happened ("Card frozen").
class ActionLine extends StatelessWidget {
  const ActionLine({super.key, required this.action, this.compact = false});

  final SupportAction action;

  /// A pill inside the chat rather than a full-width row.
  final bool compact;

  static IconData iconFor(SupportActionType type) => switch (type) {
    SupportActionType.identityVerified => Icons.verified_user,
    SupportActionType.cardFrozen => Icons.ac_unit,
    SupportActionType.disputeOpened => Icons.gavel,
    SupportActionType.accountSecured => Icons.lock_reset,
    SupportActionType.caseCreated => Icons.support_agent,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: compact ? 4 : 5),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 6 : 11),
        decoration: BoxDecoration(
          color: colors.receipt,
          borderRadius: BorderRadius.circular(compact ? 20 : 12),
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(
              iconFor(action.type),
              color: Theme.of(context).colorScheme.primary,
              size: compact ? 16 : 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                action.label,
                style: TextStyle(
                  color: colors.onReceipt,
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
