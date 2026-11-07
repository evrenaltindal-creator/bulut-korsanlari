import 'package:flutter/material.dart';

import '../audio/music.dart';
import 'scope.dart';

/// Tells the navigator which routes come and go, so a screen can claim
/// the music again when the player comes back to it.
final RouteObserver<ModalRoute<void>> musicRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// Plays [track] while the screen holding it is the top route.
class MusicCue extends StatefulWidget {
  const MusicCue({super.key, required this.track, required this.child});

  final MusicTrack track;
  final Widget child;

  @override
  State<MusicCue> createState() => _MusicCueState();
}

class _MusicCueState extends State<MusicCue> with RouteAware {
  ModalRoute<void>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) musicRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) {
        // Calls didPush straight away.
        musicRouteObserver.subscribe(this, route);
      } else {
        _apply();
      }
    }
  }

  @override
  void didUpdateWidget(MusicCue old) {
    super.didUpdateWidget(old);
    if (old.track != widget.track) _apply();
  }

  @override
  void dispose() {
    musicRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() => _apply();

  @override
  void didPopNext() => _apply();

  void _apply() {
    if (_route != null && !_route!.isCurrent) return;
    StoreScope.read(context).music.play(widget.track);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
