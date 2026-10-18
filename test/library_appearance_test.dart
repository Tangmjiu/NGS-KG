// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/playlist.dart';
import 'package:ngskg_plus/models/rank_entry.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/models/user.dart';
import 'package:ngskg_plus/providers/auth_provider.dart';
import 'package:ngskg_plus/providers/liked_songs_provider.dart';
import 'package:ngskg_plus/providers/local_music_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/providers/playlist_provider.dart';
import 'package:ngskg_plus/providers/theme_provider.dart';
import 'package:ngskg_plus/screens/library_screen.dart';
import 'package:ngskg_plus/screens/search_screen.dart';
import 'package:ngskg_plus/screens/theme_settings_screen.dart';
import 'package:ngskg_plus/services/music_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoggedIn => false;
  @override
  User? get user => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalMusic extends ChangeNotifier implements LocalMusicProvider {
  @override
  List<Song> get songs => [];
  @override
  Future<void> scanMusic({bool forceFull = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LikedSongs extends ChangeNotifier implements LikedSongsProvider {
  @override
  Set<int> get likedIds => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playlists extends ChangeNotifier implements PlaylistProvider {
  @override
  List<Playlist> get userPlaylists => [];
  @override
  bool get isLoading => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends ChangeNotifier implements PlayerProvider {
  @override
  Song? get currentSong => null;
  @override
  bool get isPlayerScreenVisible => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Music implements MusicService {
  String? searchedKeyword;

  @override
  Future<List<Map<String, dynamic>>> getHotSearch() async => [];
  @override
  Future<List<RankEntry>> getRankList() async => [];
  @override
  Future<List<String>> getSearchSuggest(String keyword) async => [];
  @override
  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0, String type = 'song'}) async {
    searchedKeyword = keyword;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _smallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _largeText(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.25),
      ),
      child: child!,
    );

void main() {
  testWidgets('小屏嵌入搜索保留提交和分类，且不添加第二层 Scaffold', (tester) async {
    _smallViewport(tester);
    final music = _Music();
    await tester.pumpWidget(ChangeNotifierProvider<PlayerProvider>(
      create: (_) => _Player(),
      child: MaterialApp(
        builder: _largeText,
        home: Scaffold(body: SearchScreen(embedded: true, musicService: music)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.enterText(find.byType(TextField), '晴天');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(music.searchedKeyword, '晴天');
    expect(find.text('未找到歌曲'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('小屏资料库的登录、设置和本地音乐入口仍可访问', (tester) async {
    _smallViewport(tester);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
        ChangeNotifierProvider<LocalMusicProvider>(
            create: (_) => _LocalMusic()),
        ChangeNotifierProvider<LikedSongsProvider>(
            create: (_) => _LikedSongs()),
        ChangeNotifierProvider<PlaylistProvider>(create: (_) => _Playlists()),
        ChangeNotifierProvider<PlayerProvider>(create: (_) => _Player()),
      ],
      child: MaterialApp(
        builder: _largeText,
        routes: {
          for (final route in ['/settings', '/login', '/local/music'])
            route: (_) => Scaffold(body: Text('已打开 $route')),
        },
        home: Scaffold(body: LibraryScreen(musicService: _Music())),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('资料库'), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('已打开 /settings'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录音乐账号'));
    await tester.pumpAndSettle();
    expect(find.text('已打开 /login'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('本地音乐'));
    await tester.tap(find.text('本地音乐'));
    await tester.pumpAndSettle();
    expect(find.text('已打开 /local/music'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('浅深预览独立于应用模式，样式预览按钮支持状态切换', (tester) async {
    _smallViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeProvider();
    await theme.setThemeMode(ThemeMode.light);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      theme.dispose();
    });
    await tester.pumpWidget(ChangeNotifierProvider<ThemeProvider>.value(
      value: theme,
      child: Builder(
          builder: (context) => MaterialApp(
                theme: theme.buildLightTheme(context),
                builder: _largeText,
                home: const ThemeSettingsScreen(),
              )),
    ));
    await tester.pumpAndSettle();
    final previewTitle = find.text('音乐，让日常不同');
    expect(Theme.of(tester.element(previewTitle)).brightness, Brightness.light);
    await tester.tap(find.widgetWithText(ChoiceChip, '深色预览'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(previewTitle)).brightness, Brightness.dark);
    expect(theme.themeMode, ThemeMode.light);
    await tester.ensureVisible(find.text('收藏 · 预览'));
    await tester.tap(find.text('收藏 · 预览'));
    await tester.pumpAndSettle();
    expect(find.text('已收藏 · 预览'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
