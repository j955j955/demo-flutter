import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config.dart';
import '../wallet/models.dart';
import '../wallet/wallet_state.dart';
import 'diagnostics.dart';
import 'identity_verifier.dart';
import 'support_session.dart';
import 'support_transport.dart';

/// Holds the one support conversation the app can have at a time, above the
/// navigator, so screens can come and go without ending it. Also owns what
/// must outlive a single conversation: recording consent and the identity
/// verification lockout.
class SupportHub extends ChangeNotifier {
  SupportHub({
    required this.wallet,
    String? agentId,
    this.userId = AppConfig.userId,
    this.transportFactory = createTransport,
    this._device,
    DateTime Function()? clock,
  }) : agentId = agentId ?? AppConfig.agentId,
       _clock = clock ?? DateTime.now,
       verifier = IdentityVerifier(expectedLast4: () => wallet.cardLast4, clock: clock);

  final WalletState wallet;
  final String agentId;
  final String userId;
  final TransportFactory transportFactory;
  final IdentityVerifier verifier;
  final DeviceInfo? _device;
  final DateTime Function() _clock;

  bool _consentGiven = false;
  SupportSession? _session;
  bool _lastActive = false;

  /// Whether the customer accepted the recording notice in this app session.
  bool get consentGiven => _consentGiven;
  SupportSession? get session => _session;
  SupportSession? get activeSession {
    final session = _session;
    return session != null && session.state.isActive ? session : null;
  }

  void recordConsent() => _consentGiven = true;

  /// Starts a conversation, or returns the one already in progress, so the
  /// customer never ends up with two conversations and two references.
  ///
  /// Conversations are recorded, so this refuses to start one without
  /// consent, whichever screen asks.
  SupportSession open(SupportChannel channel, {Transaction? transaction}) {
    if (!_consentGiven) {
      throw StateError('Recording consent is required before a support conversation starts.');
    }
    final active = activeSession;
    if (active != null) return active;
    final session = SupportSession(
      channel: channel,
      wallet: wallet,
      verifier: verifier,
      agentId: agentId,
      userId: userId,
      transportFactory: transportFactory,
      device: _device ?? DeviceInfo.current(),
      contextTransaction: transaction,
      clock: _clock,
    );
    // Started before it is published, so listeners hear about it once, as
    // already connecting.
    final starting = session.start();
    _replace(session);
    unawaited(starting);
    return session;
  }

  /// Ends and forgets the current conversation.
  void close() {
    if (_session != null) _replace(null);
  }

  /// Demo reset: drop the conversation, ask for consent again and clear the
  /// verification state.
  void reset() {
    close();
    _consentGiven = false;
    verifier.reset();
  }

  void _replace(SupportSession? next) {
    final previous = _session;
    previous?.removeListener(_onSessionChanged);
    _session = next;
    next?.addListener(_onSessionChanged);
    _lastActive = next?.state.isActive ?? false;
    previous?.dispose();
    notifyListeners();
  }

  /// Screens outside the conversation only care whether one is active, so
  /// the hub doesn't pass on every message, tick or voice-level change.
  void _onSessionChanged() {
    final active = _session?.state.isActive ?? false;
    if (active == _lastActive) return;
    _lastActive = active;
    notifyListeners();
  }

  @override
  void dispose() {
    final session = _session;
    _session = null;
    session?.removeListener(_onSessionChanged);
    session?.dispose();
    super.dispose();
  }
}

class SupportScope extends InheritedNotifier<SupportHub> {
  const SupportScope({super.key, required SupportHub hub, required super.child})
    : super(notifier: hub);

  static SupportHub of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SupportScope>()!.notifier!;

  static SupportHub read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SupportScope>()!.notifier!;
}
