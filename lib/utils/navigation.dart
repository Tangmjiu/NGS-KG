// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;

/// 供通知操作、弹窗及组件树外的导航使用。
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// 跟踪实际页面，弹窗等覆盖层不会改变外壳的页面布局。
class AppRouteObserver extends NavigatorObserver {
  static final AppRouteObserver instance = AppRouteObserver();
  static const unnamedPageRouteName = '/_unnamed_page';

  final ValueNotifier<String?> currentRouteNotifier = ValueNotifier(null);
  final List<Route<dynamic>> _routes = [];
  Route<dynamic>? _rootRoute;
  bool _publishScheduled = false;

  void _publishPage() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (!_publishScheduled) {
        _publishScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _publishScheduled = false;
          _publishPage();
        });
      }
      return;
    }
    PageRoute<dynamic>? page;
    for (final route in _routes.reversed) {
      if (route is PageRoute<dynamic>) {
        page = route;
        break;
      }
    }
    final name = page?.settings.name;
    currentRouteNotifier.value = page == null
        ? null
        : name != null && name.isNotEmpty
            ? name
            : identical(page, _rootRoute)
                ? '/'
                : unnamedPageRouteName;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // 同一 observer 重新连接 Navigator 时，清理上一导航栈的身份。
    if (previousRoute == null) {
      _routes.clear();
      _rootRoute = route;
    }
    _routes.add(route);
    _publishPage();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _routes.remove(route);
    if (identical(route, _rootRoute)) _rootRoute = null;
    _publishPage();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) _routes.removeAt(index);
    if (newRoute != null) {
      _routes.insert(index < 0 ? _routes.length : index, newRoute);
    }
    if (identical(oldRoute, _rootRoute)) _rootRoute = newRoute;
    _publishPage();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _routes.remove(route);
    if (identical(route, _rootRoute)) _rootRoute = null;
    _publishPage();
  }
}
