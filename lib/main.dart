import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'support/support_hub.dart';
import 'theme.dart';
import 'wallet/wallet_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DemoWalletApp(wallet: WalletState()));
}

class DemoWalletApp extends StatefulWidget {
  const DemoWalletApp({super.key, required this.wallet, this.support});

  final WalletState wallet;

  /// Injected by tests; otherwise created for the app's lifetime.
  final SupportHub? support;

  @override
  State<DemoWalletApp> createState() => _DemoWalletAppState();
}

class _DemoWalletAppState extends State<DemoWalletApp> {
  late final SupportHub _support = widget.support ?? SupportHub(wallet: widget.wallet);

  @override
  void dispose() {
    if (widget.support == null) _support.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WalletScope(
      wallet: widget.wallet,
      child: SupportScope(
        hub: _support,
        child: MaterialApp(
          title: 'Demo Wallet',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
