import 'package:flutter/material.dart';

/// Black Lock's look: near-black, one electric blue, frosted-glass cards.
abstract final class BL {
  static const bg = Color(0xFF07080B);
  static const ink = Color(0xFFEEF1F6);
  static const muted = Color(0xFF8C94A6);
  static const faint = Color(0xFF5B6273);
  static const accent = Color(0xFF3D7BFF);
  static const accentHi = Color(0xFF8DB2FF);
  static const cyan = Color(0xFF6FD3FF);
  static const good = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const glass = Color(0x0FFFFFFF);
  static const glassLine = Color(0x1AFFFFFF);

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
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A frosted card: faint white fill, hairline border.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.borderColor = BL.glassLine,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BL.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
