import 'package:demo_wallet/wallet/models.dart';
import 'package:demo_wallet/wallet/wallet_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WalletState wallet;
  setUp(() => wallet = WalletState(clock: () => DateTime(2026, 11, 2, 11)));

  test('state can only change through methods, and lists are read-only', () {
    expect(() => wallet.transactions.clear(), throwsUnsupportedError);
    expect(() => wallet.cases.clear(), throwsUnsupportedError);
  });

  test('freezing twice changes nothing the second time', () {
    expect(wallet.freezeCard(), isTrue);
    expect(wallet.freezeCard(), isFalse);
    expect(wallet.cardFrozen, isTrue);
  });

  test('disputes: opened once, never for income or unknown IDs', () {
    final flagged = wallet.flaggedTransaction!;
    final first = wallet.disputeTransaction(flagged.id);
    expect(first.outcome, DisputeOutcome.opened);
    expect(first.transaction!.status, TxStatus.disputed);
    expect(wallet.flaggedTransaction, isNull);
    expect(wallet.disputeTransaction(flagged.id).outcome, DisputeOutcome.alreadyDisputed);

    final income = wallet.transactions.firstWhere((tx) => !tx.isDebit);
    expect(wallet.disputeTransaction(income.id).outcome, DisputeOutcome.notDisputable);
    expect(wallet.disputeTransaction('tx_nope').outcome, DisputeOutcome.notFound);
  });

  test('cases parse the agent\'s values and fall back safely', () {
    expect(CaseCategory.parse('account_security'), CaseCategory.accountSecurity);
    expect(CaseCategory.parse('something else'), CaseCategory.other);
    expect(CasePriority.parse(null), CasePriority.normal);
    final c = wallet.openCase(
      category: CaseCategory.fraud,
      summary: 'Unrecognized charge',
      priority: CasePriority.urgent,
      conversationId: 'conv_1',
    );
    expect(wallet.cases.single, same(c));
    expect(c.createdAt, DateTime(2026, 11, 2, 11));
  });

  test('resetDemo restores the original state', () {
    wallet
      ..freezeCard()
      ..secureAccount()
      ..disputeTransaction('tx_9f31');
    wallet.resetDemo();
    expect(wallet.cardFrozen, isFalse);
    expect(wallet.accountSecured, isFalse);
    expect(wallet.flaggedTransaction, isNotNull);
  });

  test('profile name drives first name and initial, blank is ignored', () {
    wallet.updateName('  john   doe ');
    expect(wallet.customerName, 'john doe');
    expect(wallet.firstName, 'john');
    expect(wallet.initial, 'J');
    wallet.updateName('   ');
    expect(wallet.customerName, 'john doe');
  });

  test('balance is integer cents', () {
    expect(wallet.balanceCents, 248130);
  });
}
