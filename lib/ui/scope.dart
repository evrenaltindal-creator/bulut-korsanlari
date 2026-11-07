import 'package:flutter/material.dart';

import '../campaign/store.dart';

/// Makes the [GameStore] reachable from any widget and rebuilds
/// dependants when it changes.
class StoreScope extends InheritedNotifier<GameStore> {
  const StoreScope({super.key, required GameStore store, required super.child})
    : super(notifier: store);

  static GameStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static GameStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

extension StoreContext on BuildContext {
  GameStore get store => StoreScope.of(this);

  String tr(String key, [Map<String, Object> args = const {}]) =>
      StoreScope.of(this).strings.t(key, args);
}
