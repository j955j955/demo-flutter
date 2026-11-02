import 'package:flutter/foundation.dart';

enum SupportActionType { identityVerified, cardFrozen, disputeOpened, accountSecured, caseCreated }

/// Something the agent actually did, recorded only when a tool succeeds.
/// [label] is short ("Card frozen") because it is shown as a one-line receipt.
@immutable
class SupportAction {
  const SupportAction(this.type, this.label);

  final SupportActionType type;
  final String label;
}
