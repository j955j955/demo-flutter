import 'package:demo_wallet/main.dart';
import 'package:demo_wallet/screens/support/support_session_screen.dart';
import 'package:demo_wallet/support/support_hub.dart';
import 'package:demo_wallet/support/support_session.dart';
import 'package:demo_wallet/wallet/wallet_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> dismissSheet(WidgetTester tester) async {
    Navigator.of(tester.element(find.text('Chat'))).pop();
    await tester.pumpAndSettle();
  }

  testWidgets('Get help asks chat or call instead of starting a call', (tester) async {
    await tester.pumpWidget(DemoWalletApp(wallet: WalletState()));
    await tester.tap(find.text('Get help'));
    await tester.pumpAndSettle();

    expect(find.text('How would you like to get help?'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.textContaining('About'), findsNothing);

    await dismissSheet(tester);
    expect(find.byType(SupportSessionScreen), findsNothing);
  });

  testWidgets("This wasn't me shows the charge in the chooser", (tester) async {
    await tester.pumpWidget(DemoWalletApp(wallet: WalletState()));
    await tester.tap(find.text("This wasn't me"));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'About $389.99 at GAMEVAULT'), findsOneWidget);
  });

  testWidgets('recording notice: Cancel starts nothing, Agree is remembered', (tester) async {
    final wallet = WalletState();
    final hub = SupportHub(wallet: wallet, agentId: '');
    addTearDown(hub.dispose);
    await tester.pumpWidget(DemoWalletApp(wallet: wallet, support: hub));

    Future<void> chooseChat() async {
      await tester.tap(find.text('Get help'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
    }

    await chooseChat();
    expect(find.text('Recording notice'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportSessionScreen), findsNothing);
    expect(hub.consentGiven, isFalse);

    await chooseChat();
    await tester.tap(find.text('Agree'));
    await tester.pumpAndSettle();
    expect(hub.consentGiven, isTrue);
    // No agent ID in tests, so the screen says so clearly.
    expect(find.text('Support agent is not configured'), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(hub.session, isNull, reason: 'leaving a failed conversation forgets it');

    await chooseChat();
    expect(find.text('Recording notice'), findsNothing);
    expect(find.byType(SupportSessionScreen), findsOneWidget);
  });

  test('audio tags never reach the customer', () {
    expect(stripAudioTags("[sad] I'm sorry to hear that."), "I'm sorry to hear that.");
    expect(stripAudioTags('[happy] Done. [warmly] Anything else?'), 'Done. Anything else?');
    expect(stripAudioTags('Card •••• 7314'), 'Card •••• 7314');
  });
}
