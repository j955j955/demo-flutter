/// Build-time configuration.
///
/// Values are injected with `--dart-define-from-file=config/dev.json`
/// (see `config/dev.example.json`). The ID of a public agent is not a secret,
/// but it is kept out of the repository so nobody else spends its credits.
abstract final class AppConfig {
  static const agentId = String.fromEnvironment('ELEVENLABS_AGENT_ID');

  /// The demo has one customer. A real app would send its own user ID.
  static const userId = 'demo-customer';
}
