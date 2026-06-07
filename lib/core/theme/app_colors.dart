import 'package:flutter/material.dart';

/// Wellness / lifestyle iOS-like tokens.
abstract final class AppColors {
  static const background = Color(0xFFF3F4F1);
  static const surface = Color(0xFFFFFFFF);
  static const surfacePrimary = Color(0xFFE3E1D8);
  static const surfaceSecondary = Color(0xFFD3D2CA);

  static const textPrimary = Color(0xFF0B0B0B);
  static const textOnDark = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF6F716C);
  static const textMuted = Color(0xFFA4A49D);
  static const textDisabled = Color(0xFFB0B0B0);

  static const border = Color(0xFFD0D0C8);
  static const divider = Color(0xFFC8C8C0);
  static const darkCard = Color(0xFF2F3838);

  static const tan = Color(0xFFC7A176);
  static const coral = Color(0xFFEF5C4E);

  static const primary = coral;
  static const secondary = tan;
  static const success = Color(0xFF5A8F4E);
  static const warning = tan;
  static const error = coral;

  static const textOnAccent = Color(0xFFFFFFFF);
  static const disabled = Color(0xFFD8D8D8);
  static const shadow = Color(0x140B0B0B);

  // Legacy aliases
  static const anthropicDark = textPrimary;
  static const pampas = background;
  static const midGray = textMuted;
  static const lightGray = surfacePrimary;
  static const surfaceVariant = surfacePrimary;
  static const surfaceMuted = surfaceSecondary;
  static const accentYellow = tan;
  static const accentYellowPressed = Color(0xFFB8895E);
  static const crailOrange = coral;
  static const crailOrangeLight = Color(0xFFF25F50);
  static const slateBlue = textSecondary;
  static const oliveGreen = success;
}
