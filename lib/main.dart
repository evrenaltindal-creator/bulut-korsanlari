import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/audioplayers_backend.dart';
import 'campaign/store.dart';
import 'ui/music_cue.dart';
import 'ui/scope.dart';
import 'ui/theme.dart';
import 'ui/title_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final store = await GameStore.load(
    deviceLang: PlatformDispatcher.instance.locale.languageCode,
    backend: AudioplayersBackend(),
  );
  runApp(CloudCorsairsApp(store: store));
}

class CloudCorsairsApp extends StatefulWidget {
  const CloudCorsairsApp({super.key, required this.store});

  final GameStore store;

  @override
  State<CloudCorsairsApp> createState() => _CloudCorsairsAppState();
}

class _CloudCorsairsAppState extends State<CloudCorsairsApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Music stops when the game leaves the screen and comes back with it.
    _lifecycle = AppLifecycleListener(
      onHide: widget.store.music.pause,
      onShow: widget.store.music.resume,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      // Browsers only allow sound after the first touch (on touch
      // screens, once the finger lifts).
      child: Listener(
        onPointerDown: (_) => widget.store.music.unlock(),
        onPointerUp: (_) => widget.store.music.unlock(),
        child: Builder(
          builder: (context) => MaterialApp(
            title: context.tr('app.title'),
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            navigatorObservers: [musicRouteObserver],
            home: const TitleScreen(),
          ),
        ),
      ),
    );
  }
}
