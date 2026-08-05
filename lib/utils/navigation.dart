import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

/// Global navigator key used across the app for showing dialogs, etc.
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// 跨页面搜索重启通道: 顶栏搜索框输入新词时通知已打开的搜索页重新搜索。
class SearchRestarter {
  static final ValueNotifier<String?> keyword = ValueNotifier<String?>(null);

  static void restart(String kw) => keyword.value = kw;
}

/// Observer to track the currently active route name, so layout elements (like MiniPlayer)
/// can adjust their position and safe areas dynamically.
class AppRouteObserver extends NavigatorObserver {
  static final AppRouteObserver instance = AppRouteObserver();

  final ValueNotifier<String?> currentRouteNotifier =
      ValueNotifier<String?>(null);

  final ValueNotifier<bool> canPopNotifier = ValueNotifier<bool>(false);

  final ValueNotifier<bool> canForwardNotifier = ValueNotifier<bool>(false);

  final List<Route<dynamic>> _routeStack = [];

  /// 已弹出路由的历史，用于桌面端“前进”按钮。
  final List<Route<dynamic>> _forwardStack = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _routeStack.add(route);
    // 发生新的 push 时清空 forward 栈
    _forwardStack.clear();
    // 无名路由(播放器等)不改变当前路由标记,避免侧边栏高亮丢失
    if (route.settings.name != null) {
      currentRouteNotifier.value = route.settings.name;
    }
    _updateNotifiers();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _routeStack.remove(route);
    // 只有命名路由才支持“前进”恢复 (播放器/对话框等无名路由无法按名重建)
    if (route.settings.name != null) {
      _forwardStack.add(route);
    }
    // 初始首页路由没有 name,回退到首页标记,避免侧边栏高亮丢失
    currentRouteNotifier.value = previousRoute?.settings.name ?? AppRoutes.home;
    _updateNotifiers();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _routeStack.remove(route);
    _forwardStack.remove(route);
    _updateNotifiers();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      _routeStack.remove(oldRoute);
      _forwardStack.remove(oldRoute);
    }
    if (newRoute != null) {
      _routeStack.add(newRoute);
      _forwardStack.clear();
      currentRouteNotifier.value = newRoute.settings.name;
    }
    _updateNotifiers();
  }

  void _updateNotifiers() {
    // 直接查询真实 Navigator 状态，避免自维护栈与初始路由不同步
    canPopNotifier.value = navKey.currentState?.canPop() ?? false;
    canForwardNotifier.value = _forwardStack.isNotEmpty;
  }

  /// 桌面端前进：重新 push 最近 pop 掉的路由。
  /// 注意：这里只恢复路由名，参数需要调用方重新构造。
  void forward() {
    if (_forwardStack.isEmpty) return;
    // 跳过无法按名恢复的无名路由（播放器/对话框等）
    while (_forwardStack.isNotEmpty) {
      final r = _forwardStack.last;
      if (r.settings.name != null) break;
      _forwardStack.removeLast();
    }
    if (_forwardStack.isEmpty) return;
    final route = _forwardStack.removeLast();
    navKey.currentState
        ?.pushNamed(route.settings.name!, arguments: route.settings.arguments);
  }

  /// 切换侧边栏顶层栏目时，清空 forward 栈，避免跨层级前进。
  void clearForward() {
    _forwardStack.clear();
    _updateNotifiers();
  }
}
