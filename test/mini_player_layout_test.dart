// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/providers/auth_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/providers/theme_provider.dart';
import 'package:ngskg_plus/screens/player_screen.dart';
import 'package:ngskg_plus/ui/components/mini_player.dart';
import 'package:ngskg_plus/ui/components/player_bottom_padding.dart';
import 'package:ngskg_plus/ui/foundation/app_layout.dart';
import 'package:ngskg_plus/ui/shell/app_shell.dart';
import 'package:ngskg_plus/utils/navigation.dart' as app;
import 'package:provider/provider.dart';

const _song = Song(
  id: 1,
  name: '一首很长很长的歌曲名称',
  artists: ['一位名字很长的歌手'],
);
const _packageChannel = MethodChannel('dev.fluttercommunity.plus/package_info');

class _Player extends ChangeNotifier implements PlayerProvider {
  Song? song = _song;
  bool playing = true;
  bool loading = false;
  bool dismissed = false;
  bool playerVisible = false;
  int toggles = 0;
  int nextCalls = 0;
  int previousCalls = 0;
  final visibilityChanges = <bool>[];
  final progressNotifier = ValueNotifier<PlaybackProgress>((
    position: const Duration(seconds: 25),
    duration: const Duration(seconds: 100),
  ));

  @override
  Song? get currentSong => song;
  @override
  bool get isPlaying => playing;
  @override
  bool get isLoading => loading;
  @override
  bool get isMiniPlayerDismissed => dismissed;
  @override
  bool get isPlayerScreenVisible => playerVisible;
  @override
  ValueNotifier<PlaybackProgress> get playbackProgress => progressNotifier;

  @override
  Future<void> togglePlayPause() async {
    toggles++;
    playing = !playing;
    notifyListeners();
  }

  @override
  void playNext() => nextCalls++;
  @override
  void playPrevious() => previousCalls++;

  @override
  void dismissMiniPlayer() {
    dismissed = true;
    notifyListeners();
  }

  @override
  void showMiniPlayer() {
    dismissed = false;
    notifyListeners();
  }

  @override
  void setPlayerScreenVisible(bool visible) {
    playerVisible = visible;
    visibilityChanges.add(visible);
    notifyListeners();
  }

  void setLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    progressNotifier.dispose();
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoggedIn => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Theme extends ChangeNotifier implements ThemeProvider {
  @override
  bool get shouldShowSupportPopup => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

class _ContentPage extends StatelessWidget {
  final bool home;
  const _ContentPage({required this.home});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          key: ValueKey(home ? 'home-list' : 'detail-list'),
          children: [
            for (var index = 0; index < 18; index++)
              SizedBox(
                height: 64,
                child: Center(child: Text('内容 ${index + 1}')),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton(
                key: ValueKey(home ? 'home-last' : 'detail-last'),
                onPressed: () {},
                child: Text(home ? '首页末尾操作' : '详情末尾操作'),
              ),
            ),
            const PlayerBottomPadding(),
          ],
        ),
        bottomNavigationBar: home
            ? const SafeArea(
                top: false,
                child: SizedBox(
                  key: ValueKey('navigation'),
                  height: AppChrome.navigationExtent,
                  child: Center(child: Text('页面导航')),
                ),
              )
            : null,
      );
}

void _smallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<
    ({
      GlobalKey<NavigatorState> nav,
      _Routes routes,
      ValueNotifier<bool> ticker
    })> _mount(
  WidgetTester tester,
  _Player player, {
  bool shell = false,
  bool useGlobalNavigation = false,
  double textScale = 2,
  bool reduceMotion = false,
  ThemeData? theme,
}) async {
  _smallViewport(tester);
  final nav = useGlobalNavigation ? app.navKey : GlobalKey<NavigatorState>();
  final routes = _Routes();
  final ticker = ValueNotifier(true);
  final version = Completer<Map<String, dynamic>>();
  var requestedVersion = false;
  // 将启动更新隔离在平台接口处，播放栏布局验证不请求外部网络。
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _packageChannel,
    (_) {
      requestedVersion = true;
      return version.future;
    },
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    if (requestedVersion) {
      version.completeError(PlatformException(code: 'test_disposed'));
    }
    await tester.pump();
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageChannel, null);
    player.dispose();
    ticker.dispose();
  });
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<PlayerProvider>.value(value: player),
      ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => _Theme()),
    ],
    child: MaterialApp(
      theme: theme,
      navigatorKey: nav,
      navigatorObservers: [app.AppRouteObserver.instance, routes],
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: ticker,
        builder: (context, enabled, _) => TickerMode(
          enabled: enabled,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
              padding: const EdgeInsets.only(bottom: 24),
              viewPadding: const EdgeInsets.only(bottom: 24),
            ),
            child: shell ? AppShell(child: child) : child!,
          ),
        ),
      ),
      home: shell
          ? const _ContentPage(home: true)
          : const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: MiniPlayer(),
              ),
            ),
    ),
  ));
  await tester.pumpAndSettle();
  return (nav: nav, routes: routes, ticker: ticker);
}

Future<void> _scrollToEnd(WidgetTester tester, String listKey) async {
  final list = find.byKey(ValueKey(listKey));
  final scrollable = find.descendant(
    of: list,
    matching: find.byType(Scrollable),
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  // 懒布局在末尾组件首次出现后可能修正滚动范围，继续拖到实际边界。
  for (var attempt = 0; attempt < 5 && position.extentAfter > 0; attempt++) {
    await tester.drag(list, Offset(0, -position.extentAfter - 200));
    await tester.pumpAndSettle();
  }
  expect(position.extentAfter, 0);
}

void main() {
  testWidgets('播放栏操作有独立语义，紧凑主题下仍满足48像素触摸目标', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final player = _Player();
      await _mount(tester, player,
          textScale: 1,
          theme: ThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ));
      final open = tester.getSemantics(find.bySemanticsLabel('打开播放器'));
      final data = open.getSemanticsData();
      expect(data.value, '${_song.name} · ${_song.artistDisplay}');
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      expect(data.hasAction(ui.SemanticsAction.longPress), isTrue);
      for (final label in ['打开播放器', '暂停', '下一首']) {
        final node = tester.getSemantics(label == '打开播放器'
            ? find.bySemanticsLabel(label)
            : find.byTooltip(label));
        final data = node.getSemanticsData();
        expect(data.label == label || data.tooltip == label, isTrue);
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
        expect(node.rect.width, greaterThanOrEqualTo(48));
        expect(node.rect.height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.byTooltip('暂停'));
      await tester.pumpAndSettle();
      final playData =
          tester.getSemantics(find.byTooltip('播放')).getSemanticsData();
      expect(playData.label == '播放' || playData.tooltip == '播放', isTrue);
      expect(player.toggles, 1);
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('减少动态效果时加载状态仍可识别且不持续转动', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final player = _Player()..loading = true;
      await _mount(tester, player, reduceMotion: true);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getSemantics(find.byTooltip('暂停')).getSemanticsData().value,
          '正在加载');
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(find.byTooltip('暂停'));
      await tester.pumpAndSettle();
      expect(player.toggles, 1);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('加载指示在隐藏、离开前台和系统减少动态效果时停止动画', (tester) async {
    final player = _Player();
    final mounted = await _mount(tester, player);
    player.setLoading(true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    mounted.ticker.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    mounted.ticker.value = true;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final dispatcher = tester.binding.platformDispatcher;
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
    dispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    player.setLoading(false);
    await tester.pumpAndSettle();
  });

  testWidgets('冷启动已有歌曲时，外壳正确展示首页播放栏', (tester) async {
    app.AppRouteObserver.instance.currentRouteNotifier.value = null;
    await _mount(tester, _Player(), shell: true);
    expect(app.AppRouteObserver.instance.currentRouteNotifier.value, '/');
    expect(find.byTooltip('暂停').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 宽和两倍字体仍可控制播放，歌曲信息与进度正确更新', (tester) async {
    final player = _Player();
    await _mount(tester, player);
    expect(tester.takeException(), isNull);
    expect(find.text(_song.name), findsOneWidget);
    expect(find.text(_song.artistDisplay), findsOneWidget);
    expect(find.byTooltip('暂停').hitTestable(), findsOneWidget);
    expect(find.byTooltip('下一首').hitTestable(), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.25);

    await tester.tap(find.byTooltip('暂停'));
    await tester.pumpAndSettle();
    expect(player.toggles, 1);
    expect(find.byTooltip('播放').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('播放'));
    await tester.tap(find.byTooltip('下一首'));
    await tester.pumpAndSettle();
    expect(player.toggles, 2);
    expect(player.nextCalls, 1);
    expect(player.playerVisible, isFalse);

    player.progressNotifier.value = (
      position: const Duration(seconds: 75),
      duration: const Duration(seconds: 100),
    );
    await tester.pump();
    expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.75);
    player.setLoading(true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    player.setLoading(false);
    await tester.pumpAndSettle();
    expect(find.byTooltip('暂停'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击歌曲打开原播放器，再次请求打开不重复入栈，返回恢复显示', (tester) async {
    final player = _Player();
    final mounted = await _mount(tester, player, useGlobalNavigation: true);
    await tester.tap(find.text(_song.name));
    final route = mounted.routes.pushed.last;
    expect(route.settings.name, '/player');
    expect(player.playerVisible, isTrue);
    expect(route, isA<PageRouteBuilder<void>>());
    // 验证真实点击创建的目标页面；此测试不挂载完整播放器的音频/歌词依赖。
    final page = (route as PageRouteBuilder<void>).pageBuilder(
      tester.element(find.byType(MiniPlayer)),
      const AlwaysStoppedAnimation(1),
      const AlwaysStoppedAnimation(1),
    );
    expect(page, isA<PlayerScreen>());
    // 新路由已覆盖播放栏，直接调用公开入口验证其他调用方的重复请求。
    await PlayerScreen.open();
    expect(
        mounted.routes.pushed.where((item) => item.settings.name == '/player'),
        hasLength(1));
    mounted.nav.currentState!.removeRoute(route);
    await tester.pumpAndSettle();
    expect(player.visibilityChanges, [true, false]);
    expect(find.text(_song.name).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('左右滑动切歌后播放栏仍可使用', (tester) async {
    final player = _Player();
    await _mount(tester, player);
    await tester.drag(find.byType(Dismissible), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(player.nextCalls, 1);
    expect(find.byTooltip('暂停').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(Dismissible), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(player.previousCalls, 1);
    expect(player.dismissed, isFalse);
    expect(find.byTooltip('暂停').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('外壳中长按隐藏后可通过提示恢复，且不影响播放状态', (tester) async {
    final player = _Player();
    await _mount(tester, player, shell: true);
    final original = tester.getRect(find.byType(MiniPlayer));
    await tester.longPress(find.text(_song.name));
    await tester.pumpAndSettle();
    expect(player.dismissed, isTrue);
    expect(find.byType(MiniPlayer), findsNothing);
    expect(find.text('恢复').hitTestable(), findsOneWidget);
    expect(player.playing, isTrue);
    expect(player.toggles, 0);

    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(player.dismissed, isFalse);
    expect(find.byTooltip('暂停').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byType(MiniPlayer)), original);
    expect(player.playing, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页导航和二级页末尾操作均避开播放栏及系统安全区', (tester) async {
    final player = _Player();
    final mounted = await _mount(tester, player, shell: true);
    await _scrollToEnd(tester, 'home-list');
    final homeMini = tester.getRect(find.byType(MiniPlayer));
    final navigation = tester.getRect(find.byKey(const ValueKey('navigation')));
    final homeLast = find.byKey(const ValueKey('home-last'));
    expect(homeMini.bottom, lessThanOrEqualTo(navigation.top));
    expect(tester.getBottomLeft(homeLast).dy, lessThanOrEqualTo(homeMini.top));
    expect(homeLast.hitTestable(), findsOneWidget);

    mounted.nav.currentState!.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/detail'),
      builder: (_) => const _ContentPage(home: false),
    ));
    await tester.pumpAndSettle();
    await _scrollToEnd(tester, 'detail-list');
    final detailMini = tester.getRect(find.byType(MiniPlayer));
    final detailLast = find.byKey(const ValueKey('detail-last'));
    expect(detailMini.bottom, greaterThan(homeMini.bottom));
    expect(detailMini.bottom, lessThanOrEqualTo(760 - 24));
    expect(
        tester.getBottomLeft(detailLast).dy, lessThanOrEqualTo(detailMini.top));
    expect(detailLast.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('登录页和全屏播放器隐藏播放栏，返回原页面后重新显示', (tester) async {
    final player = _Player();
    final mounted = await _mount(tester, player, shell: true);
    for (final name in ['/login', '/player']) {
      mounted.nav.currentState!.push(MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => const Scaffold(body: Text('独立页面')),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayer), findsNothing);
      mounted.nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byTooltip('暂停').hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
