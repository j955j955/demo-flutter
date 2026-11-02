import 'package:demo_wallet/support/support_session.dart';
import 'package:demo_wallet/support/support_transport.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeSupport support;
  setUp(() {
    support = FakeSupport();
    support.hub.recordConsent();
  });

  Future<SupportSession> openConnected(SupportChannel channel, [String id = 'conv_1']) async {
    final session = support.hub.open(channel);
    await pumpEventQueue();
    support.last.connect(id);
    return session;
  }

  test('conversations need recording consent, whichever screen asks', () {
    support.hub.reset();
    expect(() => support.hub.open(SupportChannel.chat), throwsStateError);
  });

  test('the first attempt is not a follow-up; the next keeps its reference', () async {
    final session = await openConnected(SupportChannel.chat);
    final first = support.last;
    expect(session.isFollowUp, isFalse);
    expect(first.requests.single.variables['follow_up_reference'], 'none');
    expect(first.requests.single.maxDuration, SupportSession.chatMaxDuration);

    await first.tools['verify_identity']!.execute({'card_last4': '7314'});
    await first.tools['freeze_card']!.execute({'reason': 'fraud'});
    await session.end();
    first.closeNormally();
    expect(session.state, isA<SessionEnded>());

    await session.start(); // "Still need help?"
    final second = support.last;
    expect(second, isNot(same(first)), reason: 'a fresh transport per attempt');
    expect(first.disposed, isTrue);
    expect(session.isFollowUp, isTrue);
    expect(second.requests.single.variables['follow_up_reference'], 'conv_1');
    expect(second.requests.single.variables['entry_point'], 'follow_up');
    expect(second.requests.single.variables['opening'], startsWith('Welcome back'));
    expect(first.requests.single.variables['opening'], startsWith('Hi '));
    expect(second.contextual.single, allOf(contains('Card frozen'), contains('already verified')));

    second.connect('conv_2');
    expect(session.referenceId, 'conv_1');
    expect(session.conversationIds, ['conv_1', 'conv_2']);
  });

  test('ending while connecting wins over a late "connected"', () async {
    final session = support.hub.open(SupportChannel.voice);
    await pumpEventQueue();
    await session.end();
    support.last.connect('conv_late');
    expect(session.state, isA<SessionEnded>());
    expect(session.referenceId, isNull);
    expect(support.last.ends, greaterThanOrEqualTo(2), reason: 'the late connection is closed too');
  });

  test('events from an earlier attempt are ignored', () async {
    final session = await openConnected(SupportChannel.chat);
    final old = support.last;
    await session.end();
    await session.start();
    old.drop(); // Arrives late, from the first connection.
    expect(session.state, isA<SessionConnecting>());
  });

  test('a second start while active is ignored (double tap)', () async {
    final session = support.hub.open(SupportChannel.chat);
    await session.start();
    await pumpEventQueue();
    expect(support.transports, hasLength(1));
  });

  test('a warning does not turn a normal ending into a failure', () async {
    final session = await openConnected(SupportChannel.chat);
    support.last.events.onWarning('Failed to send contextual update', null);
    support.last.closeNormally(); // e.g. the agent's end_call
    expect(session.state, isA<SessionEnded>());
    expect(session.diagnostics.warnings, hasLength(1));
  });

  test('a dropped connection fails; never connecting fails', () async {
    final live = await openConnected(SupportChannel.chat);
    support.last.drop();
    expect(live.state, isA<SessionFailed>());

    support.hub.close();
    final never = support.hub.open(SupportChannel.chat);
    await pumpEventQueue();
    support.last.closeNormally();
    expect(never.state, isA<SessionFailed>());
  });

  test('a message that cannot be sent is reported, not shown', () async {
    final session = await openConnected(SupportChannel.chat);
    support.last.connected = false;
    expect(session.send('hello'), isFalse);
    expect(session.chat.whereType<ChatMessage>(), isEmpty);
    expect(session.awaitingReply, isFalse);
  });

  test('agent text is cleaned, and counted as unread while hidden', () async {
    final session = await openConnected(SupportChannel.chat);
    support.last.events.onAgentMessage('[sad] Sorry to hear that.');
    expect((session.chat.last as ChatMessage).text, 'Sorry to hear that.');
    expect(session.unread, 1);
    session.setVisible(true);
    expect(session.unread, 0);
  });

  test('only one conversation at a time', () async {
    final first = support.hub.open(SupportChannel.chat);
    expect(support.hub.open(SupportChannel.voice), same(first));
    await pumpEventQueue();
    support.last.connect('conv_1');
    await first.end();
    support.hub.close();
    expect(support.hub.open(SupportChannel.voice), isNot(same(first)));
  });

  test('the hub only announces whether a conversation is active', () async {
    var notifications = 0;
    support.hub.addListener(() => notifications++);
    final session = support.hub.open(SupportChannel.chat); // replaced: 1
    await pumpEventQueue();
    support.last.connect('conv_1');
    for (var i = 0; i < 5; i++) {
      support.last.events.onAgentMessage('message $i');
      support.last.events.onVoiceLevel(i / 5);
    }
    expect(notifications, 1);
    await session.end(); // no longer active: 2
    expect(notifications, 2);
  });

  test('diagnostics mask the agent ID and strip URLs from errors', () async {
    final session = await openConnected(SupportChannel.chat);
    support.last.events.onWarning(
      'Connection error',
      'WebSocketException: wss://api.elevenlabs.io/v1/convai/conversation?agent_id=agent_test_1234',
    );
    final report = session.diagnosticsReport();
    expect(report, isNot(contains('agent_test_1234')));
    expect(report, contains('agent_…1234'));
    expect(report, contains('conversation?…'));
  });
}
