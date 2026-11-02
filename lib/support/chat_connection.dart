import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:elevenlabs_agents/elevenlabs_agents.dart';

/// How a chat connection ended.
typedef ChatClosure = ({int? code, String? reason, bool byClient});

/// Text-only support chat over the ElevenLabs Agents WebSocket API.
///
/// Voice needs WebRTC (the SDK uses LiveKit for low-latency audio and echo
/// cancellation). A text chat doesn't: a plain WebSocket carries the same
/// agent events without opening the microphone or an audio session.
///
/// One instance handles one conversation; create a new one to reconnect.
class ChatConnection {
  ChatConnection({
    required this.tools,
    required this.onConnect,
    required this.onAgentMessage,
    required this.onClose,
    required this.onWarning,
    this.endpoint = 'wss://api.elevenlabs.io/v1/convai/conversation',
    this.confirmTimeout = const Duration(seconds: 15),
  });

  final Map<String, ClientTool> tools;
  final void Function(String conversationId) onConnect;
  final void Function(String text) onAgentMessage;
  final void Function(ChatClosure closure) onClose;
  final void Function(String message, Object? detail) onWarning;
  final String endpoint;

  /// How long to wait for the server to confirm the conversation.
  final Duration confirmTimeout;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _confirmTimer;
  bool _started = false;
  bool _confirmed = false;
  bool _closedByClient = false;
  bool _disposed = false;

  /// Opens the socket and sends the initiation message. Throws if the socket
  /// can't be opened; [onConnect] fires once the server confirms.
  Future<void> start({
    required String agentId,
    required String userId,
    required Map<String, String> dynamicVariables,
    Map<String, Object> conversationConfigOverride = const {},
  }) async {
    if (_started) throw StateError('ChatConnection.start can only be called once');
    _started = true;
    final uri = Uri.parse(endpoint).replace(queryParameters: {'agent_id': agentId});
    final socket = await WebSocket.connect(uri.toString()).timeout(confirmTimeout);
    if (_disposed || _closedByClient) {
      // Closed while the socket was still opening: don't leave it running.
      await socket.close(WebSocketStatus.normalClosure);
      return;
    }
    _socket = socket;
    _subscription = socket.listen(
      _onData,
      onError: (Object e) => onWarning('Chat connection error', e),
      onDone: () {
        _confirmTimer?.cancel();
        if (!_disposed) {
          onClose((code: socket.closeCode, reason: socket.closeReason, byClient: _closedByClient));
        }
      },
    );
    _confirmTimer = Timer(confirmTimeout, () {
      if (_confirmed) return;
      onWarning('The agent did not confirm the conversation in time', null);
      unawaited(socket.close(WebSocketStatus.goingAway));
    });
    final override = Map<String, Object>.of(conversationConfigOverride);
    override['conversation'] = {
      ...?(override['conversation'] as Map<String, Object>?),
      'text_only': true,
    };
    _send({
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': override,
      'dynamic_variables': dynamicVariables,
      'user_id': userId,
    });
  }

  /// Returns false if the message could not be sent (not connected).
  bool sendUserMessage(String text) => _send({'type': 'user_message', 'text': text});

  bool sendContextualUpdate(String text) => _send({'type': 'contextual_update', 'text': text});

  Future<void> close() async {
    _closedByClient = true;
    _confirmTimer?.cancel();
    final socket = _socket;
    if (socket != null && socket.readyState == WebSocket.open) {
      await socket.close(WebSocketStatus.normalClosure);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await close();
  }

  bool _send(Map<String, Object?> message) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return false;
    socket.add(jsonEncode(message));
    return true;
  }

  void _onData(dynamic data) {
    unawaited(
      _handle(data).catchError((Object e) {
        onWarning('Could not handle a message from the agent', e);
      }),
    );
  }

  Future<void> _handle(dynamic data) async {
    if (data is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException catch (e) {
      onWarning('Malformed message from the agent', e);
      return;
    }
    if (decoded is! Map<String, Object?>) return;
    switch (decoded) {
      case {
        'type': 'conversation_initiation_metadata',
        'conversation_initiation_metadata_event': {'conversation_id': final String id},
      }:
        _confirmed = true;
        _confirmTimer?.cancel();
        onConnect(id);
      case {
        'type': 'agent_response',
        'agent_response_event': {'agent_response': final String text},
      }:
        onAgentMessage(text);
      case {'type': 'client_tool_call', 'client_tool_call': final Map<String, Object?> call}:
        await _runTool(call);
      case {'type': 'ping', 'ping_event': {'event_id': final Object id}}:
        _send({'type': 'pong', 'event_id': id});
    }
  }

  Future<void> _runTool(Map<String, Object?> call) async {
    final id = call['tool_call_id'];
    if (id is! String) {
      onWarning('Tool call without an ID', call['tool_name']);
      return;
    }
    final name = call['tool_name'];
    final tool = tools[name];
    final params = call['parameters'];
    if (tool == null) {
      onWarning('Agent called unknown tool "$name"', null);
      _sendToolResult(id, ClientToolResult.failure('unknown_tool: $name'));
      return;
    }
    final result = await tool.execute(
      params is Map<String, Object?> ? Map<String, dynamic>.of(params) : <String, dynamic>{},
    );
    if (result != null) _sendToolResult(id, result);
  }

  void _sendToolResult(String id, ClientToolResult result) {
    final data = result.data;
    _send({
      'type': 'client_tool_result',
      'tool_call_id': id,
      'result': result.success
          ? (data is String ? data : jsonEncode(data))
          : (result.error ?? 'unknown_error'),
      'is_error': !result.success,
    });
  }
}
