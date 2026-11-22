import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// What the orb is showing.
enum OrbMode { setup, ready, countdown }

/// The big round "Lock now" button in the middle of the screen.
/// A thin ring on black; during the countdown the ring drains and the seconds count down.
class LockOrb extends StatefulWidget {
  const LockOrb({
    super.key,
    required this.mode,
    required this.onTap,
    this.countdown,
    this.size = 220,
  });

  final OrbMode mode;
  final VoidCallback? onTap;

  /// Runs from 1 to 0 while counting down.
  final Animation<double>? countdown;
  final double size;

  @override
  State<LockOrb> createState() => _LockOrbState();
}

class _LockOrbState extends State<LockOrb> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final enabled = mode == OrbMode.ready && widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: switch (mode) {
        OrbMode.setup => 'Lock now, needs setup first',
        OrbMode.ready => 'Lock now',
        OrbMode.countdown => 'Locking soon',
      },
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedBuilder(
            animation: widget.countdown ?? kAlwaysCompleteAnimation,
            builder: (context, _) {
              final remaining = widget.countdown?.value ?? 1;
              return SizedBox.square(
                dimension: widget.size,
                child: CustomPaint(
                  painter: _RingPainter(mode: mode, remaining: remaining),
                  child: Center(
                    child: _Centre(mode: mode, remaining: remaining),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.mode, required this.remaining});

  final OrbMode mode;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    if (mode == OrbMode.countdown) {
      final secs = (remaining * 5).ceil().clamp(1, 5);
      return Text(
        '$secs',
        style: BL.display(72, FontWeight.w500).copyWith(height: 1),
      );
    }
    return Opacity(
      opacity: mode == OrbMode.ready ? 1 : 0.35,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandGlyph(size: 50),
          const SizedBox(height: 14),
          Text('Lock now', style: BL.display(19, FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.mode, required this.remaining});

  final OrbMode mode;
  final double remaining;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0A0B0E));

    switch (mode) {
      case OrbMode.setup:
        canvas.drawCircle(c, r, stroke..color = const Color(0x1FFFFFFF));
      case OrbMode.ready:
        canvas.drawCircle(c, r, stroke..color = BL.accent);
      case OrbMode.countdown:
        canvas.drawCircle(c, r, stroke..color = const Color(0x1FFFFFFF));
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          2 * math.pi * remaining,
          false,
          stroke
            ..color = BL.accent
            ..strokeWidth = 3,
        );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.mode != mode || old.remaining != remaining;
}

/// The logo mark (padlock + swipe trail + fingertip), drawn as vectors so it is sharp at any size.
class BrandGlyph extends StatelessWidget {
  const BrandGlyph({
    super.key,
    required this.size,
    this.color = BL.ink,
    this.trail = BL.accent,
  });

  final double size;
  final Color color;
  final Color trail;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(color, trail),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.color, this.trail);

  final Color color;
  final Color trail;

  @override
  void paint(Canvas canvas, Size size) {
    // Same geometry as docs/logo.svg: the mark spans x 31–77, y 25–82 of a 108 grid.
    final s = size.height / 57;
    canvas.save();
    canvas.translate((size.width - 46 * s) / 2 - 31 * s, -25 * s);
    canvas.scale(s);

    final shackle = Path()
      ..moveTo(41, 50)
      ..lineTo(41, 41)
      ..arcToPoint(const Offset(67, 41), radius: const Radius.circular(13))
      ..lineTo(67, 50);
    canvas.drawPath(
      shackle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(31, 47, 77, 82, const Radius.circular(9)),
      Paint()..color = color,
    );
    canvas.drawLine(
      const Offset(39, 64.5),
      const Offset(62, 64.5),
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [trail.withValues(alpha: 0), trail])
            .createShader(const Rect.fromLTRB(39, 60, 62, 69)),
    );
    canvas.drawCircle(const Offset(63.5, 64.5), 5, Paint()..color = trail);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.color != color || old.trail != trail;
}
