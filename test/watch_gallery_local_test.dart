// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Run normally to exercise routes without writing images. On a local host:
// WATCH_SCREENSHOTS=/your/local/gallery flutter test test/watch_gallery_local_test.dart
// Output is grouped by logical diameter. Only production Flutter layers are
// captured. The native keyboard, Bluetooth picker, sensors and accounts are
// represented by local inputs, never invoked or drawn into the gallery.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/utils/navigation.dart';
import 'package:ngskg_plus/watch/app.dart';
import 'package:ngskg_plus/watch/screens/audio_output_screen.dart';
import 'package:ngskg_plus/watch/screens/fm_screen.dart';
import 'package:ngskg_plus/watch/screens/hubs.dart';
import 'package:ngskg_plus/watch/screens/liked_songs_screen.dart';
import 'package:ngskg_plus/watch/screens/local_music_screen.dart';
import 'package:ngskg_plus/watch/screens/log_export_screen.dart';
import 'package:ngskg_plus/watch/screens/login_screen.dart';
import 'package:ngskg_plus/watch/screens/onboarding_screen.dart';
import 'package:ngskg_plus/watch/screens/player_screen.dart';
import 'package:ngskg_plus/watch/screens/playlist_list_screen.dart';
import 'package:ngskg_plus/watch/screens/queue_screen.dart';
import 'package:ngskg_plus/watch/screens/rank_list_screen.dart';
import 'package:ngskg_plus/watch/screens/search_screen.dart';
import 'package:ngskg_plus/watch/screens/settings_screen.dart';
import 'package:ngskg_plus/watch/theme/watch_theme.dart';
import 'package:ngskg_plus/watch/theme/watch_theme_provider.dart';
import 'package:ngskg_plus/watch/widgets/mini_player.dart';
import 'package:ngskg_plus/watch/widgets/watch_quick_panel.dart';
import 'package:ngskg_plus/watch/widgets/watch_transport_face.dart';
import 'package:package_info_plus/package_info_plus.dart';
// path_provider's documented test seam, available through path_provider.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wear_plus/wear_plus.dart';

import 'support/watch_gallery_fixtures.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.directory);
  final Directory directory;
  @override
  Future<String> getApplicationDocumentsPath() async => directory.path;
}

class _Gallery {
  _Gallery(this.tester, this.side);
  final WidgetTester tester;
  final double side;
  final data = GalleryFixtures();
  final boundary = GlobalKey();
  bool ambient = false;

  void channel(String name, Future<dynamic> Function(MethodCall call) handler) {
    final channel = MethodChannel(name);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  void configure() {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size.square(side);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    channel(
      'wear',
      (call) async => switch (call.method) {
        'getShape' => 'round',
        'isAmbient' => ambient,
        _ => null,
      },
    );
    channel('flutter.wearable_rotary.channel', (_) async => null);
  }

  Future<void> open(Widget page) async {
    // Remove both global keys before starting the next route stack. Otherwise
    // Navigator reparents its previous overlay, including any pushed detail.
    if (boundary.currentContext != null) {
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.pumpWidget(
      data.wrap(
        MaterialApp(
          key: UniqueKey(),
          navigatorKey: navKey,
          debugShowCheckedModeBanner: false,
          theme: buildWatchTheme(WatchThemeProvider().colorSeed),
          builder: (_, child) => WatchShape(
            builder: (_, _, _) => RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: Colors.black,
                child: ClipOval(child: child),
              ),
            ),
          ),
          home: page,
        ),
      ),
    );
    await frames();
  }

  // Crown illustration, mini-player, spinners and text cursors can animate
  // indefinitely. Drive a finite transition instead of pumpAndSettle().
  Future<void> frames() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
  }

  Future<void> tap(Finder target) async {
    if (target.hitTestable().evaluate().isEmpty) {
      await tester.ensureVisible(target);
      await frames();
    }
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target.hitTestable());
    await frames();
  }

  Future<void> shot(String name, Finder content) async {
    expect(content, findsWidgets, reason: name);
    expect(tester.takeException(), isNull, reason: name);
    final root = Platform.environment['WATCH_SCREENSHOTS'];
    if (root == null || root.trim().isEmpty) return;
    await tester.pump();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 3);
      try {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final dir = await Directory(
          '$root/${side.toInt()}dp',
        ).create(recursive: true);
        await File('${dir.path}/$name.png').writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        image.dispose();
      }
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Android supplies the default typeface and CJK fallback on a watch. Use
    // the app's full bundled family in the headless shell, including weights.
    for (final family in ['Roboto', 'HarmonyOS Sans']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'Bold', 'Light']) {
        loader.addFont(
          rootBundle.load('assets/fonts/HarmonyOS_Sans_$weight.ttf'),
        );
      }
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final side in [192.0, 225.0]) {
    void scenario(String label, Future<void> Function(_Gallery) body) {
      testWidgets('${side.toInt()}dp · $label', (tester) async {
        final gallery = _Gallery(tester, side)..configure();
        try {
          await body(gallery);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          // Allow a pending QR poll to observe unmount and terminate.
          await tester.pump(const Duration(seconds: 3));
          gallery.data.dispose();
        }
      });
    }

    scenario('首次引导', (g) async {
      var finished = false;
      await g.open(WatchOnboardingScreen(onDone: () => finished = true));
      await g.shot('onboarding-crown', find.byType(PageView));
      await g.tap(find.byType(FilledButton));
      await g.shot('onboarding-gestures', find.text('开始使用'));
      await g.tap(find.text('开始使用'));
      expect(finished, isTrue);
      expect(await WatchOnboardingScreen.isDone(), isTrue);
    });

    scenario('四个主页、快捷面板和迷你播放器', (g) async {
      await g.open(const WatchHome());
      await g.shot('hub-listen', find.byType(ListenHubPage));
      await g.tap(find.byTooltip('快捷操作'));
      await g.shot('quick-panel', find.byType(WatchQuickPanel));
      final toggle = find.descendant(
        of: find.byType(WatchQuickPanel),
        matching: find.byTooltip('播放'),
      );
      await g.tap(toggle);
      expect(g.data.player.isPlaying, isTrue);
      await g.tester.binding.handlePopRoute();
      await g.frames();
      for (final (name, type) in [
        ('discover', DiscoverHubPage),
        ('library', LibraryHubPage),
        ('me', MeHubPage),
      ]) {
        await g.tester.drag(find.byType(PageView), Offset(-side * .78, 0));
        await g.frames();
        expect(
          g.tester
              .widget<PageView>(find.byType(PageView))
              .controller!
              .page!
              .round(),
          ['discover', 'library', 'me'].indexOf(name) + 1,
        );
        await g.shot('hub-$name', find.byType(type));
      }
      await g.shot('mini-playing', find.byType(WatchMiniPlayer));
      await g.data.player.togglePlayPause();
      await g.frames();
      await g.shot('mini-paused', find.byType(WatchMiniPlayer));
      await g.tap(find.byType(WatchMiniPlayer));
      expect(find.byType(WatchPlayerScreen), findsOneWidget);
    });

    scenario('空队列首页、设备页音质选择', (g) async {
      g.data.player.playlist = [];
      g.data.auth.user = null;
      await g.open(const WatchHome());
      await g.shot('hub-listen-empty', find.text('找歌'));
      for (var i = 0; i < 3; i++) {
        await g.tester.drag(find.byType(PageView), Offset(-side * .78, 0));
        await g.frames();
      }
      await g.shot('hub-me-sign-in', find.text('登录'));
      await g.tap(find.text('Wi-Fi 音质'));
      await g.shot('quality-picker', find.text('标准'));
      await g.tap(find.text('标准'));
      expect(find.byType(MeHubPage), findsOneWidget);
    });

    scenario('两种息屏界面', (g) async {
      g.ambient = true;
      await g.open(const WatchHome());
      expect(find.byType(PageView), findsNothing);
      await g.shot(
        'ambient-home',
        find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')),
      );
      await g.open(const WatchPlayerScreen());
      expect(find.byType(WatchTransportFace), findsNothing);
      await g.shot('ambient-player', find.byType(WatchChronoFace));
    });

    scenario('扫码与短信登录', (g) async {
      await g.open(const WatchLoginScreen());
      await g.shot('login-methods', find.text('二维码登录'));
      await g.tap(find.text('二维码登录'));
      // The engine decodes Image.memory off the fake test clock. Wait for the
      // actual production RawImage to receive a frame, not a duplicate cache key.
      final pixels = find.byWidgetPredicate(
        (w) => w is RawImage && w.image != null,
      );
      for (
        var attempt = 0;
        pixels.evaluate().isEmpty && attempt < 50;
        attempt++
      ) {
        await g.tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await g.tester.pump();
      }
      await g.shot('login-qr', pixels);
      g.data.qr.status = 2;
      await g.tester.pump(const Duration(seconds: 2));
      await g.tester.pump();
      await g.shot('login-qr-scanned', find.textContaining('已扫码'));
      g.data.qr.status = 0;
      await g.tester.pump(const Duration(seconds: 2));
      await g.tester.pump();
      await g.shot('login-qr-expired', find.text('重新生成'));
      await g.tester.binding.handlePopRoute();
      await g.frames();
      await g.tap(find.text('手机验证码登录'));
      await g.shot('login-sms', find.byType(TextField));
      await g.tester.enterText(find.byType(TextField), '00000001234');
      await g.tap(find.text('获取验证码'));
      await g.shot('login-sms-code', find.textContaining('尾号 1234'));
      await g.tester.enterText(find.byType(TextField), '0000');
      await g.tap(find.text('登录'));
      await g.shot('login-sms-error', find.textContaining('登录失败'));
    });

    scenario('音频输出设备枚举与选择', (g) async {
      var active = 1;
      g.channel('com.mjiutang.ngskg/audio_route_events', (_) async => null);
      g.channel('com.mjiutang.ngskg/audio_route', (call) async {
        if (call.method == 'setAudioOutput') {
          active = call.arguments['deviceId'] as int;
          return true;
        }
        if (call.method == 'getAudioOutputs') {
          return [
            {
              'id': 1,
              'type': 'speaker',
              'name': '手表扬声器',
              'isActive': active == 1,
            },
            {
              'id': 2,
              'type': 'bluetooth',
              'name': '蓝牙耳机',
              'isActive': active == 2,
              'batteryLevel': 75,
            },
          ];
        }
        return null;
      });
      await g.open(const WatchAudioOutputScreen());
      await g.shot('output-speaker', find.text('手表扬声器'));
      await g.tap(find.text('蓝牙耳机'));
      expect(active, 2);
      await g.shot('output-bluetooth', find.text('当前输出'));
    });

    scenario('歌单、排行榜和曲目', (g) async {
      await g.open(const WatchPlaylistListScreen());
      await g.shot('playlists', find.text(galleryPlaylist.name));
      await g.tap(find.text(galleryPlaylist.name));
      await g.shot('playlist-tracks', find.text(gallerySongs.first.name));
      await g.tap(find.text(gallerySongs[1].name));
      expect(g.data.player.currentSong!.id, gallerySongs[1].id);
      await g.open(const WatchRankListScreen());
      await g.shot('ranks', find.text(galleryRank.name));
      await g.tap(find.text(galleryRank.name));
      await g.shot('rank-tracks', find.text(gallerySongs.first.name));
      await g.tap(find.text(gallerySongs.first.name));
      expect(g.data.player.currentSong!.id, gallerySongs.first.id);
    });

    scenario('榜单与 FM 的等待、重试和空列表', (g) async {
      final music = g.data.music;
      music.pendingRanks = Completer();
      await g.open(const WatchRankListScreen());
      await g.shot('ranks-loading', find.byType(CircularProgressIndicator));
      music.pendingRanks!.completeError(StateError('离线样本'));
      await g.frames();
      await g.shot('ranks-error', find.text('重试'));
      music.pendingRanks = Completer();
      await g.tap(find.text('重试'));
      music.pendingRanks!.complete([]);
      await g.frames();
      await g.shot('ranks-empty', find.text('暂无榜单'));

      music.pendingRankSongs = Completer();
      await g.open(const WatchRankSongsScreen(rank: galleryRank));
      await g.shot(
        'rank-tracks-loading',
        find.byType(CircularProgressIndicator),
      );
      music.pendingRankSongs!.completeError(StateError('离线样本'));
      await g.frames();
      await g.shot('rank-tracks-error', find.text('重试'));
      music.pendingRankSongs = Completer();
      await g.tap(find.text('重试'));
      music.pendingRankSongs!.complete([]);
      await g.frames();
      await g.shot('rank-tracks-empty', find.text('这个榜单里还没有歌'));

      music.pendingFm = Completer();
      g.data.player.playlist = [];
      await g.open(const WatchFmScreen());
      await g.shot('fm-loading', find.text('正在加载歌曲'));
      music.pendingFm!.completeError(StateError('离线样本'));
      await g.frames();
      await g.shot('fm-error', find.text('重试'));
      music.pendingFm = Completer();
      await g.tap(find.text('重试'));
      music.pendingFm!.complete([]);
      await g.frames();
      await g.shot('fm-empty', find.text('暂时没有推荐歌曲'));
    });

    scenario('收藏、本地歌曲与队列', (g) async {
      await g.open(const WatchLikedSongsScreen());
      await g.shot('liked', find.text(gallerySongs.first.name));
      await g.open(const WatchLocalMusicScreen());
      await g.shot('local', find.text('林间'));
      await g.tap(find.text('林间'));
      expect(g.data.player.currentSong!.filePath, '/fixture/forest.flac');
      await g.open(const WatchQueueScreen());
      await g.shot('queue', find.text('林间'));
      await g.tap(find.text('清晨'));
      expect(g.data.player.currentIndex, 1);
      g.data.player.playlist = [];
      await g.open(const WatchQueueScreen());
      await g.shot('queue-empty', find.text('播放队列为空'));
      g.data.local.songs = [];
      await g.open(const WatchLocalMusicScreen());
      await g.shot('local-empty', find.text('手表里还没有音乐'));
      g.data.local.isScanning = true;
      await g.open(const WatchLocalMusicScreen());
      await g.shot('local-scanning', find.byType(CircularProgressIndicator));
      g.data.likes.likedSongs.clear();
      await g.open(const WatchLikedSongsScreen());
      await g.shot('liked-empty', find.text('还没有收藏歌曲'));
      g.data.auth.user = null;
      await g.open(const WatchLikedSongsScreen());
      await g.shot('liked-sign-in', find.text('登录'));
      await g.open(const WatchPlaylistListScreen());
      await g.shot('playlists-sign-in', find.text('登录后查看歌单'));
    });

    scenario('搜索防抖、等待、空结果、错误与播放', (g) async {
      await g.open(const WatchSearchScreen());
      await g.shot('search', find.byType(TextField));
      Future<void> search(String term) async {
        await g.tester.enterText(find.byType(TextField), term);
        await g.frames();
      }

      g.data.music.pendingSearch = Completer();
      await search('等待');
      await g.shot('search-loading', find.byType(CircularProgressIndicator));
      g.data.music.pendingSearch!.complete([]);
      await g.frames();
      await g.shot('search-empty', find.text('没找到这首歌'));
      await search('断线');
      await g.shot('search-error', find.text('重试'));
      await search('小夜');
      await g.shot('search-results', find.text(gallerySongs.first.name));
      await g.tap(find.text(gallerySongs.first.name));
      expect(g.data.player.playlist.length, 2);
    });

    scenario('私人 FM 队列与换歌', (g) async {
      await g.open(const WatchFmScreen());
      expect(g.data.player.isFmMode, isTrue);
      await g.shot('fm', find.text('海风'));
      await g.tap(find.byIcon(Icons.skip_next_rounded));
      expect(find.text('潮声'), findsOneWidget);
    });

    scenario('设置与日志导出结果', (g) async {
      // A fresh private temp directory is the only allowed documents path.
      // Export runs the real Dart formatter/writer with synthetic device data.
      final dir = Directory.systemTemp.createTempSync('watch-gallery-');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Documents(dir);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        dir.deleteSync(recursive: true);
      });
      g.channel(
        'com.mjiutang.ngskg/log_export',
        (call) async => switch (call.method) {
          'getDeviceInfo' => {
            'manufacturer': 'Fixture',
            'model': 'Round Watch',
          },
          'dumpLogcat' => 'Fixture: app ready',
          _ => null,
        },
      );
      PackageInfo.setMockInitialValues(
        appName: 'Sample Watch',
        packageName: 'test.watch.gallery',
        version: '1.0',
        buildNumber: '1',
        buildSignature: '',
      );
      await g.open(const WatchSettingsScreen());
      await g.shot('settings', find.byType(WatchSettingsScreen));
      for (final (label, name) in [
        ('退出登录', 'logout'),
        ('清除音频缓存', 'clear-cache'),
      ]) {
        await g.tap(find.text(label));
        await g.shot('confirm-$name', find.byTooltip('取消'));
        await g.tap(find.byTooltip('取消'));
      }
      await g.tap(find.text('导出日志'));
      expect(find.byType(WatchLogExportScreen), findsOneWidget);
      await g.shot('logs-before', find.text('导出完整日志'));
      // Await the button's actual asynchronous handler in real time. Waiting
      // for file I/O in the test binding's fake clock can stall indefinitely.
      final button = g.tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '导出完整日志'),
      );
      await g.tester.runAsync(button.onPressed! as Future<void> Function());
      await g.frames();
      expect(
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .single
            .readAsStringSync(),
        contains('Fixture: app ready'),
      );
      await g.tester.pump(const Duration(seconds: 2));
      await g.frames();
      await g.shot('logs-after', find.text('导出成功'));
      await g.tap(find.text('查看保存位置'));
      await g.shot('logs-location', find.byType(SelectableText));
    });
  }
}
