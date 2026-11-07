import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/paint_kit.dart';

/// Slowly drifting floating islands and clouds behind the menus.
class SkyBackdrop extends StatefulWidget {
  const SkyBackdrop({super.key, required this.child, this.animate = true});

  final Widget child;
  final bool animate;

  @override
  State<SkyBackdrop> createState() => _SkyBackdropState();
}

class _SkyBackdropState extends State<SkyBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) =>
                CustomPaint(painter: _SkyPainter(_c.value)),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.t);

  final double t;
  static final _rng = math.Random(4);
  static final List<CloudShape> _clouds = List.generate(
    9,
    (_) => CloudShape(_rng, puffs: 5),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Palette.skyTop,
            Palette.skyMid,
            Palette.skyHorizon,
            Palette.cloudSeaNear,
          ],
          stops: [0, 0.5, 0.78, 1],
        ).createShader(Offset.zero & size),
    );
    final w = size.width;
    final h = size.height;
    // Far islands.
    const islands = [
      (0.12, 0.62, 0.05, 3),
      (0.78, 0.55, 0.07, 9),
      (0.48, 0.7, 0.035, 21),
    ];
    for (final (x, y, r, seed) in islands) {
      final dx = math.sin((t + seed) * math.pi * 2) * w * 0.01;
      final dy = math.sin((t * 2 + seed) * math.pi * 2) * h * 0.01;
      paintFloatingIsland(
        canvas,
        Offset(x * w + dx, y * h + dy),
        r * w,
        seed,
        opacity: 0.9,
      );
    }
    // Clouds drifting left to right.
    for (var i = 0; i < _clouds.length; i++) {
      final speed = 0.6 + (i % 3) * 0.35;
      final x = ((i / _clouds.length + t * speed) % 1.2 - 0.1) * w;
      final y = h * (0.18 + (i * 37 % 60) / 100);
      _clouds[i].paint(
        canvas,
        Offset(x, y),
        w * (0.025 + (i % 4) * 0.008),
        0.55,
      );
    }
    // Cloud sea along the bottom.
    final sea = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w + 40; x += 40) {
      sea.lineTo(x, h * 0.9 + math.sin(x / 70 + t * math.pi * 4) * 8);
    }
    sea
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(sea, Paint()..color = const Color(0xDDF4EEF6));
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t;
}
