import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'logger.dart';

/// Global navigator key used across the app for showing dialogs, etc.
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// Observer to track the currently active route name, so layout elements (like MiniPlayer)
/// can adjust their position and safe areas dynamically.
///
/// 开发者工具：非 Release 构建下将导航栈变化记录到日志（Tag: ROUTE）。
class AppRouteObserver extends NavigatorObserver {
  static final AppRouteObserver instance = AppRouteObserver();

  final ValueNotifier<String?> currentRouteNotifier =
      ValueNotifier<String?>(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Push route settings to notifier
    currentRouteNotifier.value = route.settings.name;
    _logRoute('push', route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    currentRouteNotifier.value = previousRoute?.settings.name;
    _logRoute('pop', route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    currentRouteNotifier.value = newRoute?.settings.name;
    _logRoute('replace', newRoute?.settings.name, oldRoute?.settings.name);
  }

  /// 路由日志（debug/profile 专用）
  // 新增功能：路由日志
  void _logRoute(String action, String? route, String? previous) {
    if (kReleaseMode) return;
    Log.i(
        'ROUTE',
        '$action → ${route ?? '(匿名路由)'}'
            '${previous != null ? ' (上一页: $previous)' : ''}');
  }
}
