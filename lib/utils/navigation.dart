import 'package:flutter/material.dart';

/// Global navigator key used across the app for showing dialogs, etc.
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// Observer to track the currently active route name, so layout elements (like MiniPlayer)
/// can adjust their position and safe areas dynamically.
class AppRouteObserver extends NavigatorObserver {
  static final AppRouteObserver instance = AppRouteObserver();

  final ValueNotifier<String?> currentRouteNotifier = ValueNotifier<String?>(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    currentRouteNotifier.value = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    currentRouteNotifier.value = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    currentRouteNotifier.value = newRoute?.settings.name;
  }
}
