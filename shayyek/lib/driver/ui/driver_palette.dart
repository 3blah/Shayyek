import 'package:flutter/material.dart';

class DriverPalette {
  final Color pageBg;
  final Color card;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color shadow;
  final Color primary;
  final Color secondary;
  final Color available;
  final Color occupied;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconMuted;

  const DriverPalette({
    required this.pageBg,
    required this.card,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.shadow,
    required this.primary,
    required this.secondary,
    required this.available,
    required this.occupied,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconMuted,
  });

  factory DriverPalette.of(bool dark) {
    if (dark) {
      return const DriverPalette(
        pageBg: Color(0xFF07111F),
        card: Color(0xFF0E1C2F),
        surfaceAlt: Color(0xFF12243A),
        border: Color(0xFF1E3550),
        borderStrong: Color(0xFF2A4A6F),
        shadow: Color(0xFF000000),
        primary: Color(0xFF0B3C7A),
        secondary: Color(0xFF19D3FF),
        available: Color(0xFF22C55E),
        occupied: Color(0xFFEF4444),
        textPrimary: Color(0xFFEAF4FF),
        textSecondary: Color(0xFF9FB3C8),
        iconMuted: Color(0xFFB8CAE0),
      );
    }

    return const DriverPalette(
      pageBg: Color(0xFFF6FAFF),
      card: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFF8FBFF),
      border: Color(0xFFD7E4F2),
      borderStrong: Color(0xFFBFD2E6),
      shadow: Color(0xFF0F172A),
      primary: Color(0xFF0B3C7A),
      secondary: Color(0xFF00B7E8),
      available: Color(0xFF16A34A),
      occupied: Color(0xFFDC2626),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF475569),
      iconMuted: Color(0xFF64748B),
    );
  }
}
