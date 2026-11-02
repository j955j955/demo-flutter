import 'package:flutter/material.dart';

import '../../support/support_hub.dart';
import '../../util/format.dart';
import '../../wallet/models.dart';
import '../../wallet/wallet_state.dart';
import '../support/support_entry.dart';
import 'widgets/alert_banner.dart';
import 'widgets/card_view.dart';
import 'widgets/info_banner.dart';
import 'widgets/profile_sheet.dart';
import 'widgets/support_fab.dart';
import 'widgets/transaction_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _editName(BuildContext context, WalletState wallet) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProfileSheet(initialName: wallet.customerName),
    );
    if (name != null) wallet.updateName(name);
  }

  /// Hidden demo control: long-press the title to restore the demo data.
  void _resetDemo(BuildContext context) {
    SupportScope.read(context).reset();
    WalletScope.read(context).resetDemo();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo data reset')));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = WalletScope.of(context);
    final flagged = wallet.flaggedTransaction;
    final now = DateTime.now();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: GestureDetector(
          onLongPress: () => _resetDemo(context),
          child: const Text(
            'Demo Wallet',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Edit profile',
              onPressed: () => _editName(context, wallet),
              icon: CircleAvatar(radius: 16, child: Text(wallet.initial)),
            ),
          ),
        ],
      ),
      floatingActionButton: const SupportFab(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          Text('${greeting(now)}, ${wallet.firstName}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          CardView(wallet: wallet),
          const SizedBox(height: 16),
          if (flagged != null)
            AlertBanner(
              transaction: flagged,
              onReport: () => openSupport(context, transaction: flagged),
            ),
          if (wallet.accountSecured)
            const InfoBanner(
              icon: Icons.verified_user,
              text: 'Account secured. Other devices were signed out.',
            ),
          for (final supportCase in wallet.cases)
            InfoBanner(
              icon: Icons.confirmation_number_outlined,
              text: 'Case ${supportCase.id} · a specialist will follow up',
            ),
          const SizedBox(height: 8),
          Text('Recent activity', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                for (final tx in wallet.transactions)
                  TransactionTile(
                    transaction: tx,
                    now: now,
                    onTap: tx.status == TxStatus.flagged
                        ? () => openSupport(context, transaction: tx)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
