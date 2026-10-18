// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/constants/quality.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/providers/liked_songs_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/providers/theme_provider.dart';
import 'package:ngskg_plus/screens/player_screen.dart';
import 'package:ngskg_plus/theme/theme_assets.dart';
import 'package:ngskg_plus/widgets/hi_res_badge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _song = Song(id: 1, name: '高解析音质歌曲', artists: ['测试歌手']);
const _openPlayer = ValueKey('open-player');

class _Player extends ChangeNotifier implements PlayerProvider {
  String _resolvedQuality = 'high';

  @override
  final LyricController lyricController = LyricController();
  @override
  final ValueNotifier<PlaybackProgress> playbackProgress = ValueNotifier((
    position: const Duration(seconds: 45),
    duration: const Duration(minutes: 4),
  ));
  @override
  Song get currentSong => _song;
  @override
  List<Map<String, dynamic>> get currentSongAuthors => const [];
  @override
  bool get isPlaying => true;
  @override
  bool get isLoading => false;
  @override
  bool get isFmMode => false;
  @override
  PlayMode get playMode => PlayMode.sequential;
  @override
  Color get backgroundColor => Colors.indigo;
  @override
  List<Color> get paletteColors => const [];
  @override
  List<QualityOption> get qualityOptions => const [];
  @override
  String get resolvedQuality => _resolvedQuality;
  @override
  int get qualityLevel => 3;
  @override
  bool get lyricLoading => false;
  @override
  int get selectedLyricLang => 0;
  @override
  bool get hasLangData => false;
  @override
  Duration get position => playbackProgress.value.position;

  void resolveQuality(String quality) {
    _resolvedQuality = quality;
    notifyListeners();
  }

  @override
  void dispose() {
    lyricController.dispose();
    playbackProgress.dispose();
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Likes extends ChangeNotifier implements LikedSongsProvider {
  @override
  Set<int> get likedIds => const {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _openScreen(
    WidgetTester tester, _Player player, ThemeProvider theme) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<PlayerProvider>.value(value: player),
      ChangeNotifierProvider<ThemeProvider>.value(value: theme),
      ChangeNotifierProvider<LikedSongsProvider>(create: (_) => _Likes()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: FilledButton(
              key: _openPlayer,
              onPressed: () => Navigator.of(context).push(PlayerScreen.route()),
              child: const Text('打开播放器'),
            ),
          ),
        );
      }),
    ),
  ));
  await tester.tap(find.byKey(_openPlayer));
  await tester.pumpAndSettle();
}

void main() {
  late String originalBackground;
  late String originalBadge;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalBackground = ThemeAssets.playerBg;
    originalBadge = ThemeAssets.hiResBadge;
    ThemeAssets.playerBg = '';
    ThemeAssets.hiResBadge = 'assets/images/hi_res_badge.jpg';
  });

  tearDown(() {
    ThemeAssets.playerBg = originalBackground;
    ThemeAssets.hiResBadge = originalBadge;
  });

  for (final badgeEnabled in [false, true]) {
    testWidgets('高解析音质打开真实播放器，徽章开关为$badgeEnabled时不抛构建异常', (tester) async {
      final player = _Player();
      final theme = ThemeProvider();
      await theme.setShowHiResBadge(badgeEnabled);
      try {
        await _openScreen(tester, player, theme);
        expect(tester.takeException(), isNull);
        expect(find.byType(PlayerScreen), findsOneWidget);
        expect(find.text(_song.name), findsOneWidget);
        expect(find.text('Hi-Res'), findsOneWidget);
        expect(find.byType(HiResBadge),
            badgeEnabled ? findsOneWidget : findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        player.dispose();
        theme.dispose();
      }
    });
  }

  testWidgets('徽章开关即时刷新，播放器通知更新实际音质时也正确显示', (tester) async {
    final player = _Player();
    final theme = ThemeProvider();
    try {
      await _openScreen(tester, player, theme);
      expect(tester.takeException(), isNull);
      final screen = tester.state(find.byType(PlayerScreen));
      expect(find.byType(HiResBadge), findsNothing);

      await theme.setShowHiResBadge(true);
      await tester.pumpAndSettle();
      expect(find.byType(HiResBadge), findsOneWidget);
      await theme.setShowHiResBadge(false);
      await tester.pumpAndSettle();
      expect(find.byType(HiResBadge), findsNothing);
      await theme.setShowHiResBadge(true);
      await tester.pumpAndSettle();
      expect(find.byType(HiResBadge), findsOneWidget);

      // 这里只由播放器通知 Consumer，不重新挂载 PlayerScreen。
      player.resolveQuality('flac');
      await tester.pumpAndSettle();
      expect(find.byType(HiResBadge), findsNothing);
      expect(find.text('SQ'), findsOneWidget);
      player.resolveQuality('high');
      await tester.pumpAndSettle();
      expect(find.byType(HiResBadge), findsOneWidget);
      expect(tester.state(find.byType(PlayerScreen)), same(screen));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      player.dispose();
      theme.dispose();
    }
  });
}
