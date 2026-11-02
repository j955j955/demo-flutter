import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../../../util/format.dart';
import '../../../wallet/models.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction, required this.now, this.onTap});

  final Transaction transaction;
  final DateTime now;
  final VoidCallback? onTap;

  static IconData iconFor(TxCategory category) => switch (category) {
    TxCategory.digitalGoods => Icons.sports_esports_outlined,
    TxCategory.foodAndDrink => Icons.local_cafe_outlined,
    TxCategory.transport => Icons.directions_subway_outlined,
    TxCategory.groceries => Icons.shopping_basket_outlined,
    TxCategory.income => Icons.account_balance_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final scheme = Theme.of(context).colorScheme;
    final amount = formatCents(tx.amountCents.abs());
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: tx.status == TxStatus.flagged
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest,
        child: Icon(iconFor(tx.category), size: 20),
      ),
      title: Text(tx.merchant),
      subtitle: Text(shortDate(tx.date, now: now)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            tx.isDebit ? '-$amount' : '+$amount',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tx.isDebit ? null : context.colors.income,
            ),
          ),
          if (tx.status != TxStatus.posted)
            Text(
              tx.status == TxStatus.flagged ? 'Review' : 'Disputed',
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
        ],
      ),
    );
  }
}
