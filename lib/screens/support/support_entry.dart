import 'package:flutter/material.dart';

import '../../support/support_hub.dart';
import '../../support/support_session.dart';
import '../../support/support_transport.dart';
import '../../wallet/models.dart';
import 'support_session_screen.dart';
import 'widgets/recording_notice_dialog.dart';
import 'widgets/support_options_sheet.dart';

/// Opens support from anywhere in the app: back to the conversation in
/// progress, or chat-or-call → recording notice → a new conversation.
Future<void> openSupport(BuildContext context, {Transaction? transaction}) async {
  final hub = SupportScope.read(context);
  final active = hub.activeSession;
  if (active != null) return showSupportSession(context, active);

  final channel = await showModalBottomSheet<SupportChannel>(
    context: context,
    showDragHandle: true,
    builder: (_) => SupportOptionsSheet(transaction: transaction),
  );
  if (channel == null || !context.mounted) return;
  if (!hub.consentGiven) {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (_) => RecordingNoticeDialog(channel: channel),
    );
    if (agreed != true || !context.mounted) return;
    hub.recordConsent();
  }
  final session = hub.open(channel, transaction: transaction);
  return showSupportSession(context, session);
}

/// Shows [session] full screen. Leaving it while it's active only minimizes
/// it; leaving a finished one forgets it.
Future<void> showSupportSession(BuildContext context, SupportSession session) async {
  final hub = SupportScope.read(context);
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SupportSessionScreen(session: session),
    ),
  );
  if (!session.state.isActive && identical(hub.session, session)) hub.close();
}
