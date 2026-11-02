import 'package:demo_wallet/support/diagnostics.dart';
import 'package:demo_wallet/support/support_hub.dart';
import 'package:demo_wallet/support/support_transport.dart';
import 'package:demo_wallet/wallet/wallet_state.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';

/// Stands in for ElevenLabs: records what the app sends and lets a test play
/// the agent's side through [events].
class FakeTransport extends SupportTransport {
  FakeTransport(this.channel, this.tools, this.events);

  final SupportChannel channel;
  final Map<String, ClientTool> tools;
  final TransportEvents events;
  final requests = <SessionRequest>[];
  final contextual = <String>[];
  final sent = <String>[];
  bool connected = true;
  int ends = 0;
  bool disposed = false;

  @override
  Future<void> start(SessionRequest request) async => requests.add(request);

  @override
  bool sendUserMessage(String text) {
    if (!connected) return false;
    sent.add(text);
    return true;
  }

  @override
  bool sendContextualUpdate(String text) {
    contextual.add(text);
    return true;
  }

  @override
  Future<void> end() async => ends++;

  @override
  Future<void> dispose() async => disposed = true;

  @override
  String get description => 'fake';

  void connect(String id) => events.onConnected(id);
  void closeNormally() => events.onClosed((abnormal: false, reason: 'agent', code: 1000));
  void drop() => events.onClosed((abnormal: true, reason: 'error', code: 1006));
}

/// A hub wired to fake transports, with every transport it creates kept in
/// [transports] in order.
class FakeSupport {
  FakeSupport({WalletState? wallet, DateTime Function()? clock, String agentId = 'agent_test_1234'})
    : wallet = wallet ?? WalletState() {
    hub = SupportHub(
      wallet: this.wallet,
      agentId: agentId,
      device: const DeviceInfo(platform: 'test', osVersion: '1.0'),
      clock: clock,
      transportFactory: (channel, tools, events) {
        final transport = FakeTransport(channel, tools, events);
        transports.add(transport);
        return transport;
      },
    );
  }

  final WalletState wallet;
  late final SupportHub hub;
  final transports = <FakeTransport>[];

  FakeTransport get last => transports.last;
}
