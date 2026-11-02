import 'package:flutter/material.dart';

import '../../support/support_session.dart';
import '../../theme.dart';
import '../../widgets/elapsed_text.dart';
import 'widgets/action_line.dart';
import 'widgets/call_controls.dart';
import 'widgets/voice_orb.dart';

/// A connecting or live call. Built only while the call is active, so the
/// orb animation stops with it.
class VoiceView extends StatefulWidget {
  const VoiceView({super.key, required this.session});

  final SupportSession session;

  @override
  State<VoiceView> createState() => _VoiceViewState();
}

class _VoiceViewState extends State<VoiceView> with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  late final TextEditingController _input;

  SupportSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _breath.repeat(reverse: true);
    _input = TextEditingController(text: _session.draft)
      ..addListener(() => _session.saveDraft(_input.text));
  }

  @override
  void dispose() {
    _breath.dispose();
    _input.dispose();
    super.dispose();
  }

  void _send() {
    if (_session.send(_input.text)) {
      _input.clear();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Not connected yet')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = _session.state;
    final mode = switch (state) {
      SessionLive() when _session.isMuted => OrbMode.muted,
      SessionLive() when _session.isSpeaking => OrbMode.speaking,
      SessionLive() => OrbMode.listening,
      _ => OrbMode.connecting,
    };
    final label = switch (mode) {
      OrbMode.connecting => 'Connecting…',
      OrbMode.listening => 'Listening',
      OrbMode.speaking => 'Speaking',
      OrbMode.muted => 'Muted',
    };
    final subtitleStyle = TextStyle(color: colors.muted, fontSize: 13);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            children: [
              SizedBox(
                height: 220,
                child: Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_breath, _session.voiceLevel]),
                    builder: (context, _) => VoiceOrb(
                      mode: mode,
                      breath: Curves.easeInOut.transform(_breath.value),
                      level: _session.voiceLevel.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.ink, fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  if (state case SessionLive(:final connectedAt))
                    ElapsedText(since: connectedAt, style: subtitleStyle),
                  if (_session.isFollowUp)
                    Text(
                      'Follow-up · ref …${SupportSession.shortRef(_session.referenceId!)}',
                      style: subtitleStyle,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              for (final action in _session.actions) ActionLine(action: action),
            ],
          ),
        ),
        CallControls(
          input: _input,
          enabled: state is SessionLive,
          muted: _session.isMuted,
          onSend: _send,
          onToggleMute: state is SessionLive ? _session.toggleMute : null,
          onEnd: _session.end,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Powered by ElevenAgents',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
