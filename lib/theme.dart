import 'package:flutter/material.dart';

/// Black Lock's look: pure black, white text, one blue accent.
abstract final class BL {
  static const bg = Color(0xFF000000);
  static const ink = Color(0xFFEEF1F6);
  static const muted = Color(0xFF8C94A6);
  static const accent = Color(0xFF3D7BFF);
  static const accentHi = Color(0xFF8DB2FF);

  /// Darker blue for filled buttons, so their white label stays readable (≥ 4.5:1).
  static const accentDeep = Color(0xFF2E66E8);
  static const good = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const hairline = Color(0x24FFFFFF);

  /// Sora is a variable font: the weight goes through the 'wght' axis as well.
  static TextStyle display(
    double size,
    FontWeight weight, {
    Color color = ink,
  }) => TextStyle(
    fontFamily: 'Sora',
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    letterSpacing: -0.2,
    height: 1.15,
  );

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(primary: accent, onPrimary: Colors.white, surface: bg);
    const label = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentDeep,
          foregroundColor: Colors.white,
          textStyle: label,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 28),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentHi,
          textStyle: label,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: hairline),
          textStyle: label.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ),
    );
  }
}
