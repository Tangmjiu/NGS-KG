// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/artist.dart';
import 'package:ngskg_plus/models/lyric_settings.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/models/theme_pack.dart';
import 'package:ngskg_plus/providers/audio_settings_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/providers/theme_provider.dart';
import 'package:ngskg_plus/screens/audio_effects_screen.dart';
import 'package:ngskg_plus/screens/comments_screen.dart';
import 'package:ngskg_plus/screens/lyric_settings_screen.dart';
import 'package:ngskg_plus/services/equalizer_service.dart';
import 'package:ngskg_plus/services/music_service.dart';
import 'package:ngskg_plus/theme/app_theme.dart';
import 'package:ngskg_plus/ui/components/player_bottom_padding.dart';
import 'package:ngskg_plus/ui/components/settings_slider.dart';
import 'package:ngskg_plus/widgets/lyric_settings_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Player extends ChangeNotifier implements PlayerProvider {
  double volume = 1;

  @override
  Song? get currentSong => const Song(id: 1, name: '正在播放', artists: ['歌手']);
  @override
  bool get isPlayerScreenVisible => false;
  @override
  bool get isMiniPlayerDismissed => false;
  @override
  void setVolume(double value) => volume = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LyricTheme extends ChangeNotifier implements ThemeProvider {
  LyricSettings _settings = const LyricSettings();

  @override
  LyricSettings get lyricSettings => _settings;
  @override
  Future<void> setLyricSettings(LyricSettings settings) async {
    _settings = settings;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Music implements MusicService {
  final Future<List<Comment>> Function(String type, int id) load;

  _Music(this.load);

  @override
  Future<List<Comment>> getMusicComments(int songId,
          {int page = 1, int pageSize = 200}) =>
      load('music', songId);
  @override
  Future<List<Comment>> getPlaylistComments(int playlistId,
          {int page = 1, int pageSize = 200}) =>
      load('playlist', playlistId);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _smallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  Widget home, {
  _Player? player,
  _LyricTheme? lyricTheme,
  AudioSettingsProvider? audioSettings,
  bool dark = false,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerProvider>(
            create: (_) => player ?? _Player()),
        ChangeNotifierProvider<ThemeProvider>(
            create: (_) => lyricTheme ?? _LyricTheme()),
        ChangeNotifierProvider<AudioSettingsProvider>(
            create: (_) => audioSettings ?? AudioSettingsProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.build(
            dark ? ngsNagisa.darkScheme! : ngsNagisa.lightScheme!, ngsNagisa),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: home,
      ),
    );

void main() {
  testWidgets('窄屏大字评论失败后可重试，长昵称和点赞数不溢出且可返回', (tester) async {
    _smallViewport(tester);
    var calls = 0;
    final music = _Music((type, id) async {
      expect(type, 'music');
      expect(id, 42);
      if (++calls == 1) throw StateError('暂时离线');
      return const [
        Comment(
          id: 1,
          userName: '这位听友的昵称很长也应该可以阅读',
          content: '戴上耳机慢慢听，每一次都能发现新的细节。',
          time: '2026-10-04 12:30',
          likedCount: 123456789,
        ),
      ];
    });
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) =>
                  CommentsScreen(type: 'music', id: 42, musicService: music))),
          child: const Text('打开评论'),
        ),
      ),
    )));
    await tester.tap(find.text('打开评论'));
    await tester.pumpAndSettle();
    expect(find.text('评论加载失败'), findsOneWidget);
    expect(find.text('暂无评论'), findsNothing);
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('这位听友的昵称很长也应该可以阅读'), findsOneWidget);
    await tester.ensureVisible(find.text('123456789'));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(PlayerBottomPadding));
    expect(tester.getSize(find.byType(PlayerBottomPadding)).height,
        greaterThan(80));
    await tester.ensureVisible(find.byType(BackButton));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('打开评论'), findsOneWidget);
  });

  testWidgets('评论对象变更后，旧歌曲响应不会覆盖新歌单评论', (tester) async {
    _smallViewport(tester);
    final pending = Completer<List<Comment>>();
    final music = _Music((type, id) async {
      if (type == 'music') return pending.future;
      expect(id, 2);
      return const [Comment(id: 2, content: '新歌单的评论')];
    });
    await tester.pumpWidget(
        _app(CommentsScreen(type: 'music', id: 1, musicService: music)));
    await tester.pump();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.pumpWidget(
        _app(CommentsScreen(type: 'playlist', id: 2, musicService: music)));
    await tester.pumpAndSettle();
    expect(find.text('新歌单的评论'), findsOneWidget);
    pending.complete(const [Comment(id: 1, content: '旧歌曲的评论')]);
    await tester.pumpAndSettle();
    expect(find.text('新歌单的评论'), findsOneWidget);
    expect(find.text('旧歌曲的评论'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('独立歌词设置沿用${dark ? '深色' : '浅色'}主题，大字可操作并同步外部配置', (tester) async {
      _smallViewport(tester);
      final theme = _LyricTheme();
      await tester.pumpWidget(
          _app(const LyricSettingsScreen(), lyricTheme: theme, dark: dark));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.text('歌词设置'))).brightness,
          dark ? Brightness.dark : Brightness.light);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(theme.lyricSettings.centerAlign, true);
      await theme.setLyricSettings(
          const LyricSettings(fontSize: 24, fontWeight: 700, blurEffect: true));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(find.byType(Slider).first).value, 24);
      expect(tester.widget<Slider>(find.byType(Slider).last).value, 700);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, false);
      expect(tester.widget<Switch>(find.byType(Switch).last).value, true);
      await tester.ensureVisible(find.byType(PlayerBottomPadding));
      expect(tester.getSize(find.byType(PlayerBottomPadding)).height,
          greaterThan(80));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('播放器歌词面板保持白色样式，大字小高度下可滚动完成设置', (tester) async {
    _smallViewport(tester);
    final theme = _LyricTheme();
    await tester.pumpWidget(_app(
      const Scaffold(body: SizedBox(height: 240, child: LyricSettingsPanel())),
      lyricTheme: theme,
    ));
    await tester.pumpAndSettle();
    expect(
        tester.widget<Text>(find.text('歌词视图字体大小')).style?.color, Colors.white);
    expect(tester.widget<Switch>(find.byType(Switch).last).activeThumbColor,
        Colors.white);
    await tester.ensureVisible(find.byType(Switch).last);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(theme.lyricSettings.blurEffect, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏大字音效保留音量、淡入和均衡器调节及重置', (tester) async {
    _smallViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      const channel = MethodChannel('com.mjiutang.ngskg/equalizer');
      final levels = [-400, 200];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        final band = (call.arguments as Map?)?['band'] as int? ?? 0;
        switch (call.method) {
          case 'attachSession':
            return true;
          case 'getBandLevelRange':
            return [-1200, 1200];
          case 'getNumberOfBands':
            return levels.length;
          case 'getBandLevel':
            return levels[band];
          case 'getCenterFreq':
            return band == 0 ? 60000 : 1000000;
          case 'setBandLevel':
            levels[band] = (call.arguments as Map)['level'] as int;
        }
        return null;
      });
      addTearDown(() async {
        await EqualizerService.instance.release();
        messenger.setMockMethodCallHandler(channel, null);
      });
      await EqualizerService.instance.attachSession(42);
      final player = _Player();
      final audioSettings = AudioSettingsProvider();
      await tester.pumpWidget(_app(const AudioEffectsScreen(),
          player: player, audioSettings: audioSettings));
      await tester.pumpAndSettle();
      final volume = find.descendant(
          of: find.widgetWithText(SettingsSlider, '播放音量'),
          matching: find.byType(Slider));
      final volumeRect = tester.getRect(volume);
      await tester.tapAt(Offset(
          volumeRect.left + volumeRect.width * 0.3, volumeRect.center.dy));
      await tester.pumpAndSettle();
      expect(player.volume, inExclusiveRange(0, 1));
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(audioSettings.crossfadeEnabled, true);
      final fade = find.descendant(
          of: find.widgetWithText(SettingsSlider, '淡入时长'),
          matching: find.byType(Slider));
      await tester.ensureVisible(fade);
      final fadeRect = tester.getRect(fade);
      await tester.tapAt(
          Offset(fadeRect.left + fadeRect.width * 0.75, fadeRect.center.dy));
      await tester.pumpAndSettle();
      expect(audioSettings.crossfadeMs, greaterThan(2000));
      await tester.scrollUntilVisible(find.text('60 Hz'), 250,
          scrollable: find.byType(Scrollable).first);
      final band = find.descendant(
          of: find.widgetWithText(SettingsSlider, '60 Hz'),
          matching: find.byType(Slider));
      await tester.ensureVisible(band);
      final bandRect = tester.getRect(band);
      await tester.tapAt(
          Offset(bandRect.left + bandRect.width * 0.75, bandRect.center.dy));
      await tester.pumpAndSettle();
      expect(levels.first, greaterThan(0));
      await tester.ensureVisible(find.text('重置'));
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      expect(levels, [0, 0]);
      expect(tester.takeException(), isNull);
    } finally {
      // testWidgets 在 addTearDown 之前检查 foundation 调试变量。
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}
