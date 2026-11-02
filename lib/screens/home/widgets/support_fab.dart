import 'package:flutter/material.dart';

import '../../../support/support_hub.dart';
import '../../../support/support_session.dart';
import '../../../theme.dart';
import '../../../widgets/elapsed_text.dart';
import '../../support/support_entry.dart';

/// "Get help", or, while a conversation is minimized, a way back to it, like
/// the bar a phone shows during a call. Only this widget listens to the
/// support hub, so the rest of the home screen doesn't rebuild with it.
class SupportFab extends StatelessWidget {
  const SupportFab({super.key});

  static const unreadBadgeKey = Key('support-unread-badge');

  @override
  Widget build(BuildContext context) {
    final session = SupportScope.of(context).activeSession;
    if (session == null) {
      return FloatingActionButton.extended(
        onPressed: () => openSupport(context),
        icon: const Icon(Icons.support_agent),
        label: const Text('Get help'),
      );
    }
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final state = session.state;
        const labelStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
        return FloatingActionButton.extended(
          onPressed: () => showSupportSession(context, session),
          backgroundColor: context.colors.live,
          foregroundColor: Colors.white,
          icon: Badge(
            key: unreadBadgeKey,
            isLabelVisible: session.unread > 0,
            label: Text('${session.unread}'),
            child: Icon(session.isChat ? Icons.chat_bubble : Icons.call),
          ),
          label: switch ((session.isChat, state)) {
            (true, _) => const Text('Return to chat', style: labelStyle),
            (false, SessionLive(:final connectedAt)) => ElapsedText(
              since: connectedAt,
              prefix: 'Return to call · ',
              style: labelStyle,
            ),
            (false, _) => const Text('Return to call', style: labelStyle),
          },
        );
      },
    );
  }
}
