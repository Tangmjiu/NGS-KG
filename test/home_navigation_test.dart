// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/album.dart';
import 'package:ngskg_plus/models/card_section.dart';
import 'package:ngskg_plus/models/latest_listen_info.dart';
import 'package:ngskg_plus/models/playlist.dart';
import 'package:ngskg_plus/models/radio.dart';
import 'package:ngskg_plus/models/rank_entry.dart';
import 'package:ngskg_plus/models/scene_category.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/models/user.dart';
import 'package:ngskg_plus/models/vip_info.dart';
import 'package:ngskg_plus/providers/auth_provider.dart';
import 'package:ngskg_plus/providers/discover_provider.dart';
import 'package:ngskg_plus/providers/liked_songs_provider.dart';
import 'package:ngskg_plus/providers/local_music_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/providers/playlist_provider.dart';
import 'package:ngskg_plus/screens/discover/sections/discover_personal_fm_row.dart';
import 'package:ngskg_plus/screens/discover_screen.dart';
import 'package:ngskg_plus/screens/home_screen.dart';
import 'package:ngskg_plus/screens/library_screen.dart';
import 'package:ngskg_plus/screens/search_screen.dart';
import 'package:ngskg_plus/services/music_service.dart';
import 'package:provider/provider.dart';

const _songs = [
  Song(id: 1, name: '第一首推荐', artists: ['歌手']),
  Song(id: 2, name: '第二首推荐', artists: ['歌手']),
  Song(id: 3, name: '第三首推荐', artists: ['歌手']),
];

class _Music extends Fake implements MusicService {
  final calls = <String, int>{};
  final searched = <(String, String)>[];

  void _count(String name) =>
      calls.update(name, (value) => value + 1, ifAbsent: () => 1);

  @override
  Future<List<Song>> getTopSongs() async {
    _count('songs');
    return _songs;
  }

  @override
  Future<List<Song>> getDailyRecommend() async {
    _count('daily');
    return _songs;
  }

  @override
  Future<CardSection> getCardSongs(int cardId) async {
    _count('card-$cardId');
    return const CardSection(recDesc: '', songs: []);
  }

  @override
  Future<CardSection> getCardSongsYouth(int cardId, {int? pagesize}) async {
    _count('card-$cardId');
    return const CardSection(recDesc: '', songs: []);
  }

  @override
  Future<LatestListenInfo?> getLatestListen() async => null;

  @override
  Future<List<RadioStation>> getFmRecommend() async {
    _count('radio');
    return [];
  }

  @override
  Future<List<Playlist>> getTopPlaylists(
      {int limit = 200, int offset = 0, int categoryId = 0}) async {
    _count('playlists');
    return const [Playlist(id: 1, name: '发现歌单')];
  }

  @override
  Future<List<RankEntry>> getRankList() async {
    _count('ranks');
    return [];
  }

  @override
  Future<List<Album>> getTopAlbums(
      {int? type, int page = 1, int pageSize = 30}) async {
    _count('albums');
    return [];
  }

  @override
  Future<List<SceneCategory>> getSceneLists() async {
    _count('scenes');
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getTopIp() async {
    _count('ip');
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getPersonalFm({
    String mode = 'normal',
    int songPoolId = 0,
    String? hash,
    int? songid,
    int? playtime,
    String? action,
    int? isOverplay,
    int? remainSongcnt,
  }) async {
    _count('personalFm');
    return [
      for (var id = 1; id <= 4; id++)
        {'songid': id, 'songname': 'FM 推荐 $id', 'hash': 'fm-$id'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getHotSearch() async {
    _count('hotSearch');
    return [];
  }

  @override
  Future<List<String>> getSearchSuggest(String keyword) async => [];

  @override
  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0, String type = 'song'}) async {
    searched.add((type, keyword));
    return [
      Song(id: 20, name: '$keyword 搜索结果', artists: const ['歌手'])
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> searchPlaylists(String keyword,
      {int limit = 30, int offset = 0}) async {
    searched.add(('special', keyword));
    return [
      {'specialname': '$keyword 歌单结果', 'songcount': 5}
    ];
  }

  @override
  Future<VipInfo?> getVipInfo() async {
    _count('vip');
    return null;
  }
}

class _Player extends ChangeNotifier implements PlayerProvider {
  @override
  Song? get currentSong => null;
  @override
  bool get isPlayerScreenVisible => false;
  @override
  bool get isMiniPlayerDismissed => false;
  @override
  bool get isFmMode => false;
  @override
  bool get isPlaying => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoggedIn => true;
  @override
  User get user => const User(userId: 1, nickname: '测试用户');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalMusic extends ChangeNotifier implements LocalMusicProvider {
  int scans = 0;
  @override
  List<Song> get songs => [];
  @override
  Future<void> scanMusic({bool forceFull = false}) async => scans++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LikedSongs extends ChangeNotifier implements LikedSongsProvider {
  int loads = 0;
  @override
  Set<int> get likedIds => {};
  @override
  Future<void> load({bool force = false}) async => loads++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playlists extends ChangeNotifier implements PlaylistProvider {
  int topLoads = 0;
  int userLoads = 0;
  @override
  List<Playlist> get topPlaylists => [];
  @override
  List<Playlist> get userPlaylists => [];
  @override
  bool get isLoading => false;
  @override
  Future<void> fetchTopPlaylists({int limit = 30}) async => topLoads++;
  @override
  Future<void> fetchUserPlaylist(int? userId, {bool force = false}) async =>
      userLoads++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _App {
  final music = _Music();
  final local = _LocalMusic();
  final likes = _LikedSongs();
  final playlists = _Playlists();

  Widget build({double textScale = 1}) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
          ChangeNotifierProvider<PlayerProvider>(create: (_) => _Player()),
          ChangeNotifierProvider<LocalMusicProvider>(create: (_) => local),
          ChangeNotifierProvider<LikedSongsProvider>(create: (_) => likes),
          ChangeNotifierProvider<PlaylistProvider>(create: (_) => playlists),
          ChangeNotifierProvider<DiscoverProvider>(
              create: (_) => DiscoverProvider(music)),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: HomeScreen(musicService: music),
        ),
      );
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(label));
  await tester.pumpAndSettle();
}

void _viewport(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('跨越导航断点保留搜索输入、页面状态与请求结果', (tester) async {
    _viewport(tester);
    final app = _App();
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await _tab(tester, '搜索');
    await tester.enterText(find.byType(TextField), '晚风');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final search = tester.state(find.byType(SearchScreen));

    for (final width in [840.0, 600.0, 390.0]) {
      tester.view.physicalSize = Size(width, 760);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail),
          width >= 600 ? findsOneWidget : findsNothing);
      expect(find.byType(NavigationBar),
          width < 600 ? findsOneWidget : findsNothing);
      expect(tester.state(find.byType(SearchScreen)), same(search));
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '晚风');
      expect(find.text('晚风 搜索结果'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(app.music.calls['hotSearch'], 1);
    expect(app.music.searched, [('song', '晚风')]);
  });

  testWidgets('快速连续切页只将最后页面暴露给输入和读屏', (tester) async {
    _viewport(tester);
    final app = _App();
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索'));
    await tester.pump(const Duration(milliseconds: 45));
    await tester.tap(find.byTooltip('发现'));
    await tester.pump(const Duration(milliseconds: 45));
    await tester.tap(find.byTooltip('首页'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    expect(find.byType(DiscoverScreen), findsNothing);
    expect(find.byType(SearchScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(DiscoverScreen, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('四入口首次访问才加载，来回切换复用页面和请求结果', (tester) async {
    _viewport(tester);
    final app = _App();
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    expect(app.music.calls['daily'], 1);
    expect(app.playlists.topLoads, 1);
    expect(app.music.calls['personalFm'], isNull);
    expect(app.music.calls['hotSearch'], isNull);
    expect(app.local.scans, 0);
    expect(find.byType(DiscoverScreen, skipOffstage: false), findsNothing);
    expect(find.byType(SearchScreen, skipOffstage: false), findsNothing);
    expect(find.byType(LibraryScreen, skipOffstage: false), findsNothing);

    await _tab(tester, '搜索');
    final search = tester.state(find.byType(SearchScreen));
    expect(app.music.calls['hotSearch'], 1);
    expect(app.music.calls['ranks'], 1);
    expect(app.local.scans, 0);
    expect(find.byType(Scaffold), findsOneWidget);

    await _tab(tester, '发现');
    final discover = tester.state(find.byType(DiscoverScreen));
    expect(app.music.calls['personalFm'], 1);
    expect(app.music.calls['ranks'], 2);

    await _tab(tester, '资料库');
    final library = tester.state(find.byType(LibraryScreen));
    expect(app.local.scans, 1);
    expect(app.likes.loads, 1);
    expect(app.playlists.userLoads, 1);
    expect(app.music.calls['vip'], 1);

    await _tab(tester, '首页');
    await _tab(tester, '发现');
    expect(tester.state(find.byType(DiscoverScreen)), same(discover));
    await _tab(tester, '资料库');
    expect(tester.state(find.byType(LibraryScreen)), same(library));
    await _tab(tester, '搜索');
    expect(tester.state(find.byType(SearchScreen)), same(search));
    expect(app.music.calls['daily'], 1);
    expect(app.music.calls['personalFm'], 1);
    expect(app.music.calls['hotSearch'], 1);
    expect(app.music.calls['ranks'], 2);
    expect(app.local.scans, 1);
    expect(app.likes.loads, 1);
    expect(app.playlists.userLoads, 1);
    expect(find.byType(Scaffold, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换首页入口后保留搜索输入、结果和选中分类', (tester) async {
    _viewport(tester);
    final app = _App();
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await _tab(tester, '搜索');
    await tester.enterText(find.byType(TextField), '晴天');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('晴天 搜索结果'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, '歌单'));
    await tester.pumpAndSettle();
    expect(find.text('晴天 歌单结果'), findsOneWidget);

    await _tab(tester, '首页');
    await _tab(tester, '发现');
    await _tab(tester, '搜索');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '晴天');
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(find.text('晴天 歌单结果'), findsOneWidget);
    expect(app.music.searched, [('song', '晴天'), ('special', '晴天')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('私人 FM 快捷入口进入发现并在再次访问时重新定位', (tester) async {
    _viewport(tester);
    final app = _App();
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('私人 FM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私人 FM'));
    await tester.pumpAndSettle();
    final fm = find.byType(DiscoverPersonalFmRow);
    final discover = tester.state(find.byType(DiscoverScreen));
    expect(fm, findsOneWidget);
    expect(tester.getTopLeft(fm).dy, inInclusiveRange(0, 300));
    expect(find.widgetWithText(ChoiceChip, '红心').hitTestable(), findsOneWidget);

    final scrollable = find
        .descendant(
          of: find.byKey(const PageStorageKey('discover_feed')),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(fm.hitTestable(), findsNothing);

    await _tab(tester, '首页');
    await tester.ensureVisible(find.text('私人 FM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私人 FM'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(DiscoverScreen)), same(discover));
    expect(tester.getTopLeft(fm).dy, inInclusiveRange(0, 300));
    expect(find.widgetWithText(ChoiceChip, '红心').hitTestable(), findsOneWidget);
    expect(app.music.calls['personalFm'], 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 宽放大字体下首页与私人 FM 无布局溢出', (tester) async {
    _viewport(tester, width: 320);
    final app = _App();
    await tester.pumpWidget(app.build(textScale: 1.5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('私人 FM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私人 FM'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('开启私人 FM'), findsOneWidget);
    for (final label in ['搜索', '资料库', '首页']) {
      await _tab(tester, label);
      expect(tester.takeException(), isNull);
    }
  });
}
