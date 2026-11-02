import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../../../util/format.dart';
import '../../../wallet/wallet_state.dart';

class CardView extends StatelessWidget {
  const CardView({super.key, required this.wallet});

  final WalletState wallet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frozen = wallet.cardFrozen;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      // A minimum, not a fixed height, so large text sizes grow the card
      // instead of overflowing it.
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: frozen ? colors.cardFrozen : colors.cardActive,
        ),
      ),
      child: IntrinsicHeight(
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Debit card',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(frozen: frozen),
                ],
              ),
              const Spacer(),
              const SizedBox(height: 24),
              Text(
                formatCents(wallet.balanceCents),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '•••• ${wallet.cardLast4}  ·  ${wallet.customerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.frozen});

  final bool frozen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(frozen ? Icons.ac_unit : Icons.check_circle, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            frozen ? 'Frozen' : 'Active',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
