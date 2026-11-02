import 'package:flutter/material.dart';

import '../../../theme.dart';

enum OrbMode { connecting, listening, speaking, muted }

/// A soft glowing orb: indigo while listening, teal while the agent speaks,
/// grey while connecting or muted.
///
/// The agent's speech drives a slow breath and the customer's voice nudges
/// the orb. The final size is always eased, including when the state
/// changes, so the orb never jumps.
class VoiceOrb extends StatelessWidget {
  const VoiceOrb({
    super.key,
    required this.mode,
    required this.breath,
    required this.level,
    this.size = 180,
  });

  final OrbMode mode;

  /// 0..1, eased, from a slow repeating animation.
  final double breath;

  /// 0..1, the customer's voice level.
  final double level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (mode) {
      OrbMode.listening => colors.orbListening,
      OrbMode.speaking => colors.orbSpeaking,
      OrbMode.connecting || OrbMode.muted => colors.orbIdle,
    };
    final scale = switch (mode) {
      OrbMode.speaking => 1 + 0.06 * breath,
      OrbMode.connecting => 1 + 0.03 * breath,
      OrbMode.listening => 1 + 0.08 * level.clamp(0.0, 1.0),
      OrbMode.muted => 1.0,
    };
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.35),
            colors: [Color.lerp(color, Colors.white, 0.45)!, color],
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 4),
          ],
        ),
      ),
    );
  }
}
