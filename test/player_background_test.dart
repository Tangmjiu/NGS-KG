// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/providers/theme_provider.dart';
import 'package:ngskg_plus/theme/theme_assets.dart';
import 'package:ngskg_plus/widgets/player_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _coverUrl = 'https://imge.kugou.com/stdmusic/480/test-cover.png';
const _backgroundKey = ValueKey('player-background-snapshot');

class _Player extends ChangeNotifier implements PlayerProvider {
  bool _playing = true;

  @override
  bool get isPlaying => _playing;

  void setPlaying(bool playing) {
    _playing = playing;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BuildCounter extends StatelessWidget {
  final VoidCallback onBuild;
  final Widget child;

  const _BuildCounter({required this.onBuild, required this.child});

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}

class _Harness {
  final String? coverUrl;
  _Harness({this.coverUrl = _coverUrl});

  final player = _Player();
  final theme = ThemeProvider();
  final tickerEnabled = ValueNotifier(true);
  final reduceMotion = ValueNotifier(false);
  int parentBuilds = 0;

  Widget get app => MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayerProvider>.value(value: player),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ],
        child: MaterialApp(
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: reduceMotion,
            child: child,
            builder: (context, reduced, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
          ),
          home: ValueListenableBuilder<bool>(
            valueListenable: tickerEnabled,
            child: _BuildCounter(
              onBuild: () => parentBuilds++,
              child: RepaintBoundary(
                key: _backgroundKey,
                child: PlayerBackground(
                  albumCoverUrl: coverUrl,
                  paletteColor: Colors.blue,
                  // 在线取色尚未完成时也应该能显示流光。
                  paletteColors: [],
                  scrollOffset: 0,
                ),
              ),
            ),
            builder: (context, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
          ),
        ),
      );

  void dispose() {
    tickerEnabled.dispose();
    reduceMotion.dispose();
    theme.dispose();
    player.dispose();
  }
}

// 使用真实 PNG 解码填充在线封面的内存缓存，让 CachedNetworkImage 完整走
// ImageStream 和 imageBuilder 的加载链路，不访问酷狗服务或手工调用 builder。
Future<void> _cacheOnlineCover() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 384, 192),
    Paint()..color = Colors.blue,
  );
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 192, 96),
    Paint()..color = Colors.red,
  );
  canvas.drawRect(
    const Rect.fromLTWH(192, 96, 192, 96),
    Paint()..color = Colors.green,
  );
  final picture = recorder.endRecording();
  final source = await picture.toImage(384, 192);
  final png = await source.toByteData(format: ui.ImageByteFormat.png);
  source.dispose();
  picture.dispose();
  const online = CachedNetworkImageProvider(_coverUrl);
  final providers = <(ImageProvider, int?, int?)>[
    (online, null, null),
    (ResizeImage.resizeIfNeeded(96, 96, online), 96, 96),
    (
      const ResizeImage(
        online,
        width: 96,
        height: 96,
        policy: ResizeImagePolicy.fit,
      ),
      96,
      48,
    ),
  ];
  for (final (provider, width, height) in providers) {
    final codec = await ui.instantiateImageCodec(
      png!.buffer.asUint8List(),
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    try {
      final key = await provider.obtainKey(ImageConfiguration.empty);
      final completer = OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: frame.image.clone())),
      );
      PaintingBinding.instance.imageCache.putIfAbsent(key, () => completer);
      final loaded = Completer<void>();
      final listener = ImageStreamListener((info, _) {
        info.dispose();
        loaded.complete();
      });
      completer.addListener(listener);
      await loaded.future;
      completer.removeListener(listener);
    } finally {
      frame.image.dispose();
    }
  }
}

Future<_Harness> _mount(
  WidgetTester tester, {
  bool flowEnabled = true,
  String? coverUrl = _coverUrl,
  bool reduceMotion = false,
}) async {
  await tester.runAsync(_cacheOnlineCover);
  final harness = _Harness(coverUrl: coverUrl);
  harness.reduceMotion.value = reduceMotion;
  await harness.theme.setFlowLightEnabled(flowEnabled);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    harness.dispose();
  });
  await tester.pumpWidget(harness.app);
  await tester.pump();
  return harness;
}

Future<void> _advanceFrames(WidgetTester tester, {int count = 10}) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<Uint8List> _backgroundPixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_backgroundKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 0.25);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }))!;
}

double _elapsed(WidgetTester tester) => tester
    .widget<FlowingImageLayer>(find.byType(FlowingImageLayer).first)
    .elapsed;

void _expectIdle(WidgetTester tester) {
  expect(tester.binding.transientCallbackCount, 0);
  expect(tester.binding.hasScheduledFrame, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String savedThemeBackground;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    savedThemeBackground = ThemeAssets.playerBg;
    ThemeAssets.playerBg = '';
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    ThemeAssets.playerBg = savedThemeBackground;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('在线封面解码后无需等待取色即可显示运动的流光', (tester) async {
    final harness = await _mount(tester);
    expect(find.byType(FlowingImageLayer), findsNWidgets(2));
    final images = tester.widgetList<RawImage>(
      find.descendant(
        of: find.byType(FlowingImageLayer),
        matching: find.byType(RawImage),
      ),
    );
    expect(images, hasLength(2));
    expect(images.every((image) => image.image != null), isTrue);
    for (final image in images) {
      expect(image.image!.width, lessThanOrEqualTo(96));
      expect(image.image!.height, lessThanOrEqualTo(96));
      expect(image.image!.width, image.image!.height * 2);
    }

    // 先结束图片加载的淡入，避免把一次性淡入误判为持续流光运动。
    await _advanceFrames(tester, count: 60);
    final initialElapsed = _elapsed(tester);
    final transformFinder = find.descendant(
      of: find.byType(FlowingImageLayer).first,
      matching: find.byType(Transform),
    );
    final initialTransform = List<double>.of(
      tester.widget<Transform>(transformFinder).transform.storage,
    );
    final initialPixels = await _backgroundPixels(tester);
    expect(initialPixels, isNotEmpty);
    expect(initialPixels.any((channel) => channel != 0), isTrue);

    await _advanceFrames(tester, count: 120);
    expect(_elapsed(tester), greaterThan(initialElapsed));
    expect(
      tester.widget<Transform>(transformFinder).transform.storage,
      isNot(orderedEquals(initialTransform)),
    );
    final animatedPixels = await _backgroundPixels(tester);
    expect(animatedPixels, hasLength(initialPixels.length));
    var changedPixels = 0;
    for (var index = 0; index < initialPixels.length; index += 4) {
      if (initialPixels[index] != animatedPixels[index] ||
          initialPixels[index + 1] != animatedPixels[index + 1] ||
          initialPixels[index + 2] != animatedPixels[index + 2]) {
        changedPixels++;
      }
    }
    // 验证最终合成画面确实变化，防止计时器/矩阵已更新而流光仍未绘制。
    expect(changedPixels, greaterThan(0));
    expect(harness.parentBuilds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('开关流光即时生效，关闭后停止空转，再开启恢复', (tester) async {
    final harness = await _mount(tester, flowEnabled: false);
    await tester.pumpAndSettle();
    expect(find.byType(FlowingImageLayer), findsNothing);
    _expectIdle(tester);

    await harness.theme.setFlowLightEnabled(true);
    await tester.pump();
    expect(find.byType(FlowingImageLayer), findsNWidgets(2));
    await _advanceFrames(tester);
    final beforeDisable = _elapsed(tester);
    expect(beforeDisable, greaterThan(0));

    await harness.theme.setFlowLightEnabled(false);
    await tester.pumpAndSettle();
    expect(find.byType(FlowingImageLayer), findsNothing);
    _expectIdle(tester);

    await harness.theme.setFlowLightEnabled(true);
    await tester.pump();
    expect(find.byType(FlowingImageLayer), findsNWidgets(2));
    await _advanceFrames(tester);
    expect(_elapsed(tester), greaterThan(beforeDisable));
    expect(harness.parentBuilds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('播放暂停会缓停，仅靠播放状态通知即可恢复流光', (tester) async {
    final harness = await _mount(tester);
    await _advanceFrames(tester);
    harness.player.setPlaying(false);
    await tester.pump();
    final beforeCoast = _elapsed(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_elapsed(tester), greaterThan(beforeCoast));

    // 逐帧运行缓停过程，避免一次大步进跳过缓停而掩盖空转问题。
    await _advanceFrames(tester, count: 220);
    _expectIdle(tester);
    final stopped = _elapsed(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(_elapsed(tester), stopped);

    harness.player.setPlaying(true);
    await tester.pump();
    await _advanceFrames(tester);
    expect(_elapsed(tester), greaterThan(stopped));
    expect(harness.parentBuilds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TickerMode 静音后返回时流光时钟不跳跃', (tester) async {
    final harness = await _mount(tester);
    await _advanceFrames(tester);
    harness.tickerEnabled.value = false;
    await tester.pump();
    final beforeHidden = _elapsed(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(_elapsed(tester), beforeHidden);
    _expectIdle(tester);

    harness.tickerEnabled.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final afterReturn = _elapsed(tester);
    expect(afterReturn, greaterThanOrEqualTo(beforeHidden));
    expect(afterReturn - beforeHidden, lessThan(0.2));
    await _advanceFrames(tester);
    expect(_elapsed(tester), greaterThan(afterReturn));
    expect(harness.parentBuilds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态效果保留静态流光，关闭后沿当前画面继续', (tester) async {
    final harness = await _mount(tester, reduceMotion: true);
    await tester.pumpAndSettle();
    expect(find.byType(FlowingImageLayer), findsNWidgets(2));
    final initial = _elapsed(tester);
    await tester.pump(const Duration(minutes: 1));
    expect(_elapsed(tester), initial);
    _expectIdle(tester);

    harness.reduceMotion.value = false;
    await tester.pump();
    await _advanceFrames(tester);
    expect(_elapsed(tester), greaterThan(initial));
    harness.reduceMotion.value = true;
    await tester.pumpAndSettle();
    final stopped = _elapsed(tester);
    await tester.pump(const Duration(minutes: 1));
    expect(_elapsed(tester), stopped);
    _expectIdle(tester);
  });

  testWidgets('系统辅助功能改变时立即静止流光，不依赖播放状态通知', (tester) async {
    await _mount(tester);
    await _advanceFrames(tester);
    final dispatcher = tester.binding.platformDispatcher;
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
    dispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpAndSettle();
    final stopped = _elapsed(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(_elapsed(tester), stopped);
    _expectIdle(tester);

    dispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    await tester.pump();
    await _advanceFrames(tester);
    expect(_elapsed(tester), greaterThan(stopped));
  });

  testWidgets('应用失去前台时立即停帧，暂停期间返回不会重启流光', (tester) async {
    final harness = await _mount(tester);
    await _advanceFrames(tester, count: 60);
    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    final stopped = _elapsed(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(_elapsed(tester), stopped);
    _expectIdle(tester);

    harness.player.setPlaying(false);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_elapsed(tester), stopped);
    _expectIdle(tester);
    harness.player.setPlaying(true);
    await tester.pump();
    await _advanceFrames(tester);
    expect(_elapsed(tester), greaterThan(stopped));
    expect(_elapsed(tester) - stopped, lessThan(0.3));
  });

  testWidgets('没有封面和主题背景时不创建持续动画帧', (tester) async {
    await _mount(tester, coverUrl: null);
    await tester.pumpAndSettle();
    expect(find.byType(FlowingImageLayer), findsNothing);
    _expectIdle(tester);
    await tester.pump(const Duration(minutes: 1));
    _expectIdle(tester);
  });
}
