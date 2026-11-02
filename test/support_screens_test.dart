import 'dart:async';

import 'package:demo_wallet/main.dart';
import 'package:demo_wallet/screens/home/widgets/support_fab.dart';
import 'package:demo_wallet/screens/support/support_entry.dart';
import 'package:demo_wallet/screens/support/support_session_screen.dart';
import 'package:demo_wallet/support/support_hub.dart';
import 'package:demo_wallet/support/support_session.dart';
import 'package:demo_wallet/support/support_transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeSupport support;
  setUp(() {
    support = FakeSupport();
    support.hub.recordConsent();
  });

  Future<SupportSession> showSession(WidgetTester tester, SupportChannel channel) async {
    await tester.pumpWidget(DemoWalletApp(wallet: support.wallet, support: support.hub));
    final session = support.hub.open(channel);
    final context = tester.element(find.byType(Scaffold).first);
    // Completes only when the screen closes.
    unawaited(showSupportSession(context, session));
    // Not pumpAndSettle: the call screen animates for as long as it's open.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return session;
  }

  testWidgets('a first call is not labelled a follow-up; the second is', (tester) async {
    final session = await showSession(tester, SupportChannel.voice);
    expect(find.text('Connecting…'), findsOneWidget);
    support.last.connect('conv_1');
    await tester.pump();
    expect(find.text('Listening'), findsOneWidget);
    expect(find.textContaining('Follow-up'), findsNothing);

    await tester.tap(find.text('End call'));
    await tester.pump();
    expect(find.text('Still need help?'), findsOneWidget);
    expect(find.text('conv_1'), findsOneWidget);

    await tester.tap(find.text('Still need help?'));
    await tester.pump();
    support.last.connect('conv_2');
    await tester.pump();
    expect(find.textContaining('Follow-up · ref …conv_1'), findsOneWidget);
    expect(session.referenceId, 'conv_1');
    await session.end();
    await tester.pump();
  });

  testWidgets('minimizing keeps the conversation; returning reopens the same one', (tester) async {
    await showSession(tester, SupportChannel.chat);
    support.last.connect('conv_1');
    await tester.pump();

    await tester.tap(find.byTooltip('Minimize'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportSessionScreen), findsNothing);
    expect(support.hub.activeSession?.state, isA<SessionLive>());

    support.last.events.onAgentMessage('Your card is frozen.');
    await tester.pump();
    expect(find.text('Return to chat'), findsOneWidget);
    final badge = tester.widget<Badge>(find.byKey(SupportFab.unreadBadgeKey));
    expect(badge.isLabelVisible, isTrue);

    await tester.tap(find.text('Return to chat'));
    await tester.pumpAndSettle();
    expect(find.text('Your card is frozen.'), findsOneWidget);
    expect(support.transports, hasLength(1), reason: 'no second conversation');

    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to wallet'));
    await tester.pumpAndSettle();
    expect(support.hub.session, isNull);
    expect(find.text('Get help'), findsOneWidget);
  });

  testWidgets('the home screen survives very large text', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    support.wallet.updateName('Alexandra Montgomery-Whitfield');
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: DemoWalletApp(
          wallet: support.wallet,
          support: SupportHub(wallet: support.wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
