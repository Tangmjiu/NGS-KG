// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/utils/navigation.dart';

PageRoute<void> _page(String text, {String? name}) => MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => Scaffold(body: Center(child: Text(text))),
    );

Future<
    ({
      GlobalKey<NavigatorState> key,
      AppRouteObserver observer,
      PageRoute<void> root
    })> _mount(WidgetTester tester) async {
  final key = GlobalKey<NavigatorState>();
  final observer = AppRouteObserver();
  final root = _page('首页');
  await tester.pumpWidget(MaterialApp(
      home: Navigator(
    key: key,
    observers: [observer],
    onGenerateInitialRoutes: (_, __) => [root],
    onGenerateRoute: (_) => _page('后备页'),
  )));
  await tester.pumpAndSettle();
  return (key: key, observer: observer, root: root);
}

void main() {
  testWidgets('未命名根页为首页，二级页和弹窗保持正确页面身份', (tester) async {
    final app = await _mount(tester);
    expect(app.root.settings.name, isNull);
    expect(app.observer.currentRouteNotifier.value, '/');

    app.key.currentState!.push(_page('二级页'));
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value,
        AppRouteObserver.unnamedPageRouteName);

    showDialog<void>(
      context: tester.element(find.text('二级页')),
      useRootNavigator: false,
      builder: (_) => const AlertDialog(title: Text('二级页弹窗')),
    );
    await tester.pumpAndSettle();
    expect(find.text('二级页弹窗'), findsOneWidget);
    expect(app.observer.currentRouteNotifier.value,
        AppRouteObserver.unnamedPageRouteName);
    app.key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value,
        AppRouteObserver.unnamedPageRouteName);
    app.key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value, '/');
  });

  testWidgets('播放器上的弹窗不会让外壳误显示迷你播放器', (tester) async {
    final app = await _mount(tester);
    app.key.currentState!.push(_page('播放器', name: '/player'));
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value, '/player');
    final changes = <String?>[];
    app.observer.currentRouteNotifier.addListener(
        () => changes.add(app.observer.currentRouteNotifier.value));
    showModalBottomSheet<void>(
      context: tester.element(find.text('播放器')),
      builder: (_) => const SizedBox(height: 120, child: Text('歌词设置')),
    );
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value, '/player');
    app.key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value, '/player');
    expect(changes, isEmpty);
    app.key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value, '/');
  });

  testWidgets('替换栈内页面和移除非顶层页面不会误改当前页面', (tester) async {
    final app = await _mount(tester);
    final lower = _page('中间页', name: '/middle');
    final top = _page('当前页');
    app.key.currentState!.push(lower);
    await tester.pumpAndSettle();
    app.key.currentState!.push(top);
    await tester.pumpAndSettle();
    final replacement = _page('替换后的中间页', name: '/replacement');
    app.key.currentState!.replace(oldRoute: lower, newRoute: replacement);
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value,
        AppRouteObserver.unnamedPageRouteName);
    app.key.currentState!.removeRoute(replacement);
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value,
        AppRouteObserver.unnamedPageRouteName);
    app.key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value, '/');
  });

  testWidgets('替换当前页面与移除当前页面正确回到下层页面', (tester) async {
    final app = await _mount(tester);
    app.key.currentState!.push(_page('旧详情'));
    await tester.pumpAndSettle();
    final player = _page('替换的播放器', name: '/player');
    app.key.currentState!.pushReplacement(player);
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value, '/player');
    app.key.currentState!.removeRoute(player);
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value, '/');
  });

  testWidgets('移除根路由后未命名二级页仍不被识别为首页', (tester) async {
    final app = await _mount(tester);
    app.key.currentState!.push(_page('剩余详情页'));
    await tester.pumpAndSettle();
    app.key.currentState!.removeRoute(app.root);
    await tester.pumpAndSettle();
    expect(app.observer.currentRouteNotifier.value,
        AppRouteObserver.unnamedPageRouteName);
  });
}
