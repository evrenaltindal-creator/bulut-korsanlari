import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'paint_kit.dart';

/// A floating stick: it appears wherever the thumb lands on its half of
/// the screen and reports how far the thumb has moved since. A tap that
/// never turns into a drag goes to [onTapAt] instead (marking a target).
class TouchStick extends PositionComponent with DragCallbacks, TapCallbacks {
  TouchStick({this.radius = 62});

  final double radius;

  /// Called with the screen position of a plain tap.
  bool Function(Vector2 screen)? onTapAt;
  Vector2? _origin;
  Vector2 _knob = Vector2.zero();

  /// -1..1 on both axes; y is positive upwards.
  double get valueX =>
      _origin == null ? 0 : (_knob.x / radius).clamp(-1.0, 1.0);
  double get valueY =>
      _origin == null ? 0 : (-_knob.y / radius).clamp(-1.0, 1.0);

  @override
  void onTapUp(TapUpEvent event) => onTapAt?.call(event.canvasPosition);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _origin = event.localPosition.clone();
    _knob = Vector2.zero();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final o = _origin;
    if (o == null) return;
    final d = event.localEndPosition - o;
    if (d.length > radius) d.scaleTo(radius);
    _knob = d;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _origin = null;
    _knob = Vector2.zero();
  }

  @override
  void render(Canvas canvas) {
    final o = _origin;
    final center = o == null
        ? Offset(radius + 40, size.y - radius - 40)
        : Offset(o.x, o.y);
    final idle = o == null;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Color.fromRGBO(16, 32, 47, idle ? 0.18 : 0.32),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Palette.hud.withValues(alpha: idle ? 0.25 : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      center + Offset(_knob.x, _knob.y),
      radius * 0.42,
      Paint()..color = Palette.hud.withValues(alpha: idle ? 0.3 : 0.7),
    );
  }
}

/// The right half of the screen: holding anywhere on it presses the
/// action (fire); each new press also calls [onPress] once (bomb).
///
/// A tap is cancelled as soon as the finger slides and a drag takes over,
/// so taps and drags are tracked separately and either keeps it held.
class ActionZone extends PositionComponent with TapCallbacks, DragCallbacks {
  ActionZone({required this.label});

  String label;
  void Function()? onPress;

  /// Offered every new tap first, with its screen position; returning true
  /// takes the tap (a target was marked) so it does not fire.
  bool Function(Vector2 screen)? onTapAt;
  final Set<int> _taps = {};
  final Set<int> _drags = {};
  double _t = 0;

  bool get isDown => _taps.isNotEmpty || _drags.isNotEmpty;

  void _press(void Function() add) {
    final was = isDown;
    add();
    if (!was) onPress?.call();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (onTapAt?.call(event.canvasPosition) ?? false) return;
    _press(() => _taps.add(event.pointerId));
  }

  @override
  void onTapUp(TapUpEvent event) => _taps.remove(event.pointerId);

  @override
  void onTapCancel(TapCancelEvent event) => _taps.remove(event.pointerId);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _press(() => _drags.add(event.pointerId));
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _drags.remove(event.pointerId);
  }

  @override
  void render(Canvas canvas) {
    const r = 46.0;
    final c = Offset(size.x - r - 40, size.y - r - 40);
    final down = isDown;
    canvas.drawCircle(
      c,
      r * (down ? 0.94 : 1),
      Paint()..color = Color.fromRGBO(179, 48, 43, down ? 0.75 : 0.45),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Palette.hud.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    paintLabel(canvas, label, c, size: 13, anchor: const Offset(0.5, 0.5));
    // A faint pulsing ring hints that the whole half is touchable.
    final hint = Paint()
      ..color = const Color(0x14FFD27A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(c, r + 10 + 4 * math.sin(_t * 2.5), hint);
  }
}
