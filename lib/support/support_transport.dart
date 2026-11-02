import 'dart:async';
import 'dart:io' show WebSocketStatus;

import 'package:elevenlabs_agents/elevenlabs_agents.dart';

import 'chat_connection.dart';

/// How the customer chose to reach support.
enum SupportChannel { voice, chat }

/// Everything a conversation needs to start, the same for both channels.
typedef SessionRequest = ({
  String agentId,
  String userId,
  Map<String, String> variables,
  Duration? maxDuration,
});

/// How a connection ended. [abnormal] means it dropped rather than being
/// ended by the customer, the agent or the time limit.
typedef TransportClosure = ({bool abnormal, String? reason, int? code});

/// What a transport reports back to the conversation that owns it.
class TransportEvents {
  const TransportEvents({
    required this.onConnected,
    required this.onAgentMessage,
    required this.onClosed,
    required this.onWarning,
    required this.onEndRequested,
    required this.onStateChanged,
    required this.onVoiceLevel,
  });

  final void Function(String conversationId) onConnected;
  final void Function(String text) onAgentMessage;
  final void Function(TransportClosure closure) onClosed;
  final void Function(String message, Object? detail) onWarning;
  final void Function() onEndRequested;

  /// Speaking or muted changed (voice only).
  final void Function() onStateChanged;
  final void Function(double level) onVoiceLevel;
}

/// One connection to the agent. A conversation creates a new one for every
/// attempt, so nothing from an earlier attempt can leak into the next.
abstract class SupportTransport {
  Future<void> start(SessionRequest request);

  /// Returns false if not connected.
  bool sendUserMessage(String text);
  bool sendContextualUpdate(String text);
  Future<void> end();
  Future<void> dispose();

  bool get isSpeaking => false;
  bool get isMuted => false;
  Future<void> toggleMute() async {}

  /// Shown in diagnostics.
  String get description;
}

typedef TransportFactory = SupportTransport Function(
  SupportChannel channel,
  Map<String, ClientTool> tools,
  TransportEvents events,
);

SupportTransport createTransport(
  SupportChannel channel,
  Map<String, ClientTool> tools,
  TransportEvents events,
) => switch (channel) {
  SupportChannel.voice => VoiceTransport(tools, events),
  SupportChannel.chat => ChatTransport(tools, events),
};

/// Voice over WebRTC through the ElevenLabs Flutter SDK.
class VoiceTransport extends SupportTransport {
  VoiceTransport(Map<String, ClientTool> tools, this._events) {
    _client = ConversationClient(
      clientTools: tools,
      callbacks: ConversationCallbacks(
        onConnect: ({required conversationId}) => _events.onConnected(conversationId),
        onDisconnect: (details) => _events.onClosed((
          // The SDK reports 'user', 'agent' or 'error'.
          abnormal: details.reason == 'error',
          reason: details.reason,
          code: details.code,
        )),
        onError: (message, [detail]) => _events.onWarning(message, detail),
        onEndCallRequested: _events.onEndRequested,
        onVadScore: ({required vadScore}) => _events.onVoiceLevel(vadScore),
        onUnhandledClientToolCall: (call) =>
            _events.onWarning('Agent called unknown tool "${call.toolName}"', null),
      ),
    )..addListener(_events.onStateChanged);
  }

  final TransportEvents _events;
  late final ConversationClient _client;

  @override
  Future<void> start(SessionRequest request) => _client.startSession(
    agentId: request.agentId,
    userId: request.userId,
    dynamicVariables: request.variables,
  );

  @override
  bool sendUserMessage(String text) => _ifConnected(() => _client.sendUserMessage(text));

  @override
  bool sendContextualUpdate(String text) => _ifConnected(() => _client.sendContextualUpdate(text));

  bool _ifConnected(void Function() send) {
    if (_client.status != ConversationStatus.connected) return false;
    send();
    return true;
  }

  @override
  Future<void> end() async {
    if (_client.status != ConversationStatus.disconnected) await _client.endSession();
  }

  @override
  Future<void> dispose() async {
    _client.removeListener(_events.onStateChanged);
    await end();
    _client.dispose();
  }

  @override
  bool get isSpeaking => _client.isSpeaking;

  @override
  bool get isMuted => _client.isMuted;

  @override
  Future<void> toggleMute() => _client.toggleMute();

  @override
  String get description => 'elevenlabs_agents $packageVersion (webrtc)';
}

/// Text chat over the Agents WebSocket API. Never opens the microphone.
class ChatTransport extends SupportTransport {
  ChatTransport(Map<String, ClientTool> tools, TransportEvents events)
    : _connection = ChatConnection(
        tools: tools,
        onConnect: events.onConnected,
        onAgentMessage: events.onAgentMessage,
        onClose: (closure) => events.onClosed((
          // ElevenLabs closes with 1000 when the agent ends the chat or the
          // time limit is reached; anything else is a dropped connection.
          abnormal: !closure.byClient && closure.code != WebSocketStatus.normalClosure,
          reason: closure.reason,
          code: closure.code,
        )),
        onWarning: events.onWarning,
      );

  final ChatConnection _connection;

  @override
  Future<void> start(SessionRequest request) => _connection.start(
    agentId: request.agentId,
    userId: request.userId,
    dynamicVariables: request.variables,
    conversationConfigOverride: {
      if (request.maxDuration case final duration?)
        'conversation': {'max_duration_seconds': duration.inSeconds},
    },
  );

  @override
  bool sendUserMessage(String text) => _connection.sendUserMessage(text);

  @override
  bool sendContextualUpdate(String text) => _connection.sendContextualUpdate(text);

  @override
  Future<void> end() => _connection.close();

  @override
  Future<void> dispose() => _connection.dispose();

  @override
  String get description => 'websocket (text only)';
}
