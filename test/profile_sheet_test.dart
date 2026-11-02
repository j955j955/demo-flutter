import 'package:demo_wallet/main.dart';
import 'package:demo_wallet/wallet/wallet_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saving a new name survives the sheet closing with the keyboard', (tester) async {
    addTearDown(tester.view.reset);
    final wallet = WalletState();
    await tester.pumpWidget(DemoWalletApp(wallet: wallet));

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    // Keyboard is up while typing.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'John Doe');
    await tester.tap(find.text('Save'));
    // Keyboard goes down while the sheet animates away, which rebuilds it.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(wallet.customerName, 'John Doe');
    expect(find.textContaining('John'), findsWidgets);
  });

  testWidgets('hardware keyboard: Enter to submit, then keep typing elsewhere', (tester) async {
    addTearDown(tester.view.reset);
    final wallet = WalletState();
    await tester.pumpWidget(DemoWalletApp(wallet: wallet));

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'John Doe');
    // Mac keyboard in the simulator: key events switch focus highlight mode.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA); // mid-animation
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB); // after it closed

    expect(tester.takeException(), isNull);
    expect(wallet.customerName, 'John Doe');

    // Open it a second time and save with the button.
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alex Morgan');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);

    expect(tester.takeException(), isNull);
    expect(wallet.customerName, 'Alex Morgan');
  });
}
