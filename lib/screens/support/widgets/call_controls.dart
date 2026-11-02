import 'package:flutter/material.dart';

import '../../../theme.dart';

/// The card under the orb: type instead of speaking, mute, end the call.
class CallControls extends StatelessWidget {
  const CallControls({
    super.key,
    required this.input,
    required this.enabled,
    required this.muted,
    required this.onSend,
    required this.onToggleMute,
    required this.onEnd,
  });

  final TextEditingController input;
  final bool enabled;
  final bool muted;
  final VoidCallback onSend;
  final VoidCallback? onToggleMute;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: input,
            enabled: enabled,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(
              hintText: 'Type instead of speaking',
              border: InputBorder.none,
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEnd,
                icon: const Icon(Icons.call_end),
                label: const Text('End call'),
                style: TextButton.styleFrom(foregroundColor: colors.danger),
              ),
              const Spacer(),
              IconButton(
                tooltip: muted ? 'Unmute' : 'Mute',
                onPressed: onToggleMute,
                icon: Icon(muted ? Icons.mic_off : Icons.mic_none),
                color: muted ? colors.danger : colors.ink,
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: input,
                builder: (context, value, _) => FilledButton(
                  onPressed: enabled && value.text.trim().isNotEmpty ? onSend : null,
                  style: FilledButton.styleFrom(backgroundColor: colors.ink),
                  child: const Text('Send'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
