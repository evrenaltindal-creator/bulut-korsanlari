import 'package:flutter/material.dart';

import '../campaign/characters.dart';
import 'scope.dart';
import 'theme.dart';

/// A story painting pasted into the logbook: a cream border, a soft
/// shadow and two strips of tape. Optionally faded, with a rubber stamp
/// across it (a failed mission).
class Illustration extends StatelessWidget {
  const Illustration({
    super.key,
    required this.asset,
    this.stamp,
    this.faded = false,
    this.tilt = -0.012,
  });

  final String asset;
  final String? stamp;
  final bool faded;
  final double tilt;

  static const _grey = ColorFilter.matrix([
    0.33, 0.45, 0.12, 0, 10, //
    0.30, 0.45, 0.12, 0, 6,
    0.26, 0.40, 0.12, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget image = Image.asset(
      asset,
      fit: BoxFit.cover,
      cacheWidth: (900 * dpr).round().clamp(400, 1280),
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF3D6F92)),
    );
    if (faded) image = ColorFiltered(colorFilter: _grey, child: image);
    return Transform.rotate(
      angle: tilt,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFFBF6EA),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(padding: const EdgeInsets.all(5), child: image),
              ),
              if (stamp != null) Center(child: _Stamp(stamp!)),
              _tape(left: -22, angle: -0.6),
              _tape(left: c.maxWidth - 38, angle: 0.55),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tape({required double left, required double angle}) => Positioned(
    left: left,
    top: -6,
    child: Transform.rotate(
      angle: angle,
      child: Container(width: 60, height: 18, color: const Color(0x99EFE3C2)),
    ),
  );
}

class _Stamp extends StatelessWidget {
  const _Stamp(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.sail, width: 3),
          borderRadius: BorderRadius.circular(6),
          color: const Color(0x55FFFFFF),
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.sail,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

/// A character's portrait in a round frame, with the role and the name:
/// brass for the squadron, red for a pirate who is the target.
class PortraitBadge extends StatelessWidget {
  const PortraitBadge({super.key, required this.character, this.size = 84});

  final Character character;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final ring = character.isPirate ? AppColors.sail : const Color(0xFFC79A3E);
    return SizedBox(
      width: size + 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                character.asset,
                fit: BoxFit.cover,
                cacheWidth: (size * dpr).round().clamp(64, 640),
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF6B5A47)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context
                .tr(character.isPirate ? 'brief.target' : 'brief.officer')
                .toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: ring,
            ),
          ),
          Text(
            context.tr(character.nameKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
