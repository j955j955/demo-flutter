import 'package:elevenlabs_agents/elevenlabs_agents.dart';

import '../util/format.dart';
import '../wallet/models.dart';
import '../wallet/wallet_state.dart';
import 'identity_verifier.dart';
import 'support_action.dart';

/// The client tools the support agent can call during a conversation.
///
/// Names and parameters must match agent/agent_config.json (checked by
/// test/agent_contract_test.dart). Policy is enforced here rather than
/// trusted to the prompt: account actions fail until identity is verified,
/// repeating an action is harmless, and every call gets an answer.
class SupportToolkit {
  SupportToolkit({
    required this.wallet,
    required this.verifier,
    required this.onAction,
    required this.conversationId,
    this.onToolError,
  });

  final WalletState wallet;
  final IdentityVerifier verifier;
  final void Function(SupportAction action) onAction;
  final String? Function() conversationId;

  /// Called when a tool throws. The agent still receives an error result.
  final void Function(String tool, Object error)? onToolError;

  late final Map<String, ClientTool> tools = {
    'get_recent_transactions': _safe('get_recent_transactions', _getRecentTransactions),
    'verify_identity': _safe('verify_identity', _verifyIdentity),
    'freeze_card': _safe('freeze_card', _freezeCard),
    'dispute_transaction': _safe('dispute_transaction', _disputeTransaction),
    'secure_account': _safe('secure_account', _secureAccount),
    'create_support_case': _safe('create_support_case', _createSupportCase),
  };

  SafeClientTool _safe(String name, ToolHandler handler) =>
      SafeClientTool(name, handler, onError: onToolError);

  ClientToolResult _getRecentTransactions(Map<String, dynamic> params) => ClientToolResult.success({
    'card_status': wallet.cardFrozen ? 'frozen' : 'active',
    'transactions': [for (final tx in wallet.transactions) tx.toAgentJson()],
  });

  ClientToolResult _verifyIdentity(Map<String, dynamic> params) {
    final result = verifier.verify('${params['card_last4'] ?? ''}');
    switch (result.outcome) {
      case VerificationOutcome.verified:
        onAction(const SupportAction(SupportActionType.identityVerified, 'Identity verified'));
        return ClientToolResult.success({'verified': true});
      case VerificationOutcome.alreadyVerified:
        return ClientToolResult.success({'verified': true, 'already_verified': true});
      case VerificationOutcome.mismatch:
        return ClientToolResult.success({
          'verified': false,
          'attempts_remaining': result.attemptsRemaining,
        });
      case VerificationOutcome.locked:
        return ClientToolResult.success({
          'verified': false,
          'locked': true,
          'retry_after_minutes': verifier.lockout.inMinutes,
        });
    }
  }

  ClientToolResult _freezeCard(Map<String, dynamic> params) {
    if (!verifier.isVerified) return _notVerified;
    final changed = wallet.freezeCard();
    if (changed) onAction(const SupportAction(SupportActionType.cardFrozen, 'Card frozen'));
    return ClientToolResult.success({
      'card_last4': wallet.cardLast4,
      'card_status': 'frozen',
      if (!changed) 'already_frozen': true,
      'replacement_card': 'can be ordered from the Card tab',
    });
  }

  ClientToolResult _disputeTransaction(Map<String, dynamic> params) {
    if (!verifier.isVerified) return _notVerified;
    final id = params['transaction_id'];
    if (id is! String || id.isEmpty) {
      return ClientToolResult.failure(
        'missing_transaction_id: pass transaction_id from get_recent_transactions',
      );
    }
    final (:outcome, :transaction) = wallet.disputeTransaction(id);
    switch (outcome) {
      case DisputeOutcome.notFound:
        return ClientToolResult.failure(
          'transaction_not_found: call get_recent_transactions for valid IDs',
        );
      case DisputeOutcome.notDisputable:
        return ClientToolResult.failure(
          'not_disputable: only payments can be disputed, not money received',
        );
      case DisputeOutcome.opened:
        onAction(
          SupportAction(
            SupportActionType.disputeOpened,
            'Dispute opened · ${formatCents(transaction!.amountCents.abs())}',
          ),
        );
      case DisputeOutcome.alreadyDisputed:
        break;
    }
    return ClientToolResult.success({
      'transaction_id': transaction!.id,
      'amount_usd': transaction.amountCents.abs() / 100,
      'merchant': transaction.merchant,
      if (outcome == DisputeOutcome.alreadyDisputed) 'already_disputed': true,
      'provisional_credit': 'within 1 business day',
      'final_decision': 'within 10 business days',
    });
  }

  ClientToolResult _secureAccount(Map<String, dynamic> params) {
    if (!verifier.isVerified) return _notVerified;
    final changed = wallet.secureAccount();
    if (changed) onAction(const SupportAction(SupportActionType.accountSecured, 'Account secured'));
    return ClientToolResult.success({
      'other_sessions_signed_out': changed ? 2 : 0,
      if (!changed) 'already_secured': true,
      'password_reset_sent_to': wallet.emailMasked,
    });
  }

  /// Allowed without verification: it is how a locked-out customer reaches
  /// a human.
  ClientToolResult _createSupportCase(Map<String, dynamic> params) {
    final summary = '${params['summary'] ?? ''}'.trim();
    if (summary.isEmpty) {
      return ClientToolResult.failure(
        'missing_summary: describe the issue so a specialist can act on it',
      );
    }
    final supportCase = wallet.openCase(
      category: CaseCategory.parse(params['category']),
      summary: summary,
      priority: CasePriority.parse(params['priority']),
      conversationId: conversationId(),
    );
    onAction(SupportAction(SupportActionType.caseCreated, 'Specialist case ${supportCase.id}'));
    return ClientToolResult.success({
      'case_id': supportCase.id,
      'follow_up': 'by email within 24 hours',
    });
  }

  static final _notVerified = ClientToolResult.failure(
    'identity_not_verified: ask for the last 4 digits of the card and call verify_identity first',
  );
}

typedef ToolHandler = ClientToolResult Function(Map<String, dynamic> params);

/// Wraps a handler so the agent always gets an answer. Without this, a tool
/// that throws leaves the agent waiting until the tool times out (the voice
/// SDK reports the error but sends no result).
class SafeClientTool implements ClientTool {
  SafeClientTool(this.name, this._handler, {this.onError});

  final String name;
  final ToolHandler _handler;
  final void Function(String tool, Object error)? onError;

  @override
  Future<ClientToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      return _handler(parameters);
    } on Object catch (error) {
      onError?.call(name, error);
      // A code, not the exception text: that would reach the language model.
      return ClientToolResult.failure('internal_error: the app could not complete $name');
    }
  }
}
