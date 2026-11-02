import 'package:demo_wallet/support/identity_verifier.dart';
import 'package:demo_wallet/support/support_action.dart';
import 'package:demo_wallet/support/support_tools.dart';
import 'package:demo_wallet/wallet/models.dart';
import 'package:demo_wallet/wallet/wallet_state.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WalletState wallet;
  late List<SupportAction> actions;
  late List<String> toolErrors;
  late Map<String, ClientTool> tools;

  setUp(() {
    wallet = WalletState();
    actions = [];
    toolErrors = [];
    tools = SupportToolkit(
      wallet: wallet,
      verifier: IdentityVerifier(expectedLast4: () => wallet.cardLast4),
      onAction: actions.add,
      conversationId: () => 'conv_1',
      onToolError: (tool, _) => toolErrors.add(tool),
    ).tools;
  });

  Future<ClientToolResult> call(String name, [Map<String, dynamic> params = const {}]) async =>
      (await tools[name]!.execute(params))!;

  test('account actions are refused until identity is verified', () async {
    for (final name in ['freeze_card', 'dispute_transaction', 'secure_account']) {
      final result = await call(name, {'transaction_id': 'tx_9f31', 'reason': 'fraud'});
      expect(result.success, isFalse, reason: name);
      expect(result.error, startsWith('identity_not_verified'), reason: name);
    }
    expect(wallet.cardFrozen, isFalse);
    expect(wallet.accountSecured, isFalse);
    expect(wallet.flaggedTransaction, isNotNull);
    expect(actions, isEmpty);
  });

  test('repeating an action is harmless and records one receipt', () async {
    await call('verify_identity', {'card_last4': '7314'});
    await call('freeze_card', {'reason': 'fraud'});
    final again = await call('freeze_card', {'reason': 'fraud'});
    expect(again.data, containsPair('already_frozen', true));
    await call('dispute_transaction', {'transaction_id': 'tx_9f31'});
    final disputedAgain = await call('dispute_transaction', {'transaction_id': 'tx_9f31'});
    expect(disputedAgain.data, containsPair('already_disputed', true));
    expect(actions.map((a) => a.label), [
      'Identity verified',
      'Card frozen',
      r'Dispute opened · $389.99',
    ]);
  });

  test('dispute input is validated', () async {
    await call('verify_identity', {'card_last4': '7314'});
    expect((await call('dispute_transaction')).error, startsWith('missing_transaction_id'));
    expect(
      (await call('dispute_transaction', {'transaction_id': 'tx_x'})).error,
      startsWith('transaction_not_found'),
    );
    expect(
      (await call('dispute_transaction', {'transaction_id': 'tx_9e41'})).error,
      startsWith('not_disputable'),
    );
  });

  test('a locked-out customer can still reach a human', () async {
    for (final wrong in ['1', '2', '3']) {
      await call('verify_identity', {'card_last4': wrong});
    }
    final result = await call('create_support_case', {
      'category': 'account_security',
      'summary': 'Locked out during verification',
      'priority': 'urgent',
    });
    expect(result.success, isTrue);
    expect(wallet.cases.single.category, CaseCategory.accountSecurity);
    expect(wallet.cases.single.conversationId, 'conv_1');
    expect(
      (await call('create_support_case', {'summary': '  '})).error,
      startsWith('missing_summary'),
    );
  });

  test('a tool that throws still answers the agent, without leaking details', () async {
    final tool = SafeClientTool(
      'boom',
      (_) => throw StateError('secret detail'),
      onError: (name, _) => toolErrors.add(name),
    );
    final result = await tool.execute({});
    expect(result.success, isFalse);
    expect(result.error, 'internal_error: the app could not complete boom');
    expect(result.error, isNot(contains('secret')));
    expect(toolErrors, ['boom']);
  });

  test('transactions reach the agent in dollars, from integer cents', () async {
    final result = await call('get_recent_transactions');
    final first = ((result.data as Map)['transactions'] as List).first as Map;
    expect(first['amount_usd'], -389.99);
    expect(first['category'], 'Digital goods');
  });
}
