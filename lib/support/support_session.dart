import 'dart:async';
import 'dart:collection';

import 'package:elevenlabs_agents/elevenlabs_agents.dart' show ClientTool;
import 'package:flutter/foundation.dart';

import '../wallet/models.dart';
import '../wallet/wallet_state.dart';
import 'agent_context.dart';
import 'diagnostics.dart';
import 'identity_verifier.dart';
import 'support_action.dart';
import 'support_tools.dart';
import 'support_transport.dart';

/// Where a conversation is. Each state carries only what is true in it.
sealed class SessionState {
  const SessionState();

  /// Connecting or live: the conversation can be minimized and returned to.
  bool get isActive => false;
}

final class SessionIdle extends SessionState {
  const SessionIdle();
}

final class SessionConnecting extends SessionState {
  const SessionConnecting();

  @override
  bool get isActive => true;
}

final class SessionLive extends SessionState {
  const SessionLive(this.connectedAt);
  final DateTime connectedAt;

  @override
  bool get isActive => true;
}

final class SessionEnded extends SessionState {
  const SessionEnded(this.duration);
  final Duration duration;
}

final class SessionFailed extends SessionState {
  const SessionFailed(this.message);
  final String message;
}

sealed class ChatEntry {
  const ChatEntry();
}

final class ChatMessage extends ChatEntry {
  const ChatMessage({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

final class ChatActionEntry extends ChatEntry {
  const ChatActionEntry(this.action);
  final SupportAction action;
}

final class ChatDivider extends ChatEntry {
  const ChatDivider(this.label);
  final String label;
}

/// Removes expressive-mode audio tags such as "[sad]" from agent text. They
/// shape the voice, but must never be shown to the customer.
String stripAudioTags(String text) => text.replaceAll(RegExp(r'\[[a-zA-Z ]{1,24}\]\s*'), '').trim();

/// One support conversation, by voice or chat, and its follow-ups.
///
/// Owned by the [SupportHub] above the navigator, so the customer can
/// minimize it and come back. Every connection attempt gets a fresh
/// transport, and events from an earlier attempt are ignored, so a late
/// "connected" can never revive a conversation the customer already ended.
class SupportSession extends ChangeNotifier {
  SupportSession({
    required this.channel,
    required WalletState wallet,
    required IdentityVerifier verifier,
    required this.agentId,
    required this.userId,
    required this._transportFactory,
    required this._device,
    this.contextTransaction,
    DateTime Function()? clock,
  }) : _wallet = wallet,
       _verifier = verifier,
       _clock = clock ?? DateTime.now {
    _tools = SupportToolkit(
      wallet: wallet,
      verifier: verifier,
      onAction: _addAction,
      conversationId: () => _referenceId,
      onToolError: (tool, error) => diagnostics.warn('Tool $tool failed', error),
    ).tools;
  }

  /// Typing is slower than talking, so chat gets longer than the agent's
  /// default limit.
  static const chatMaxDuration = Duration(minutes: 15);

  final SupportChannel channel;
  final String agentId;
  final String userId;
  final Transaction? contextTransaction;
  final WalletState _wallet;
  final IdentityVerifier _verifier;
  final TransportFactory _transportFactory;
  final DeviceInfo _device;
  final DateTime Function() _clock;
  late final Map<String, ClientTool> _tools;

  final diagnostics = SessionDiagnostics();
  final _voiceLevel = ValueNotifier<double>(0);
  final _actions = <SupportAction>[];
  final _chat = <ChatEntry>[];
  final _conversationIds = <String>[];

  SessionState _state = const SessionIdle();
  SupportTransport? _transport;
  int _attempt = 0;
  bool _followUpAttempt = false;
  bool _awaitingReply = false;
  bool _visible = false;
  int _unread = 0;
  String _draft = '';
  String? _referenceId;
  bool _disposed = false;

  SessionState get state => _state;
  bool get isChat => channel == SupportChannel.chat;
  UnmodifiableListView<SupportAction> get actions => UnmodifiableListView(_actions);
  UnmodifiableListView<ChatEntry> get chat => UnmodifiableListView(_chat);
  UnmodifiableListView<String> get conversationIds => UnmodifiableListView(_conversationIds);

  /// The first conversation's ID. Follow-ups reuse it so the customer only
  /// ever has one reference, however many connections it takes.
  String? get referenceId => _referenceId;

  /// Whether the current attempt continues an earlier one.
  bool get isFollowUp => _followUpAttempt;
  bool get awaitingReply => _awaitingReply;
  int get unread => _unread;
  String get draft => _draft;
  bool get isSpeaking => _transport?.isSpeaking ?? false;
  bool get isMuted => _transport?.isMuted ?? false;

  /// Only the voice orb listens to this, so it can change many times a
  /// second without rebuilding anything else.
  ValueListenable<double> get voiceLevel => _voiceLevel;

  /// Starts the conversation, or a follow-up once one has ended. Ignored
  /// while one is already connecting or live (a double tap, for example).
  Future<void> start() async {
    if (_state.isActive || _disposed) return;
    if (agentId.isEmpty) {
      diagnostics.fail(
        'Support agent is not configured',
        'Run with --dart-define-from-file=config/dev.json',
      );
      _setState(const SessionFailed('Support agent is not configured'));
      return;
    }
    final followUp = _referenceId != null;
    final attempt = ++_attempt;
    final previous = _transport;
    final transport = _transportFactory(channel, _tools, _eventsFor(attempt));
    _transport = transport;
    if (previous != null) unawaited(previous.dispose());

    _followUpAttempt = followUp;
    _awaitingReply = false;
    diagnostics.clear();
    if (followUp && isChat) {
      _chat.add(ChatDivider('Follow-up · ref …${shortRef(_referenceId!)}'));
    }
    _setState(const SessionConnecting());

    final tx = contextTransaction;
    try {
      await transport.start((
        agentId: agentId,
        userId: userId,
        variables: AgentContext.variables(
          firstName: _wallet.firstName,
          channel: channel,
          entryPoint: followUp
              ? EntryPoint.followUp
              : tx == null
              ? EntryPoint.helpButton
              : EntryPoint.reportedTransaction,
          followUpReference: _referenceId,
        ),
        maxDuration: isChat ? chatMaxDuration : null,
      ));
    } on Object catch (error) {
      if (attempt == _attempt && _state is SessionConnecting) {
        _fail('Could not reach support', error);
      } else if (attempt == _attempt) {
        // Already failed through a disconnect (which carries no detail):
        // keep the exception, it's usually the more useful clue.
        diagnostics.warn('Session start failed', error);
      }
      return;
    }
    if (attempt != _attempt || _disposed) return;
    if (!_state.isActive) {
      // Ended while it was still connecting: don't leave it running.
      await transport.end();
      return;
    }
    final context = followUp
        ? AgentContext.followUpNotes(
            referenceId: _referenceId!,
            completed: _actions,
            identityVerified: _verifier.isVerified,
          )
        : tx == null
        ? null
        : AgentContext.reportedTransaction(tx);
    if (context != null && !transport.sendContextualUpdate(context)) {
      diagnostics.warn('Could not send context to the agent');
    }
  }

  /// A chat message, or typed text during a call. Returns false if it could
  /// not be sent, so the screen can keep the text.
  bool send(String text) {
    final message = text.trim();
    final transport = _transport;
    if (message.isEmpty || _state is! SessionLive || transport == null) return false;
    if (!transport.sendUserMessage(message)) {
      diagnostics.warn('Message not sent: not connected');
      return false;
    }
    _draft = '';
    if (isChat) {
      _awaitingReply = true;
      _chat.add(ChatMessage(fromUser: true, text: message));
    }
    _notify();
    return true;
  }

  Future<void> end() async {
    final current = _state;
    if (!current.isActive) return;
    _awaitingReply = false;
    _setState(
      SessionEnded(
        current is SessionLive ? _clock().difference(current.connectedAt) : Duration.zero,
      ),
    );
    await _transport?.end();
  }

  Future<void> toggleMute() async => _transport?.toggleMute();

  /// Unsent text, kept while the conversation is minimized.
  void saveDraft(String text) => _draft = text;

  /// Called by the screen. Agent messages that arrive while it is hidden
  /// count as unread.
  void setVisible(bool visible) {
    _visible = visible;
    if (visible && _unread > 0) {
      _unread = 0;
      _notify();
    }
  }

  String diagnosticsReport() => diagnostics.report(
    now: _clock(),
    device: _device,
    transport: _transport?.description ?? 'none',
    agentId: agentId,
    referenceId: _referenceId,
    conversationIds: _conversationIds,
  );

  static String shortRef(String id) => id.length > 6 ? id.substring(id.length - 6) : id;

  TransportEvents _eventsFor(int attempt) {
    bool current() => attempt == _attempt && !_disposed;
    return TransportEvents(
      onConnected: (id) {
        if (current()) _onConnected(id);
      },
      onAgentMessage: (text) {
        if (current()) _onAgentMessage(text);
      },
      onClosed: (closure) {
        if (current()) _onClosed(closure);
      },
      onWarning: (message, detail) {
        if (current()) diagnostics.warn(message, detail);
      },
      onEndRequested: () {
        if (current()) unawaited(end());
      },
      onStateChanged: () {
        if (current()) _notify();
      },
      onVoiceLevel: (level) {
        // Coarse steps: the orb doesn't need every tiny change.
        if (current()) _voiceLevel.value = (level * 20).round() / 20;
      },
    );
  }

  void _onConnected(String conversationId) {
    if (_state is! SessionConnecting) {
      // The customer ended it while it was connecting.
      unawaited(_transport?.end());
      return;
    }
    _conversationIds.add(conversationId);
    // Kept here because the SDK clears its own copy on disconnect, which
    // once made the reference vanish from the summary.
    _referenceId ??= conversationId;
    _setState(SessionLive(_clock()));
  }

  void _onAgentMessage(String message) {
    final text = stripAudioTags(message);
    if (text.isEmpty) return;
    _awaitingReply = false;
    if (!_visible) _unread++;
    _chat.add(ChatMessage(fromUser: false, text: text));
    _notify();
  }

  void _onClosed(TransportClosure closure) {
    diagnostics.disconnected(closure.reason, closure.code);
    _awaitingReply = false;
    switch (_state) {
      case SessionConnecting():
        _fail('Could not reach support');
      case SessionLive(:final connectedAt):
        if (closure.abnormal) {
          _fail('The connection was lost');
        } else {
          _setState(SessionEnded(_clock().difference(connectedAt)));
        }
      case SessionIdle() || SessionEnded() || SessionFailed():
        break; // Already settled, e.g. the customer ended it.
    }
  }

  void _addAction(SupportAction action) {
    _actions.add(action);
    if (isChat) _chat.add(ChatActionEntry(action));
    _notify();
  }

  void _fail(String message, [Object? detail]) {
    diagnostics.fail(message, detail);
    _setState(SessionFailed(message));
  }

  void _setState(SessionState state) {
    _state = state;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final transport = _transport;
    if (transport != null) unawaited(transport.dispose());
    _voiceLevel.dispose();
    super.dispose();
  }
}
