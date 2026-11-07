import 'package:flutter/material.dart';

import '../audio/music.dart';
import '../campaign/characters.dart';
import 'logbook_screen.dart';
import 'music_cue.dart';
import 'scope.dart';
import 'theme.dart';

/// A full-screen chapter cover shown when a new chapter of the story
/// begins. Any tap goes on to the logbook.
class ChapterScreen extends StatelessWidget {
  const ChapterScreen({super.key, required this.chapter});

  final int chapter;

  void _next(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LogbookScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return MusicCue(
      track: MusicTrack.logbook,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _next(context),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                Art.chapter(chapter),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.night),
              ),
              // Darken the bottom so the title reads over any painting.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                start: pad.left + 28,
                end: pad.right + 28,
                bottom: pad.bottom + 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('chapter.label', {'n': chapter}).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 14,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(color: Color(0xCC000000), blurRadius: 6),
                        ],
                      ),
                    ),
                    Text(
                      context.tr('chapter.$chapter'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        shadows: [
                          Shadow(color: Color(0xCC000000), blurRadius: 10),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('chapter.tap'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        shadows: [
                          Shadow(color: Color(0xCC000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
