import 'package:demo_wallet/support/identity_verifier.dart';
import 'package:demo_wallet/support/support_transport.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  var now = DateTime(2026, 11, 2, 11);
  IdentityVerifier make() => IdentityVerifier(expectedLast4: () => '7314', clock: () => now);
  setUp(() => now = DateTime(2026, 11, 2, 11));

  test('accepts digits in the formats speech-to-text produces', () {
    for (final spoken in ['7314', '7 3 1 4', 'seven three one four', 'Seven, three, one, four.']) {
      expect(make().verify(spoken).outcome, VerificationOutcome.verified, reason: spoken);
    }
  });

  test('locks after three wrong answers, even against the right one', () {
    final verifier = make();
    expect(verifier.verify('1111').outcome, VerificationOutcome.mismatch);
    expect(verifier.verify('2222').attemptsRemaining, 1);
    expect(verifier.verify('3333').outcome, VerificationOutcome.locked);
    expect(verifier.verify('7314').outcome, VerificationOutcome.locked);
    expect(verifier.isVerified, isFalse);
  });

  test('the lockout expires after the cooldown', () {
    final verifier = make();
    for (final wrong in ['1', '2', '3']) {
      verifier.verify(wrong);
    }
    now = now.add(const Duration(minutes: 16));
    expect(verifier.verify('7314').outcome, VerificationOutcome.verified);
  });

  test('checking again after success is harmless and uses no attempts', () {
    final verifier = make()..verify('7314');
    expect(verifier.verify('0000').outcome, VerificationOutcome.alreadyVerified);
    expect(verifier.isVerified, isTrue);
    expect(verifier.attemptsRemaining, 3);
  });

  test('verification expires', () {
    final verifier = make()..verify('7314');
    now = now.add(const Duration(minutes: 11));
    expect(verifier.isVerified, isFalse);
  });

  test('a new conversation does not grant new guesses', () async {
    final support = FakeSupport();
    support.hub.recordConsent();
    final first = support.hub.open(SupportChannel.chat);
    await pumpEventQueue();
    support.last.connect('conv_1');
    for (final wrong in ['1111', '2222', '3333']) {
      await support.last.tools['verify_identity']!.execute({'card_last4': wrong});
    }
    await first.end();
    support.hub.close();

    support.hub.open(SupportChannel.voice);
    await pumpEventQueue();
    final result = await support.last.tools['verify_identity']!.execute({'card_last4': '7314'});
    expect(result!.data, containsPair('locked', true));
  });
}
