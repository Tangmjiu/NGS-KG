// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/ui/foundation/app_motion.dart';
import 'package:ngskg_plus/ui/foundation/app_motion_theme.dart';
import 'package:ngskg_plus/ui/foundation/app_spring.dart';

const _movingItem = ValueKey('moving-item');
const _pressItem = ValueKey('press-item');

typedef _MotionState = ({double target, bool reduced, bool ticker});

class _SpringHarness {
  final state = ValueNotifier<_MotionState>(
    (target: 0, reduced: false, ticker: true),
  );

  void update({double? target, bool? reduced, bool? ticker}) {
    state.value = (
      target: target ?? state.value.target,
      reduced: reduced ?? state.value.reduced,
      ticker: ticker ?? state.value.ticker,
    );
  }

  Widget get app => MaterialApp(
        theme: ThemeData(extensions: const [AppMotionTheme(durationScale: 2)]),
        home: Scaffold(
          body: ValueListenableBuilder<_MotionState>(
            valueListenable: state,
            builder: (context, value, _) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: value.reduced),
              child: TickerMode(
                enabled: value.ticker,
                child: AppSpring(
                  value: value.target,
                  builder: (_, position, child) => Transform.translate(
                    offset: Offset(position, 0),
                    child: child,
                  ),
                  child: const SizedBox(
                    key: _movingItem,
                    width: 40,
                    height: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

double _position(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(_movingItem)).dx;

double _pressScale(WidgetTester tester) => tester
    .widget<Transform>(find
        .descendant(
          of: find.byType(PressScale),
          matching: find.byType(Transform),
        )
        .first)
    .transform
    .storage[0];

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets('弹簧快速反向时延续当前位置和惯性，最终回到新目标', (tester) async {
    final harness = _SpringHarness();
    addTearDown(harness.state.dispose);
    await tester.pumpWidget(harness.app);
    expect(_position(tester), 0);
    harness.update(target: 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final beforeReverse = _position(tester);
    expect(beforeReverse, inExclusiveRange(0, 100));

    harness.update(target: 0);
    await tester.pump();
    expect(_position(tester), closeTo(beforeReverse, 0.0001));
    // 极短一帧内应保留前进惯性，不能重新从旧起点启动倒放。
    await tester.pump(const Duration(milliseconds: 1));
    expect(_position(tester), greaterThan(beforeReverse));
    await tester.pumpAndSettle();
    expect(_position(tester), closeTo(0, 0.001));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态效果和隐藏页面均使弹簧直接停在最新目标', (tester) async {
    final harness = _SpringHarness();
    addTearDown(harness.state.dispose);
    await tester.pumpWidget(harness.app);
    harness.update(target: 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(_position(tester), inExclusiveRange(0, 100));

    harness.update(reduced: true);
    await tester.pumpAndSettle();
    expect(_position(tester), 100);
    harness.update(target: 40);
    await tester.pumpAndSettle();
    expect(_position(tester), 40);
    expect(tester.binding.transientCallbackCount, 0);

    harness.update(reduced: false);
    await tester.pump();
    harness.update(target: 80);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_position(tester), inExclusiveRange(40, 80));
    harness.update(ticker: false);
    await tester.pumpAndSettle();
    expect(_position(tester), 80);
    harness.update(target: 120);
    await tester.pumpAndSettle();
    expect(_position(tester), 120);
    expect(tester.binding.transientCallbackCount, 0);
    harness.update(ticker: true);
    await tester.pumpAndSettle();
    expect(_position(tester), 120);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('按压反馈保留子按钮点击，拖动和取消后回位且不误触', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            PressScale(
              child: InkWell(
                key: _pressItem,
                onTap: () => taps++,
                child: const SizedBox(
                  height: 160,
                  child: Center(child: Text('可点击歌曲')),
                ),
              ),
            ),
            const SizedBox(height: 1600),
          ],
        ),
      ),
    ));
    final tap =
        await tester.startGesture(tester.getCenter(find.byKey(_pressItem)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(_pressScale(tester), lessThan(1));
    await tap.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(_pressScale(tester), closeTo(1, 0.001));

    final drag =
        await tester.startGesture(tester.getCenter(find.byKey(_pressItem)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(_pressScale(tester), lessThan(1));
    await drag.moveBy(const Offset(0, -60));
    await drag.moveBy(const Offset(0, -20));
    await tester.pumpAndSettle();
    expect(_pressScale(tester), closeTo(1, 0.001));
    await drag.up();
    await tester.pumpAndSettle();
    expect(taps, 1);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, greaterThan(0));
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    final cancelled =
        await tester.startGesture(tester.getCenter(find.byKey(_pressItem)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(_pressScale(tester), lessThan(1));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(_pressScale(tester), closeTo(1, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('错峰入场等待期间销毁组件会取消计时器', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StaggeredEntrance(
          index: 1,
          itemDelay: Duration(seconds: 2),
          child: Text('等待入场'),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
    // 保留尚未到达的两秒期限，由测试框架检查组件卸载后无遗留 Timer。
  });

  testWidgets('错峰等待期间开启减少动态效果会立即显示并取消延迟', (tester) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: reduced,
          builder: (context, value, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: value),
            child: const StaggeredEntrance(
              index: 1,
              itemDelay: Duration(seconds: 2),
              child: Text('已显示的操作'),
            ),
          ),
        ),
      ),
    ));
    reduced.value = true;
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        1);
    expect(find.text('已显示的操作').hitTestable(), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动效弹窗使用自身路由上下文，关闭时只弹出局部弹窗', (tester) async {
    final nestedKey = GlobalKey<NavigatorState>();
    final rootRoutes = _Routes();
    final nestedRoutes = _Routes();
    ModalRoute<dynamic>? dialogRoute;
    ModalRoute<dynamic>? pageRoute;
    String? result;
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [rootRoutes],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Navigator(
        key: nestedKey,
        observers: [nestedRoutes],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/nested'),
          builder: (pageContext) => Scaffold(
            body: TextButton(
              onPressed: () async {
                pageRoute = ModalRoute.of(pageContext);
                result = await showAppDialog<String>(
                  context: pageContext,
                  routeSettings: const RouteSettings(name: '/dialog'),
                  builder: (dialogContext) {
                    dialogRoute = ModalRoute.of(dialogContext);
                    return AlertDialog(
                      title: const Text('确认操作'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop('确认'),
                          child: const Text('完成'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('打开弹窗'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final initialRootCount = rootRoutes.pushed.length;
    await tester.tap(find.text('打开弹窗'));
    await tester.pump();
    expect(dialogRoute, isNot(same(pageRoute)));
    expect(dialogRoute, same(nestedRoutes.pushed.last));
    expect(dialogRoute!.settings.name, '/dialog');
    expect(dialogRoute!.transitionDuration, Duration.zero);
    expect(dialogRoute!.reverseTransitionDuration, Duration.zero);
    expect(rootRoutes.pushed, hasLength(initialRootCount));
    expect(find.text('完成').hitTestable(), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result, '确认');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('打开弹窗').hitTestable(), findsOneWidget);
    expect(nestedKey.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
