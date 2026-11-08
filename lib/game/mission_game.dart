import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../audio/sfx.dart';
import '../core/controls.dart';
import 'bombing/bombing_painter.dart';
import 'bombing/bombing_sim.dart';
import 'dogfight/dogfight_painter.dart';
import 'dogfight/dogfight_sim.dart';
import 'mission_result.dart';
import 'paint_kit.dart';
import 'raid/raid_painter.dart';
import 'raid/raid_sim.dart';
import 'touch_controls.dart';

/// Flame host for one mission: wires touch and keyboard input into a
/// [ControlState], steps the simulation and paints it.
abstract class MissionGame extends FlameGame with KeyboardEvents {
  MissionGame({
    required this.tr,
    required this.onFinished,
    this.invertY = false,
    this.safe = const EdgeInsetsLike(),
    this.sfx,
  });

  final Tr tr;

  /// Sound effects; null keeps the mission silent (tests).
  final SfxDirector? sfx;
  final void Function(MissionResult result) onFinished;
  bool invertY;
  EdgeInsetsLike safe;

  final ControlState controls = ControlState();
  final TouchStick stick = TouchStick();
  late final ActionZone action = ActionZone(label: actionLabel);
  final Set<LogicalKeyboardKey> _keys = {};
  bool _pendingDrop = false;
  bool _reported = false;

  MissionSim get sim;
  String get actionLabel;

  /// True when the action button drops bombs rather than firing guns.
  bool get actionIsDrop => false;

  /// Whether the guns are rattling this frame.
  bool get gunsFiring => false;

  /// Engine pitch: 1 at cruising speed.
  double get engineRate => 1;

  void step(double dt, ControlState c);
  void paintScene(Canvas canvas, Size size);

  /// A tap at [screen]; true when the mission used it (a raid marks the
  /// target under the finger), false to treat it as an ordinary press.
  bool tapAt(Vector2 screen) => false;

  @override
  Color backgroundColor() => const Color(0xFF14304F);

  @override
  Future<void> onLoad() async {
    action.onPress = () {
      if (actionIsDrop) _pendingDrop = true;
    };
    action.onTapAt = tapAt;
    stick.onTapAt = tapAt;
    stick.priority = 10;
    action.priority = 10;
    camera.viewport.addAll([_Scene(this), stick, action]);
    _layout(size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout(size);
  }

  void _layout(Vector2 s) {
    stick
      ..position = Vector2.zero()
      ..size = Vector2(s.x / 2, s.y);
    action
      ..position = Vector2(s.x / 2, 0)
      ..size = Vector2(s.x / 2, s.y);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _readControls();
    // Fixed-size sub-steps keep fast bullets and AI stable after a hitch.
    var remaining = math.min(dt, 0.1);
    while (remaining > 1e-6) {
      final h = math.min(remaining, 1 / 60);
      step(h, controls);
      controls.drop = false;
      remaining -= h;
    }
    _sound(dt);
    final r = sim.result;
    if (r != null && !_reported) {
      _reported = true;
      onFinished(r);
    }
  }

  void _sound(double dt) {
    final s = sfx;
    if (s != null) {
      s.tick(dt);
      for (final e in sim.events) {
        s.event(e);
      }
      final flying = sim.result == null && sim.health > 0;
      s.guns(on: flying && gunsFiring);
      s.engine(on: sim.result == null, rate: engineRate);
    }
    sim.events.clear();
  }

  @override
  void onRemove() {
    sfx?.stopLoops();
    super.onRemove();
  }

  /// Pause menu: freezes the game and its sound together.
  void setPaused(bool paused) {
    if (paused) {
      pauseEngine();
      sfx?.pause();
    } else {
      resumeEngine();
      sfx?.resume();
    }
  }

  void _readControls() {
    double axis(
      LogicalKeyboardKey neg,
      LogicalKeyboardKey neg2,
      LogicalKeyboardKey pos,
      LogicalKeyboardKey pos2,
    ) =>
        (_keys.contains(pos) || _keys.contains(pos2) ? 1.0 : 0.0) -
        (_keys.contains(neg) || _keys.contains(neg2) ? 1.0 : 0.0);
    final kx = axis(
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyD,
    );
    final ky = axis(
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.keyW,
    );
    controls.stickX = (stick.valueX + kx).clamp(-1.0, 1.0);
    final y = (stick.valueY + ky).clamp(-1.0, 1.0);
    controls.stickY = invertY ? -y : y;
    controls.fire = action.isDown || _keys.contains(LogicalKeyboardKey.space);
    controls.drop = _pendingDrop;
    _pendingDrop = false;
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _keys
      ..clear()
      ..addAll(keysPressed);
    if (event is KeyDownEvent &&
        actionIsDrop &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.keyB)) {
      _pendingDrop = true;
    }
    return KeyEventResult.handled;
  }

  /// Ends the mission early (from the pause menu). Counts as a failure,
  /// but the pilot comes home.
  MissionResult abandonResult() =>
      const MissionResult(outcome: MissionOutcome.objectiveFailed);
}

class _Scene extends Component {
  _Scene(this.host);

  final MissionGame host;

  @override
  void render(Canvas canvas) {
    final s = host.size;
    host.paintScene(canvas, Size(s.x, s.y));
  }
}

class DogfightGame extends MissionGame {
  DogfightGame({
    required DogfightConfig config,
    PilotSkills skills = const PilotSkills(),
    required super.tr,
    required super.onFinished,
    super.invertY,
    super.safe,
    super.sfx,
  }) : sim = DogfightSim(config: config, skills: skills) {
    painter = DogfightPainter(sim, tr);
  }

  @override
  final DogfightSim sim;
  late final DogfightPainter painter;

  @override
  String get actionLabel => tr('control.fire');

  @override
  bool get gunsFiring => controls.fire && !sim.jammed && !sim.playerDown;

  @override
  double get engineRate => (sim.player.speed / 250).clamp(0.8, 1.3);

  @override
  void step(double dt, ControlState c) => sim.update(dt, c);

  @override
  void paintScene(Canvas canvas, Size size) =>
      painter.paint(canvas, size, safe);
}

class RaidGame extends MissionGame {
  RaidGame({
    required RaidConfig config,
    PilotSkills skills = const PilotSkills(),
    required super.tr,
    required super.onFinished,
    super.invertY,
    super.safe,
    super.sfx,
  }) : sim = RaidSim(config: config, skills: skills) {
    painter = RaidPainter(sim, tr);
  }

  @override
  final RaidSim sim;
  late final RaidPainter painter;

  @override
  String get actionLabel => tr('control.fire');

  @override
  bool get gunsFiring => (controls.fire || sim.lockedOn) && !sim.planeDown;

  @override
  bool tapAt(Vector2 screen) {
    final t = painter.targetAt(Offset(screen.x, screen.y));
    if (t == null) return false;
    sim.mark(t);
    return true;
  }

  @override
  void step(double dt, ControlState c) => sim.update(dt, c);

  @override
  void paintScene(Canvas canvas, Size size) =>
      painter.paint(canvas, size, safe);
}

class BombingGame extends MissionGame {
  BombingGame({
    required BombingConfig config,
    PilotSkills skills = const PilotSkills(),
    required super.tr,
    required super.onFinished,
    super.invertY,
    super.safe,
    super.sfx,
  }) : sim = BombingSim(config: config, skills: skills) {
    painter = BombingPainter(sim, tr);
  }

  @override
  final BombingSim sim;
  late final BombingPainter painter;

  @override
  String get actionLabel => tr('control.drop');

  @override
  bool get actionIsDrop => true;

  @override
  double get engineRate => (sim.speed / 150).clamp(0.85, 1.2);

  @override
  void step(double dt, ControlState c) => sim.update(dt, c);

  @override
  void paintScene(Canvas canvas, Size size) =>
      painter.paint(canvas, size, safe);
}
