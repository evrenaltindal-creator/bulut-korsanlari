import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'campaign/store.dart';
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
  );
  runApp(CloudCorsairsApp(store: store));
}

class CloudCorsairsApp extends StatelessWidget {
  const CloudCorsairsApp({super.key, required this.store});

  final GameStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: Builder(
        builder: (context) => MaterialApp(
          title: context.tr('app.title'),
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const TitleScreen(),
        ),
      ),
    );
  }
}
