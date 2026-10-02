// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/playlist.dart';
import 'package:ngskg_plus/models/rank_entry.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/models/user.dart';
import 'package:ngskg_plus/models/vip_info.dart';
import 'package:ngskg_plus/navidrome/navidrome_provider.dart';
import 'package:ngskg_plus/providers/auth_provider.dart';
import 'package:ngskg_plus/providers/liked_songs_provider.dart';
import 'package:ngskg_plus/providers/local_music_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/providers/playlist_provider.dart';
import 'package:ngskg_plus/screens/local_music_screen.dart';
import 'package:ngskg_plus/screens/profile_screen.dart';
import 'package:ngskg_plus/screens/search_screen.dart';
import 'package:ngskg_plus/services/music_service.dart';
import 'package:ngskg_plus/widgets/playlist_card.dart';
import 'package:provider/provider.dart';

class _Player extends ChangeNotifier implements PlayerProvider {
  Song? song;
  bool playing = false;

  @override
  Song? get currentSong => song;
  @override
  bool get isPlaying => playing;
  @override
  bool get isPlayerScreenVisible => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LikedSongs extends ChangeNotifier implements LikedSongsProvider {
  @override
  Set<int> get likedIds => {};
  @override
  Future<void> load({bool force = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request {
  final String type;
  final String keyword;
  final Completer<List<Song>> songs = Completer<List<Song>>();
  final Completer<List<Map<String, dynamic>>> maps =
      Completer<List<Map<String, dynamic>>>();

  _Request(this.type, this.keyword);

  void complete(String label) {
    if (type == 'song') {
      songs.complete([Song(id: label.hashCode, name: label, artists: const [])]);
    } else {
      maps.complete([
        {
          'name': label,
          'specialname': label,
          'albumname': label,
          'AuthorName': label,
          'SongName': label,
        },
      ]);
    }
  }
}

class _MusicService implements MusicService {
  final requests = <_Request>[];
  final suggestions = <Completer<List<String>>>[];

  Future<List<Map<String, dynamic>>> _maps(String type, String keyword) {
    final request = _Request(type, keyword);
    requests.add(request);
    return request.maps.future;
  }

  @override
  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0, String type = 'song'}) {
    final request = _Request(type, keyword);
    requests.add(request);
    return request.songs.future;
  }

  @override
  Future<List<Map<String, dynamic>>> searchPlaylists(String keyword,
          {int limit = 30, int offset = 0}) =>
      _maps('special', keyword);
  @override
  Future<List<Map<String, dynamic>>> searchAlbums(String keyword,
          {int limit = 30, int offset = 0}) =>
      _maps('album', keyword);
  @override
  Future<List<Map<String, dynamic>>> searchArtists(String keyword,
          {int limit = 30, int offset = 0}) =>
      _maps('author', keyword);
  @override
  Future<List<Map<String, dynamic>>> searchLyrics(String keyword,
          {int limit = 30, int offset = 0}) =>
      _maps('lyric', keyword);
  @override
  Future<List<String>> getSearchSuggest(String keyword) {
    final completer = Completer<List<String>>();
    suggestions.add(completer);
    return completer.future;
  }

  @override
  Future<List<Map<String, dynamic>>> getHotSearch() async => [];
  @override
  Future<List<RankEntry>> getRankList() async => [];
  @override
  Future<VipInfo?> getVipInfo() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalMusic extends ChangeNotifier implements LocalMusicProvider {
  final List<Song> _songs = List.generate(5000, (index) => Song(
        id: index,
        name: '本地歌曲$index',
        artists: const ['歌手'],
        albumName: '测试专辑',
        filePath: '/music/$index.mp3',
      ));
  final List<int> groupCalls = [0, 0, 0];
  int statusReads = 0;

  @override
  List<Song> get songs => _songs;
  @override
  bool get isScanning => false;
  @override
  bool get scanned => true;
  @override
  String get status {
    statusReads++;
    return '';
  }
  @override
  String get sortField => 'title';
  @override
  bool get sortAscending => true;
  @override
  String? get highlightedFilePath => null;
  @override
  Future<void> scanMusic({bool forceFull = false}) async {}

  List<LocalGroupEntry> _group(int index, String title) {
    groupCalls[index]++;
    return [LocalGroupEntry(title: title, count: _songs.length, songs: _songs)];
  }

  @override
  List<LocalGroupEntry> groupedByAlbum() => _group(0, '测试专辑');
  @override
  List<LocalGroupEntry> groupedByArtist() => _group(1, '歌手');
  @override
  List<LocalGroupEntry> groupedByFolder() => _group(2, 'music');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Navidrome extends ChangeNotifier implements NavidromeProvider {
  @override
  bool get connected => false;
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

class _Playlists extends ChangeNotifier implements PlaylistProvider {
  final List<Playlist> _playlists = List.generate(1000, (index) => Playlist(
        id: index + 10,
        name: '歌单$index',
        createUserId: index < 500 ? 1 : 2,
      ));
  @override
  bool get isLoading => false;
  @override
  List<Playlist> get userPlaylists => _playlists;
  @override
  Future<void> fetchUserPlaylist(int? userId, {bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _submit(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byType(TextField).first, keyword);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> _selectTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Widget _searchApp(_MusicService music) => MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerProvider>(create: (_) => _Player()),
        ChangeNotifierProvider<LikedSongsProvider>(create: (_) => _LikedSongs()),
      ],
      child: MaterialApp(home: SearchScreen(musicService: music)),
    );

void main() {
  testWidgets('切换搜索标签只请求一次，重复点击当前标签不请求', (tester) async {
    final music = _MusicService();
    await tester.pumpWidget(_searchApp(music));
    await _submit(tester, 'test');
    music.requests.single.complete('首个结果');
    await tester.pumpAndSettle();

    await _selectTab(tester, '歌单');
    expect(music.requests.where((r) => r.type == 'special').length, 1);
    music.requests.last.complete('歌单结果');
    await tester.pumpAndSettle();
    await _selectTab(tester, '歌单');
    expect(music.requests.length, 2);
  });

  const tabs = ['单曲', '歌单', '专辑', '歌手', '歌词'];
  for (var index = 0; index < tabs.length; index++) {
    testWidgets('${tabs[index]}乱序响应不会覆盖最新关键词', (tester) async {
      final music = _MusicService();
      await tester.pumpWidget(_searchApp(music));
      await _submit(tester, 'initial');
      music.requests.last.complete('初始结果');
      await tester.pumpAndSettle();
      if (index > 0) {
        await _selectTab(tester, tabs[index]);
        music.requests.last.complete('分类初始结果');
        await tester.pumpAndSettle();
      }

      await _submit(tester, 'older');
      final older = music.requests.last;
      await _submit(tester, 'newer');
      final newer = music.requests.last;
      newer.complete('新结果');
      await tester.pumpAndSettle();
      older.complete('旧结果');
      await tester.pumpAndSettle();
      expect(find.text('新结果'), findsOneWidget);
      expect(find.text('旧结果'), findsNothing);
    });
  }

  testWidgets('建议乱序或清空输入后不再发布旧建议', (tester) async {
    final music = _MusicService();
    await tester.pumpWidget(_searchApp(music));
    await tester.enterText(find.byType(TextField), 'older');
    await tester.pump(const Duration(milliseconds: 401));
    await tester.enterText(find.byType(TextField), 'newer');
    await tester.pump(const Duration(milliseconds: 401));
    music.suggestions[1].complete(['新建议']);
    await tester.pumpAndSettle();
    music.suggestions[0].complete(['旧建议']);
    await tester.pumpAndSettle();
    expect(find.text('新建议'), findsOneWidget);
    expect(find.text('旧建议'), findsNothing);

    await tester.enterText(find.byType(TextField), 'clear');
    await tester.pump(const Duration(milliseconds: 401));
    await tester.enterText(find.byType(TextField), '');
    music.suggestions[2].complete(['清空后的旧建议']);
    await tester.pumpAndSettle();
    expect(find.text('清空后的旧建议'), findsNothing);
  });

  testWidgets('大本地分组懒构建，播放通知不会重建页面或重新分组', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final local = _LocalMusic();
    final player = _Player();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalMusicProvider>.value(value: local),
        ChangeNotifierProvider<PlayerProvider>.value(value: player),
        ChangeNotifierProvider<NavidromeProvider>(create: (_) => _Navidrome()),
      ],
      child: const MaterialApp(home: LocalMusicScreen()),
    ));
    await tester.pumpAndSettle();
    expect(local.groupCalls, [0, 0, 0]);
    await tester.tap(find.widgetWithText(Tab, '专辑'));
    await tester.pumpAndSettle();
    expect(local.groupCalls[0], greaterThan(0));
    expect(local.groupCalls.skip(1), everyElement(0));
    await tester.tap(find.text('测试专辑'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile).evaluate().length, lessThan(40));
    expect(find.text('本地歌曲4999'), findsNothing);
    final calls = List<int>.of(local.groupCalls);
    final statusReads = local.statusReads;
    for (var i = 0; i < 5; i++) {
      player.notifyListeners();
      await tester.pump();
    }
    expect(local.groupCalls, calls);
    expect(local.statusReads, statusReads);
    player.song = Song(id: -999, name: '重扫后歌曲', artists: const [],
        filePath: local.songs.first.filePath);
    player.playing = true;
    player.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.equalizer), findsOneWidget);
    expect(local.statusReads, statusReads);
    await tester.pumpWidget(const SizedBox.shrink());
    player.dispose();
    local.dispose();
  });

  testWidgets('个人页千条歌单只构建可见项', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
        ChangeNotifierProvider<PlaylistProvider>(create: (_) => _Playlists()),
        ChangeNotifierProvider<LocalMusicProvider>(create: (_) => _LocalMusic()),
        ChangeNotifierProvider<LikedSongsProvider>(create: (_) => _LikedSongs()),
        ChangeNotifierProvider<PlayerProvider>(create: (_) => _Player()),
      ],
      child: MaterialApp(home: Scaffold(body: ProfileScreen(musicService: _MusicService()))),
    ));
    await tester.pumpAndSettle();
    final scroll = find.byType(CustomScrollView);
    await tester.drag(scroll, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistCard).evaluate().length, inExclusiveRange(0, 30));
    expect(find.text('歌单999'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
