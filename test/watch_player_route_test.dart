// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/providers/liked_songs_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/utils/navigation.dart';
import 'package:ngskg_plus/utils/error_dialog.dart';
import 'package:ngskg_plus/watch/app.dart';
import 'package:ngskg_plus/watch/theme/watch_theme.dart';
import 'package:ngskg_plus/watch/theme/watch_theme_provider.dart';
import 'package:ngskg_plus/watch/screens/lyrics_screen.dart';
import 'package:ngskg_plus/watch/screens/player_screen.dart';
import 'package:ngskg_plus/watch/widgets/watch_transport_face.dart';
import 'package:provider/provider.dart';
import 'package:wear_plus/wear_plus.dart';

class _Likes extends Fake with ChangeNotifier implements LikedSongsProvider {
  @override
  Set<int> get likedIds => const {};
}

class _Player extends Fake with ChangeNotifier implements PlayerProvider {
  final calls = <String>[];

  @override
  final Song currentSong = const Song(id: 1, name: '星光', artists: ['小夜']);
  @override
  List<Song> get playlist => [currentSong];
  @override
  final lyricController = LyricController();
  @override
  bool isPlaying = false;
  @override
  bool get isFmMode => false;
  @override
  Duration get position => const Duration(seconds: 45);
  @override
  Duration get duration => const Duration(minutes: 3);
  @override
  double get progress => 0.25;
  @override
  Null get palette => null;
  @override
  PlayMode get playMode => PlayMode.sequential;
  @override
  double get currentSpeed => 1;
  @override
  String get resolvedQualityLabel => '标准';
  @override
  String get resolvedQuality => '128';
  @override
  int get qualityLevel => 0;

  @override
  Future<void> togglePlayPause() async {
    calls.add('toggle');
    isPlaying = !isPlaying;
    notifyListeners();
  }

  @override
  void playPrevious() => calls.add('previous');
  @override
  void playNext() => calls.add('next');

  @override
  void dispose() {
    lyricController.dispose();
    super.dispose();
  }
}

void main() {
  testWidgets('192dp 圆屏从聆听歌卡打开播放器，操作按钮并进入歌词与播放选项', (tester) async {
    const side = 192.0;
    const inset = side * 0.12;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size.square(side);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const wear = MethodChannel('wear');
    const rotary = MethodChannel('flutter.wearable_rotary.channel');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      wear,
      (call) async => switch (call.method) {
        'getShape' => 'round',
        'isAmbient' => false,
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(rotary, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(wear, null);
      messenger.setMockMethodCallHandler(rotary, null);
    });

    final player = _Player();
    addTearDown(player.dispose);
    final boundaryKey = GlobalKey();
    final exportDir = Platform.environment['WATCH_SCREENSHOTS'];
    Future<void> capture(String name) async {
      if (exportDir == null) return;
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final directory = await Directory(exportDir).create(recursive: true);
          await File('${directory.path}/$name.png').writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        } finally {
          image.dispose();
        }
      });
    }

    await tester.runAsync(() async {
      // Test shells lack Android's CJK fallback. Load the app's bundled font.
      await (FontLoader('Roboto')..addFont(
            rootBundle.load('assets/fonts/HarmonyOS_Sans_Regular.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayerProvider>.value(value: player),
          ChangeNotifierProvider<LikedSongsProvider>(create: (_) => _Likes()),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          theme: buildWatchTheme(WatchThemeProvider().colorSeed),
          builder: (_, child) => WatchShape(
            builder: (_, _, _) => RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: Colors.black,
                child: ClipOval(child: child),
              ),
            ),
          ),
          home: const WatchHome(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('01-listen');
    await tester.tap(find.text(player.currentSong.name));
    await tester.pumpAndSettle();

    final screen = find.byType(WatchPlayerScreen);
    final face = find.descendant(
      of: screen,
      matching: find.byType(WatchTransportFace),
    );
    expect(face, findsOneWidget);
    final faceRect = tester.getRect(face);
    expect(faceRect.left, greaterThanOrEqualTo(inset - 0.01));
    expect(faceRect.top, greaterThanOrEqualTo(inset - 0.01));
    expect(faceRect.right, lessThanOrEqualTo(side - inset + 0.01));
    expect(faceRect.bottom, lessThanOrEqualTo(side - inset + 0.01));
    expect(find.text(player.currentSong.name), findsOneWidget);

    Future<void> tapAction(String label) async {
      final button = find.descendant(of: face, matching: find.byTooltip(label));
      expect(button.hitTestable(), findsOneWidget, reason: label);
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await tapAction('播放');
    await capture('02-player');
    await tapAction('暂停');
    await tapAction('上一首');
    await tapAction('下一首');
    expect(player.calls, ['toggle', 'toggle', 'previous', 'next']);

    final playerRoute = ModalRoute.of(tester.element(face))!;
    await tapAction('歌词');
    expect(playerRoute.isCurrent, isFalse);
    expect(find.byType(WatchLyricsScreen), findsOneWidget);
    expect(find.text('暂无歌词'), findsOneWidget);
    player.lyricController.loadLyric(
      '[00:01.00]星星落在窗边\n[00:35.00]夜色慢慢亮起\n[00:58.00]风吹过安静的街',
    );
    player.lyricController.setProgress(player.position);
    await tester.pumpAndSettle();
    await capture('03-lyrics');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(playerRoute.isCurrent, isTrue);

    await tapAction('更多操作');
    expect(playerRoute.isCurrent, isFalse);
    expect(find.text('播放选项'), findsOneWidget);
    await capture('04-options');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(playerRoute.isCurrent, isTrue);
    showErrorDialog(title: '播放失败', message: '连接超时，请稍后重试');
    await tester.pumpAndSettle();
    await capture('05-error');
    expect(find.text('播放失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
