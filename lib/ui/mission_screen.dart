import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../campaign/missions.dart';
import '../game/mission_game.dart';
import '../game/mission_result.dart';
import '../game/paint_kit.dart';
import 'debrief_screen.dart';
import 'scope.dart';

/// Builds the right Flame game for [mission].
MissionGame createMissionGame(
  MissionDef mission, {
  required PilotSkills skills,
  required Tr tr,
  required void Function(MissionResult) onFinished,
  bool invertY = false,
  EdgeInsetsLike safe = const EdgeInsetsLike(),
}) => switch (mission.kind) {
  MissionKind.dogfight => DogfightGame(
    config: mission.dogfight!,
    skills: skills,
    tr: tr,
    onFinished: onFinished,
    invertY: invertY,
    safe: safe,
  ),
  MissionKind.raid => RaidGame(
    config: mission.raid!,
    skills: skills,
    tr: tr,
    onFinished: onFinished,
    invertY: invertY,
    safe: safe,
  ),
  MissionKind.bombing => BombingGame(
    config: mission.bombing!,
    skills: skills,
    tr: tr,
    onFinished: onFinished,
    invertY: invertY,
    safe: safe,
  ),
};

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key, required this.mission});

  final MissionDef mission;

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  MissionGame? _game;
  bool _paused = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.read(context);
    final pad = MediaQuery.paddingOf(context);
    final safe = EdgeInsetsLike(
      left: pad.left,
      top: pad.top,
      right: pad.right,
      bottom: pad.bottom,
    );
    final game = _game;
    if (game == null) {
      _game = createMissionGame(
        widget.mission,
        skills: store.campaign!.activePilot.skills,
        tr: store.strings.t,
        onFinished: _finish,
        invertY: store.invertY,
        safe: safe,
      );
    } else {
      game.safe = safe;
    }
  }

  void _finish(MissionResult result) {
    if (_done) return;
    _done = true;
    // Called from the game loop; navigate once the frame is over.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final debrief = await StoreScope.read(context).recordResult(result);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DebriefScreen(debrief: debrief),
        ),
      );
    });
  }

  void _setPaused(bool value) {
    final game = _game!;
    setState(() => _paused = value);
    value ? game.pauseEngine() : game.resumeEngine();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_done) _setPaused(true);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: game, autofocus: true)),
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + 6,
              end: MediaQuery.paddingOf(context).right + 6,
              child: IconButton.filledTonal(
                tooltip: context.tr('pause.title'),
                icon: const Icon(Icons.pause),
                onPressed: _done ? null : () => _setPaused(true),
              ),
            ),
            if (_paused)
              _PauseOverlay(
                onResume: () => _setPaused(false),
                onAbandon: () {
                  _setPaused(false);
                  game.pauseEngine();
                  _finish(game.abandonResult());
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onAbandon});

  final VoidCallback onResume;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xAA0F2238),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('pause.title'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onResume,
                child: Text(context.tr('pause.resume')),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onAbandon,
                child: Text(context.tr('pause.abandon')),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('pause.abandonHint'),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
