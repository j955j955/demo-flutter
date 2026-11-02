import '../wallet/models.dart';
import 'support_action.dart';
import 'support_transport.dart';

enum EntryPoint {
  helpButton('help_button'),
  reportedTransaction('reported_transaction'),
  followUp('follow_up');

  const EntryPoint(this.wire);
  final String wire;
}

/// Everything the app tells the agent, in one place and free of UI or I/O,
/// so it can be read and tested on its own.
abstract final class AgentContext {
  /// Must match the placeholders in agent/agent_config.json and the
  /// {{variables}} in the prompt (test/agent_contract_test.dart).
  static Map<String, String> variables({
    required String firstName,
    required SupportChannel channel,
    required EntryPoint entryPoint,
    String? followUpReference,
  }) => {
    'customer_first_name': firstName,
    'entry_point': entryPoint.wire,
    'channel': channel.name,
    'follow_up_reference': followUpReference ?? 'none',
    'opening': opening(firstName, followUp: entryPoint == EntryPoint.followUp),
  };

  /// The first sentence of the agent's greeting. The rest, including the AI
  /// disclosure, stays in the agent config so no client can leave it out.
  ///
  /// A variable rather than a first-message override: ElevenLabs rejects
  /// that override (close code 1008) even when the agent allows it.
  static String opening(String firstName, {required bool followUp}) => followUp
      ? 'Welcome back, $firstName. I have the notes from earlier.'
      : 'Hi $firstName, this is Demo Wallet support.';

  static String reportedTransaction(Transaction tx) =>
      'The customer opened support by tapping "This wasn\'t me" on '
      'transaction ${tx.id}: ${tx.merchant}, '
      '${(tx.amountCents.abs() / 100).toStringAsFixed(2)} USD, '
      '${tx.date.toIso8601String()}.';

  static String followUpNotes({
    required String referenceId,
    required Iterable<SupportAction> completed,
    required bool identityVerified,
  }) {
    final done = completed.map((a) => a.label).join('; ');
    return 'This is a follow-up to conversation $referenceId in the same app '
        'session. Already completed: ${done.isEmpty ? 'nothing' : done}. '
        'Identity is ${identityVerified ? 'already verified' : 'not verified'}. '
        'Do not repeat completed actions.';
  }
}
