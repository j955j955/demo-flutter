import 'package:flutter/material.dart';

import '../../support/support_session.dart';
import '../../theme.dart';
import 'chat_view.dart';
import 'failure_view.dart';
import 'summary_view.dart';
import 'voice_view.dart';

/// Shows a [SupportSession]. The session lives in the support hub, not
/// here: leaving this screen while it is active only minimizes it.
class SupportSessionScreen extends StatefulWidget {
  const SupportSessionScreen({super.key, required this.session});

  final SupportSession session;

  @override
  State<SupportSessionScreen> createState() => _SupportSessionScreenState();
}

class _SupportSessionScreenState extends State<SupportSessionScreen> {
  SupportSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    // Clearing the unread count notifies listeners, which must not happen
    // while this screen is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.setVisible(true);
    });
  }

  @override
  void dispose() {
    _session.setVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final state = _session.state;
        final colors = context.colors;
        return Scaffold(
          backgroundColor: _session.isChat ? colors.canvas : Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: colors.ink,
            leading: state.isActive
                ? IconButton(
                    tooltip: 'Minimize',
                    icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : const CloseButton(),
            title: const Text('Support', style: TextStyle(fontSize: 17)),
            centerTitle: true,
            actions: [
              if (_session.isChat && state is SessionLive)
                TextButton(
                  onPressed: _session.end,
                  child: Text('End', style: TextStyle(color: colors.danger)),
                ),
            ],
          ),
          body: SafeArea(
            child: switch (state) {
              SessionFailed(:final message) => FailureView(
                message: message,
                diagnostics: _session.diagnosticsReport(),
                onRetry: _session.start,
              ),
              SessionEnded(:final duration) => SummaryView(
                channel: _session.channel,
                duration: duration,
                actions: _session.actions,
                referenceId: _session.referenceId,
                onStillNeedHelp: _session.start,
              ),
              SessionIdle() || SessionConnecting() || SessionLive() =>
                _session.isChat ? ChatView(session: _session) : VoiceView(session: _session),
            },
          ),
        );
      },
    );
  }
}
