import 'package:flutter/material.dart';

/// Colours the Material [ColorScheme] has no role for. Widgets read these
/// instead of hard-coding hex values.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ink,
    required this.muted,
    required this.canvas,
    required this.border,
    required this.receipt,
    required this.onReceipt,
    required this.danger,
    required this.live,
    required this.income,
    required this.cardActive,
    required this.cardFrozen,
    required this.orbListening,
    required this.orbSpeaking,
    required this.orbIdle,
  });

  final Color ink;
  final Color muted;
  final Color canvas;
  final Color border;

  /// Background and foreground of an action receipt ("Card frozen").
  final Color receipt;
  final Color onReceipt;
  final Color danger;

  /// An ongoing call or chat.
  final Color live;
  final Color income;
  final List<Color> cardActive;
  final List<Color> cardFrozen;

  /// The voice orb: one colour per state, so it's clear who is talking.
  final Color orbListening;
  final Color orbSpeaking;

  /// Connecting or muted.
  final Color orbIdle;

  static const light = AppColors(
    ink: Color(0xFF111827),
    muted: Color(0xFF6B7280),
    canvas: Color(0xFFF6F7F9),
    border: Color(0xFFE5E7EB),
    receipt: Color(0xFFE7F6EF),
    onReceipt: Color(0xFF0B3B36),
    danger: Color(0xFFDC2626),
    live: Color(0xFF16A34A),
    income: Color(0xFF15803D),
    cardActive: [Color(0xFF0F766E), Color(0xFF1E3A8A)],
    cardFrozen: [Color(0xFF64748B), Color(0xFF334155)],
    orbListening: Color(0xFF6366F1),
    orbSpeaking: Color(0xFF14B8A6),
    orbIdle: Color(0xFF94A3B8),
  );

  @override
  AppColors copyWith({Color? ink, Color? muted, Color? canvas}) => AppColors(
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    canvas: canvas ?? this.canvas,
    border: border,
    receipt: receipt,
    onReceipt: onReceipt,
    danger: danger,
    live: live,
    income: income,
    cardActive: cardActive,
    cardFrozen: cardFrozen,
    orbListening: orbListening,
    orbSpeaking: orbSpeaking,
    orbIdle: orbIdle,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      canvas: mix(canvas, other.canvas),
      border: mix(border, other.border),
      receipt: mix(receipt, other.receipt),
      onReceipt: mix(onReceipt, other.onReceipt),
      danger: mix(danger, other.danger),
      live: mix(live, other.live),
      income: mix(income, other.income),
      cardActive: t < 0.5 ? cardActive : other.cardActive,
      cardFrozen: t < 0.5 ? cardFrozen : other.cardFrozen,
      orbListening: mix(orbListening, other.orbListening),
      orbSpeaking: mix(orbSpeaking, other.orbSpeaking),
      orbIdle: mix(orbIdle, other.orbIdle),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

abstract final class AppTheme {
  static const brand = Color(0xFF0F766E);

  /// Reference IDs and diagnostics. Menlo exists on iOS; the fallbacks cover
  /// other platforms.
  static const mono = TextStyle(fontFamily: 'Menlo', fontFamilyFallback: ['Courier', 'monospace']);

  static ThemeData light() => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: brand),
    scaffoldBackgroundColor: AppColors.light.canvas,
    extensions: const [AppColors.light],
  );
}
