import 'dart:convert';
import 'dart:io';

import 'package:demo_wallet/support/agent_context.dart';
import 'package:demo_wallet/support/identity_verifier.dart';
import 'package:demo_wallet/support/support_tools.dart';
import 'package:demo_wallet/support/support_transport.dart';
import 'package:demo_wallet/wallet/wallet_state.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Json = Map<String, Object?>;

/// The agent is configured in agent/ and the app implements its side in lib/.
/// Names are shared as plain strings, so a rename on one side would only
/// show up during a live call. These tests catch the mismatch for free.
void main() {
  final config = jsonDecode(File('agent/agent_config.json').readAsStringSync()) as Json;
  final prompt = File('agent/system_prompt.md').readAsStringSync();
  final tools = (config['tools']! as List<Object?>).cast<Json>();
  final agent = ((config['agent']! as Json)['conversation_config']! as Json)['agent']! as Json;
  final clientTools = {
    for (final t in tools)
      if (t['type'] == 'client') t['name']! as String,
  };

  test('every client tool in the agent config is implemented by the app', () {
    final wallet = WalletState();
    final implemented = SupportToolkit(
      wallet: wallet,
      verifier: IdentityVerifier(expectedLast4: () => wallet.cardLast4),
      onAction: (_) {},
      conversationId: () => null,
    ).tools.keys.toSet();
    expect(implemented, clientTools);
  });

  test('the prompt explains every tool, and only tools that exist', () {
    final builtIn = ((agent['prompt']! as Json)['built_in_tools']! as Json).keys;
    final known = {for (final t in tools) t['name']! as String, ...builtIn};
    final mentioned = RegExp(
      r'^- ([a-z_]+):',
      multiLine: true,
    ).allMatches(prompt.substring(prompt.indexOf('# Tools'))).map((m) => m.group(1)!).toSet();
    expect(mentioned.difference(known), isEmpty);
    // Also guards against this passing vacuously if the bullet format changes.
    expect(clientTools.difference(mentioned), isEmpty, reason: 'tools the prompt never explains');
  });

  test('dynamic variables match between prompt, config and app', () {
    final presets =
        ((config['agent']! as Json)['conversation_config']! as Json)['language_presets']! as Json;
    final greetings = [
      agent['first_message']! as String,
      for (final preset in presets.values.cast<Json>())
        ((preset['overrides']! as Json)['agent']! as Json)['first_message']! as String,
    ];
    final used = {
      for (final text in [prompt, ...greetings])
        for (final m in RegExp(r'\{\{(\w+)\}\}').allMatches(text))
          if (!m.group(1)!.startsWith('system__')) m.group(1)!,
    };
    final placeholders =
        ((agent['dynamic_variables']! as Json)['dynamic_variable_placeholders']! as Json).keys
            .toSet();
    final sent = AgentContext.variables(
      firstName: 'Alex',
      channel: SupportChannel.voice,
      entryPoint: EntryPoint.helpButton,
    ).keys.toSet();

    expect(used.difference(placeholders), isEmpty, reason: 'variables without a placeholder');
    expect(sent, placeholders);
  });
}
