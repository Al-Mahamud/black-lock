import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// What the orb is showing.
enum OrbMode { setup, ready, countdown }

/// The big round "Lock now" button in the middle of the screen.
/// Ready: a slowly breathing blue glow. Countdown: the ring drains and the seconds count down.
class LockOrb extends StatefulWidget {
  const LockOrb({
    super.key,
    required this.mode,
    required this.onTap,
    this.countdown,
    this.size = 236,
  });

  final OrbMode mode;
  final VoidCallback? onTap;

  /// Runs from 1 to 0 while counting down.
  final Animation<double>? countdown;
  final double size;

  @override
  State<LockOrb> createState() => _LockOrbState();
}

class _LockOrbState extends State<LockOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreath();
  }

  @override
  void didUpdateWidget(LockOrb old) {
    super.didUpdateWidget(old);
    _syncBreath();
  }

  void _syncBreath() {
    final still = MediaQuery.of(context).disableAnimations;
    if (widget.mode == OrbMode.ready && !still) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0.5;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

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
          scale: _pressed ? 0.95 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedBuilder(
            animation: Listenable.merge([_breath, widget.countdown]),
            builder: (context, _) {
              final glow = mode == OrbMode.setup
                  ? 0.0
                  : 0.35 + 0.25 * Curves.easeInOut.transform(_breath.value);
              final remaining = widget.countdown?.value ?? 1;
              return SizedBox.square(
                dimension: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // soft glow
                    Container(
                      width: widget.size * 0.86,
                      height: widget.size * 0.86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: BL.accent.withValues(alpha: glow),
                            blurRadius: 48 + 30 * glow,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    CustomPaint(
                      size: Size.square(widget.size),
                      painter: _RingPainter(mode: mode, remaining: remaining),
                    ),
                    _Centre(mode: mode, remaining: remaining),
                  ],
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
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$secs', style: BL.display(68, FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            'Locking…',
            style: BL.display(15, FontWeight.w500, color: BL.accentHi),
          ),
        ],
      );
    }
    final ready = mode == OrbMode.ready;
    return Opacity(
      opacity: ready ? 1 : 0.38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandGlyph(size: 58),
          const SizedBox(height: 16),
          Text('Lock now', style: BL.display(20, FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            ready ? 'Tap to black out' : 'Finish setup first',
            style: const TextStyle(
              fontSize: 12.5,
              color: BL.muted,
              letterSpacing: 0.2,
            ),
          ),
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
    final r = size.width / 2 - 14;

    // inner disc
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.45),
          radius: 1.0,
          colors: [Color(0xFF1C2638), Color(0xFF0B0E15)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // faint outer guide ring
    canvas.drawCircle(
      c,
      r + 9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x14FFFFFF),
    );

    final rect = Rect.fromCircle(center: c, radius: r);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    switch (mode) {
      case OrbMode.setup:
        canvas.drawCircle(c, r, ring..color = const Color(0x24FFFFFF));
      case OrbMode.ready:
        ring.shader = const SweepGradient(
          colors: [BL.accent, BL.cyan, BL.accentHi, BL.accent],
          stops: [0, 0.35, 0.7, 1],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect);
        canvas.drawCircle(c, r, ring);
      case OrbMode.countdown:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0x1FFFFFFF),
        );
        ring.shader = const SweepGradient(
          colors: [BL.cyan, BL.accent],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect);
        canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * remaining,
          false,
          ring..strokeWidth = 4,
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
