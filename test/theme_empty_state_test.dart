// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/theme_pack.dart';
import 'package:ngskg_plus/providers/theme_provider.dart';
import 'package:ngskg_plus/theme/app_theme.dart';
import 'package:ngskg_plus/theme/theme_assets.dart';
import 'package:ngskg_plus/ui/app_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ThemeProvider, Directory)> _legacyTheme(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 420);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final directory = (await tester.runAsync(() async {
    final root = await Directory.systemTemp.createTemp('theme-empty-state-');
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 40, 24),
      Paint()..color = const Color(0xFF336699),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(40, 24);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      for (final filename in ['content', 'collection', 'error']) {
        await File('${root.path}/$filename.png')
            .writeAsBytes(png!.buffer.asUint8List());
      }
    } finally {
      image.dispose();
      picture.dispose();
    }
    return root;
  }))!;
  final theme = ThemeProvider();
  await theme.init();
  theme.addMarketPack(ThemePack(
    id: 'legacy_art',
    name: '旧主题插画',
    author: '作者',
    assetFiles: {
      'empty_content': '${directory.path}/content.png',
      'empty_playlist': '${directory.path}/collection.png',
      'load_failed': '${directory.path}/error.png',
    },
  ));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    theme.dispose();
    ThemeAssets.resetToDefault();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
  return (theme, directory);
}

Widget _app(ThemeProvider provider, Widget child) =>
    ChangeNotifierProvider<ThemeProvider>.value(
      value: provider,
      child: MaterialApp(
        // 固定配色，确保仅资源变更时也能刷新已经存在的空状态。
        theme: AppTheme.build(ngsNagisa.lightScheme!, ngsNagisa),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );

Future<void> _precacheIllustration(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final source = ResizeImage(themeImageProvider(path),
        width: 160, height: 160, policy: ResizeImagePolicy.fit);
    final stream = source.resolve(ImageConfiguration.empty);
    final loaded = Completer<void>();
    final listener = ImageStreamListener((image, _) {
      image.dispose();
      if (!loaded.isCompleted) loaded.complete();
    }, onError: (Object error, StackTrace? stack) {
      if (!loaded.isCompleted) loaded.completeError(error, stack);
    });
    stream.addListener(listener);
    try {
      await loaded.future.timeout(const Duration(seconds: 10));
    } finally {
      stream.removeListener(listener);
    }
  });
}

void _expectDecodedIllustration(WidgetTester tester, String path) {
  expect(tester.widget<ThemeImage>(find.byType(ThemeImage)).assetPath, path);
  expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeAssets.resetToDefault();
  });

  testWidgets('旧主题通用和歌单插画实际显示，小屏大字可滚动且切回 MD3 恢复图标', (tester) async {
    final (theme, directory) = await _legacyTheme(tester);
    for (final state in [
      (Icons.search_off_rounded, 'content'),
      (Icons.queue_music_rounded, 'collection'),
    ]) {
      var tapped = false;
      await theme.selectPack('legacy_art');
      await _precacheIllustration(tester, '${directory.path}/${state.$2}.png');
      await tester.pumpWidget(_app(
        theme,
        AppEmptyState(
          icon: state.$1,
          title: '这里还没有收藏的音乐',
          message: '找到喜欢的音乐后，可以添加到这里，随时继续收听。',
          action: FilledButton(
            onPressed: () => tapped = true,
            child: const Text('发现音乐'),
          ),
        ),
      ));
      _expectDecodedIllustration(tester, '${directory.path}/${state.$2}.png');
      expect(find.byIcon(state.$1), findsNothing);
      expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .maxScrollExtent,
          greaterThan(0));
      await tester.ensureVisible(find.text('发现音乐'));
      await tester.tap(find.text('发现音乐'));
      expect(tapped, true);

      await theme.selectPack('md3_default');
      await tester.pump();

      expect(find.byType(ThemeImage), findsNothing);
      expect(find.byIcon(state.$1), findsOneWidget);
      expect(find.text('这里还没有收藏的音乐'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('旧主题错误插画兼容默认推断和显式状态，重试按钮仍可操作', (tester) async {
    final (theme, directory) = await _legacyTheme(tester);
    for (final kind in [null, AppEmptyStateKind.error]) {
      final icon = kind == null ? Icons.cloud_off_rounded : Icons.radio_rounded;
      var retried = false;
      await theme.selectPack('legacy_art');
      await _precacheIllustration(tester, '${directory.path}/error.png');
      await tester.pumpWidget(_app(
        theme,
        AppEmptyState(
          kind: kind,
          icon: icon,
          title: '音乐暂时无法加载',
          message: '请检查网络连接后重新尝试，或者稍后再来收听喜欢的音乐。',
          action: FilledButton(
            onPressed: () => retried = true,
            child: const Text('重新加载'),
          ),
        ),
      ));
      _expectDecodedIllustration(tester, '${directory.path}/error.png');
      expect(find.byIcon(icon), findsNothing);
      expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .maxScrollExtent,
          greaterThan(0));
      await tester.ensureVisible(find.text('重新加载'));
      await tester.tap(find.text('重新加载'));
      expect(retried, true);

      await theme.selectPack('md3_default');
      await tester.pump();

      expect(find.byType(ThemeImage), findsNothing);
      expect(find.byIcon(icon), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
