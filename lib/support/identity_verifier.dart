enum VerificationOutcome { verified, alreadyVerified, mismatch, locked }

typedef VerificationResult = ({VerificationOutcome outcome, int attemptsRemaining});

/// Checks the last four digits of the card for the support agent.
///
/// Owned by the support hub, not by a conversation, so the lockout survives
/// a new chat or call: otherwise every new conversation would grant three
/// more guesses at four digits. The agent never sees the expected digits,
/// only the outcome. In production this check belongs on the bank's server.
class IdentityVerifier {
  IdentityVerifier({
    required this._expectedLast4,
    DateTime Function()? clock,
    this.maxAttempts = 3,
    this.lockout = const Duration(minutes: 15),
    this.validity = const Duration(minutes: 10),
  }) : _clock = clock ?? DateTime.now;

  final String Function() _expectedLast4;
  final DateTime Function() _clock;
  final int maxAttempts;

  /// How long verification is refused after [maxAttempts] wrong answers.
  final Duration lockout;

  /// How long a successful check counts, so a follow-up minutes later
  /// doesn't ask again.
  final Duration validity;

  int _failures = 0;
  DateTime? _lockedUntil;
  DateTime? _verifiedAt;

  bool get isVerified {
    final at = _verifiedAt;
    return at != null && _clock().difference(at) < validity;
  }

  bool get isLocked {
    final until = _lockedUntil;
    return until != null && _clock().isBefore(until);
  }

  int get attemptsRemaining => isLocked ? 0 : maxAttempts - _failures;

  VerificationResult verify(String spoken) {
    if (isLocked) return (outcome: VerificationOutcome.locked, attemptsRemaining: 0);
    if (isVerified) {
      return (outcome: VerificationOutcome.alreadyVerified, attemptsRemaining: attemptsRemaining);
    }
    if (_lockedUntil != null) {
      // The lockout has expired: start a fresh round.
      _lockedUntil = null;
      _failures = 0;
    }
    if (normalizeDigits(spoken) == _expectedLast4()) {
      _verifiedAt = _clock();
      _failures = 0;
      return (outcome: VerificationOutcome.verified, attemptsRemaining: maxAttempts);
    }
    _failures++;
    if (_failures >= maxAttempts) {
      _lockedUntil = _clock().add(lockout);
      return (outcome: VerificationOutcome.locked, attemptsRemaining: 0);
    }
    return (outcome: VerificationOutcome.mismatch, attemptsRemaining: maxAttempts - _failures);
  }

  void reset() {
    _failures = 0;
    _lockedUntil = null;
    _verifiedAt = null;
  }

  /// Speech-to-text may return "seven three one four", "7 3 1 4" or "7314".
  static String normalizeDigits(String input) {
    const words = {
      'zero': '0',
      'oh': '0',
      'o': '0',
      'one': '1',
      'two': '2',
      'to': '2',
      'too': '2',
      'three': '3',
      'four': '4',
      'for': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
    };
    final buffer = StringBuffer();
    for (final token in input.toLowerCase().split(RegExp(r'[\s,.-]+'))) {
      buffer.write(words[token] ?? token.replaceAll(RegExp('[^0-9]'), ''));
    }
    return buffer.toString();
  }
}
