import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:demo_wallet/support/chat_connection.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingTool implements ClientTool {
  Map<String, dynamic>? received;

  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    received = parameters;
    return ClientToolResult.success({'card_status': 'frozen'});
  }
}

/// Plays the ElevenLabs side of the WebSocket protocol on localhost. It
/// always reads in the background, like a real server, so close handshakes
/// are answered even while a test isn't waiting for a message.
class _FakeServer {
  late final HttpServer _http;
  final _sockets = StreamController<WebSocket>();
  late final StreamIterator<WebSocket> _accepted = StreamIterator(_sockets.stream);
  final _inbox = StreamController<Map<String, Object?>>();
  late final StreamIterator<Map<String, Object?>> _messages = StreamIterator(_inbox.stream);
  StreamSubscription<dynamic>? _reader;
  final _clientClosed = Completer<void>();
  WebSocket? socket;

  /// Completes when the app closes its end of the socket.
  Future<void> get clientClosed => _clientClosed.future;
  final List<String> connectionPaths = [];

  String get endpoint => 'ws://127.0.0.1:${_http.port}/v1/convai/conversation';

  Future<void> start() async {
    _http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _http.listen((request) async {
      connectionPaths.add(request.uri.toString());
      _sockets.add(await WebSocketTransformer.upgrade(request));
    });
  }

  Future<void> accept() async {
    await _accepted.moveNext();
    socket = _accepted.current;
    _reader = socket!.listen(
      (data) => _inbox.add(jsonDecode(data as String) as Map<String, Object?>),
      onDone: _clientClosed.complete,
    );
  }

  Future<Map<String, Object?>> next() async {
    await _messages.moveNext();
    return _messages.current;
  }

  void send(Map<String, Object?> event) => socket!.add(jsonEncode(event));

  Future<void> stop() async {
    await _messages.cancel();
    await _accepted.cancel();
    await _reader?.cancel();
    await socket?.close();
    await _http.close(force: true);
    // Not awaited: a controller nobody listens to never finishes closing.
    unawaited(_sockets.close());
    unawaited(_inbox.close());
  }
}

void main() {
  late _FakeServer server;
  late _RecordingTool tool;
  late List<String> connected;
  late List<String> messages;
  late List<String> warnings;
  late Completer<ChatClosure> closed;
  late ChatConnection chat;

  setUp(() async {
    server = _FakeServer();
    await server.start();
    tool = _RecordingTool();
    connected = [];
    messages = [];
    warnings = [];
    closed = Completer();
    chat = ChatConnection(
      tools: {'freeze_card': tool},
      onConnect: connected.add,
      onAgentMessage: messages.add,
      onClose: (closure) {
        if (!closed.isCompleted) closed.complete(closure);
      },
      onWarning: (message, _) => warnings.add(message),
      endpoint: server.endpoint,
      confirmTimeout: const Duration(seconds: 2),
    );
    addTearDown(() async {
      await server.stop();
      await chat.dispose();
    });
  });

  Future<void> startAndConfirm() async {
    await chat.start(agentId: 'agent_test', userId: 'demo-customer', dynamicVariables: {});
    await server.accept();
    await server.next(); // initiation
    server.send({
      'type': 'conversation_initiation_metadata',
      'conversation_initiation_metadata_event': {'conversation_id': 'conv_abc'},
    });
    await pumpEventQueue();
  }

  test('opens a text-only conversation with the agent ID and variables', () async {
    await chat.start(
      agentId: 'agent_test',
      userId: 'demo-customer',
      dynamicVariables: {'channel': 'chat'},
      conversationConfigOverride: {
        'conversation': {'max_duration_seconds': 900},
      },
    );
    await server.accept();
    final init = await server.next();
    expect(server.connectionPaths.single, contains('agent_id=agent_test'));
    expect(init['type'], 'conversation_initiation_client_data');
    expect(init['conversation_config_override'], {
      'conversation': {'max_duration_seconds': 900, 'text_only': true},
    });
    expect(init['dynamic_variables'], {'channel': 'chat'});
    expect(init['user_id'], 'demo-customer');
  });

  test('confirms, relays agent replies and answers pings', () async {
    await startAndConfirm();
    expect(connected, ['conv_abc']);
    server.send({
      'type': 'agent_response',
      'agent_response_event': {'agent_response': 'Hi John'},
    });
    server.send({
      'type': 'ping',
      'ping_event': {'event_id': 7},
    });
    expect(await server.next(), {'type': 'pong', 'event_id': 7});
    expect(messages, ['Hi John']);
    expect(chat.sendUserMessage('That was not me'), isTrue);
    expect(await server.next(), {'type': 'user_message', 'text': 'That was not me'});
  });

  test('runs client tools and always answers, even for unknown tools', () async {
    await startAndConfirm();
    server.send({
      'type': 'client_tool_call',
      'client_tool_call': {
        'tool_name': 'freeze_card',
        'tool_call_id': 'call_1',
        'parameters': {'reason': 'fraud'},
      },
    });
    final result = await server.next();
    expect(tool.received, {'reason': 'fraud'});
    expect(result['tool_call_id'], 'call_1');
    expect(jsonDecode(result['result']! as String), {'card_status': 'frozen'});
    expect(result['is_error'], false);

    server.send({
      'type': 'client_tool_call',
      'client_tool_call': {'tool_name': 'nope', 'tool_call_id': 'call_2'},
    });
    final unknown = await server.next();
    expect(unknown, containsPair('is_error', true));
    expect(warnings, ['Agent called unknown tool "nope"']);
  });

  test('malformed messages are reported and the conversation carries on', () async {
    await startAndConfirm();
    server.socket!.add('not json');
    server.send({
      'type': 'client_tool_call',
      'client_tool_call': {'tool_name': 'freeze_card'},
    });
    server.send({
      'type': 'agent_response',
      'agent_response_event': {'agent_response': 'Still here'},
    });
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(messages, ['Still here']);
    expect(warnings, containsAll(['Malformed message from the agent', 'Tool call without an ID']));
  });

  test('reports how the server closed, and who closed it', () async {
    await startAndConfirm();
    await server.socket!.close(WebSocketStatus.normalClosure, 'end_call');
    final closure = await closed.future;
    expect(closure.code, WebSocketStatus.normalClosure);
    expect(closure.byClient, isFalse);
    expect(chat.sendUserMessage('anyone?'), isFalse);
  });

  test('gives up if the agent never confirms', () async {
    await chat.start(agentId: 'agent_test', userId: 'demo-customer', dynamicVariables: {});
    await server.accept();
    final closure = await closed.future.timeout(const Duration(seconds: 5));
    expect(closure.code, isNot(WebSocketStatus.normalClosure));
    expect(warnings, contains('The agent did not confirm the conversation in time'));
  });

  test('closing while the socket is still opening leaves nothing running', () async {
    final starting = chat.start(
      agentId: 'agent_test',
      userId: 'demo-customer',
      dynamicVariables: {},
    );
    await chat.close();
    await starting;
    await server.accept();
    await server.clientClosed.timeout(const Duration(seconds: 2));
    expect(server.socket!.closeCode, WebSocketStatus.normalClosure);
    expect(connected, isEmpty);
  });
}
