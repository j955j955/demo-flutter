import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../util/format.dart';

@immutable
class DeviceInfo {
  const DeviceInfo({required this.platform, required this.osVersion});

  factory DeviceInfo.current() =>
      DeviceInfo(platform: Platform.operatingSystem, osVersion: Platform.operatingSystemVersion);

  final String platform;
  final String osVersion;
}

/// What went wrong in a conversation, kept apart from what merely went
/// sideways: a [failure] ends the conversation, a warning is only recorded.
class SessionDiagnostics {
  String? _failure;
  final List<String> _warnings = [];
  String? _disconnectReason;
  int? _disconnectCode;

  String? get failure => _failure;
  UnmodifiableListView<String> get warnings => UnmodifiableListView(_warnings);

  void fail(String message, [Object? detail]) =>
      _failure = detail == null ? message : '$message: ${sanitize(detail)}';

  void warn(String message, [Object? detail]) {
    _warnings.add(detail == null ? message : '$message: ${sanitize(detail)}');
    if (_warnings.length > 20) _warnings.removeAt(0);
  }

  void disconnected(String? reason, int? code) {
    _disconnectReason = reason;
    _disconnectCode = code;
  }

  void clear() {
    _failure = null;
    _warnings.clear();
    _disconnectReason = null;
    _disconnectCode = null;
  }

  /// The block the customer can copy and send. Nothing in it identifies the
  /// customer, and the agent ID is masked.
  String report({
    required DateTime now,
    required DeviceInfo device,
    required String transport,
    required String agentId,
    required String? referenceId,
    required List<String> conversationIds,
  }) => const JsonEncoder.withIndent('  ').convert({
    'time': now.toUtc().toIso8601String(),
    'platform': device.platform,
    'os_version': device.osVersion,
    'transport': transport,
    'agent_id': maskId(agentId),
    'reference_id': referenceId,
    'conversation_ids': conversationIds,
    'failure': _failure,
    'warnings': _warnings,
    'disconnect_reason': _disconnectReason,
    'disconnect_code': _disconnectCode,
  });

  /// Exception text can carry URLs with query strings (the WebSocket error
  /// includes ?agent_id=…). Strip them and keep it short.
  static String sanitize(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\?\S*'), '?…');
    return text.length > 300 ? '${text.substring(0, 300)}…' : text;
  }
}
