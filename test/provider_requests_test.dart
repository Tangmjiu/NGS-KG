// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/album.dart';
import 'package:ngskg_plus/models/playlist.dart';
import 'package:ngskg_plus/models/radio.dart';
import 'package:ngskg_plus/models/rank_entry.dart';
import 'package:ngskg_plus/models/scene_category.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/providers/discover_provider.dart';
import 'package:ngskg_plus/providers/liked_songs_provider.dart';
import 'package:ngskg_plus/providers/local_music_provider.dart';
import 'package:ngskg_plus/providers/playlist_provider.dart';
import 'package:ngskg_plus/services/api_client.dart';
import 'package:ngskg_plus/services/local_music_service.dart';
import 'package:ngskg_plus/services/music_service.dart';

// 不构造真实 MusicService/ApiClient，不执行网络或平台数据库调用。
class _FakeMusicService implements MusicService {
  final playlistRequests = <Completer<List<Playlist>>>[];
  final likedRequests = <Completer<List<Song>>>[];
  final addRequests = <Completer<Map<String, dynamic>>>[];
  final removeRequests = <Completer<Map<String, dynamic>>>[];
  final discoverCalls = <String, int>{};
  Completer<void>? discoverGate;
  bool failDiscovery = false;

  @override
  Future<List<Playlist>> getUserPlaylist(
      {int? userId, int page = 1, int pageSize = 200}) {
    final request = Completer<List<Playlist>>();
    playlistRequests.add(request);
    return request.future;
  }

  @override
  Future<List<Song>> getPlaylistTracksNew(int listid,
      {int page = 1, int pageSize = 30}) {
    final request = Completer<List<Song>>();
    likedRequests.add(request);
    return request.future;
  }

  @override
  Future<List<Song>> getPlaylistTracksById(int listid,
      {int page = 1, int pageSize = 30}) async => [];

  @override
  Future<Map<String, dynamic>> addTracksToPlaylist(int listid, String data) {
    final request = Completer<Map<String, dynamic>>();
    addRequests.add(request);
    return request.future;
  }

  @override
  Future<Map<String, dynamic>> removeTracksFromPlaylist(int listid, String fileids) {
    final request = Completer<Map<String, dynamic>>();
    removeRequests.add(request);
    return request.future;
  }

  Future<List<T>> _discover<T>(String section) async {
    discoverCalls.update(section, (count) => count + 1, ifAbsent: () => 1);
    final gate = discoverGate;
    if (gate != null) await gate.future;
    if (failDiscovery) throw StateError('离线');
    return <T>[];
  }

  @override
  Future<List<RadioStation>> getFmRecommend() => _discover('fm');

  @override
  Future<List<Playlist>> getTopPlaylists(
          {int limit = 200, int offset = 0, int categoryId = 0}) =>
      _discover('playlists');

  @override
  Future<List<RankEntry>> getRankList() => _discover('ranks');

  @override
  Future<List<Song>> getTopSongs() => _discover('songs');

  @override
  Future<List<Album>> getTopAlbums(
          {int? type, int page = 1, int pageSize = 30}) =>
      _discover('albums');

  @override
  Future<List<SceneCategory>> getSceneLists() => _discover('scenes');

  @override
  Future<List<Map<String, dynamic>>> getTopIp() => _discover('ip');

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
  }) => _discover('personalFm');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocalMusicService extends LocalMusicService {
  List<Song> result = [];

  @override
  Future<List<Song>> scanMusic({bool forceFull = false}) async => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ApiClient.setAuth('test-token', '1'));
  tearDown(ApiClient.clearAuth);

  group('用户歌单并发去重', () {
    test('普通并发请求共享 Future，完成后再次调用可刷新', () async {
      final service = _FakeMusicService();
      final provider = PlaylistProvider(service);
      addTearDown(provider.dispose);
      final first = provider.fetchUserPlaylist(1);
      final second = provider.fetchUserPlaylist(1);
      expect(second, same(first));
      expect(service.playlistRequests, hasLength(1));
      expect(provider.isLoading, isTrue);
      service.playlistRequests.single.complete([
        const Playlist(id: 1, name: '歌单'),
      ]);
      await Future.wait([first, second]);
      expect(provider.isLoading, isFalse);
      final refresh = provider.fetchUserPlaylist(1);
      expect(service.playlistRequests, hasLength(2));
      service.playlistRequests.last.complete([]);
      await refresh;
      expect(provider.userPlaylists, isEmpty);
    });

    test('force 不复用旧请求，迟到结果不覆盖更新结果', () async {
      final service = _FakeMusicService();
      final provider = PlaylistProvider(service);
      addTearDown(provider.dispose);
      final old = provider.fetchUserPlaylist(1);
      final latest = provider.fetchUserPlaylist(1, force: true);
      expect(service.playlistRequests, hasLength(2));
      service.playlistRequests[1].complete([
        const Playlist(id: 2, name: '新歌单'),
      ]);
      await latest;
      service.playlistRequests[0].complete([
        const Playlist(id: 1, name: '旧歌单'),
      ]);
      await old;
      expect(provider.userPlaylists.single.id, 2);
      expect(provider.isLoading, isFalse);
    });

    test('账号切换时请求独立，失败后可手动重试', () async {
      final service = _FakeMusicService();
      final provider = PlaylistProvider(service);
      addTearDown(provider.dispose);
      final firstUser = provider.fetchUserPlaylist(1);
      ApiClient.setAuth('other-token', '2');
      final secondUser = provider.fetchUserPlaylist(2);
      service.playlistRequests[0].complete([
        const Playlist(id: 1, name: '旧账号'),
      ]);
      await firstUser;
      expect(provider.userPlaylists, isEmpty);
      expect(provider.isLoading, isTrue);
      service.playlistRequests[1].completeError(StateError('离线'));
      await secondUser;
      expect(provider.isLoading, isFalse);
      final retry = provider.fetchUserPlaylist(2);
      service.playlistRequests.last.complete([
        const Playlist(id: 2, name: '当前账号'),
      ]);
      await retry;
      expect(provider.userPlaylists.single.id, 2);
    });
  });

  group('收藏列表请求去重', () {
    testWidgets('显式初始化和延迟初始化不重复请求', (tester) async {
      final service = _FakeMusicService();
      final provider = LikedSongsProvider(service);
      addTearDown(provider.dispose);
      final first = provider.load();
      final second = provider.load();
      expect(second, same(first));
      await tester.pump(const Duration(seconds: 1));
      expect(service.likedRequests, hasLength(1));
      service.likedRequests.single.complete([
        const Song(id: 1, name: '收藏', artists: []),
      ]);
      await tester.pump();
      await first;
      expect(provider.isLoaded, isTrue);
    });

    test('force 请求较新快照，退出登录后不回填收藏', () async {
      final service = _FakeMusicService();
      final provider = LikedSongsProvider(service);
      addTearDown(provider.dispose);
      final old = provider.load();
      final latest = provider.load(force: true);
      service.likedRequests[1].complete([
        const Song(id: 2, name: '新收藏', artists: []),
      ]);
      await latest;
      service.likedRequests[0].complete([
        const Song(id: 1, name: '旧收藏', artists: []),
      ]);
      await old;
      expect(provider.likedIds, {2});

      final pending = provider.load();
      ApiClient.clearAuth();
      provider.clear();
      service.likedRequests.last.complete([
        const Song(id: 3, name: '迟到收藏', artists: []),
      ]);
      await pending;
      expect(provider.songs, isEmpty);
      expect(provider.isLoaded, isFalse);
    });

    for (final staleIncludesRemoved in [false, true]) {
      test('并发喜欢 B/取消 A 保留 B（旧快照含 A: $staleIncludesRemoved）', () async {
        final service = _FakeMusicService();
        final provider = LikedSongsProvider(service);
        addTearDown(provider.dispose);
        const songA = Song(id: 1, name: 'A', artists: [], fileId: 11);
        const songB = Song(id: 2, name: 'B', artists: [], fileId: 22);
        final initial = provider.load();
        service.likedRequests.single.complete([songA]);
        await initial;

        final likeB = provider.toggle(const SongInfo(id: 2, name: 'B'));
        service.addRequests.single.complete({});
        await Future<void>.value();
        expect(service.likedRequests, hasLength(2));
        final unlikeA = provider.toggle(const SongInfo(id: 1, name: 'A'));
        service.removeRequests.single.complete({});
        await Future<void>.value();
        final hadReplacement = service.likedRequests.length == 3;
        service.likedRequests[1].complete([
          if (staleIncludesRemoved) songA,
          songB,
        ]);
        if (hadReplacement) service.likedRequests[2].complete([songB]);
        expect(await likeB, isTrue);
        expect(await unlikeA, isTrue);
        expect(hadReplacement, isTrue);
        expect(provider.songs.map((song) => song.id), [2]);
        expect(provider.likedIds, {2});
        expect(provider.isLoaded, isTrue);
      });
    }

    testWidgets('dispose 取消初始化定时器', (tester) async {
      final service = _FakeMusicService();
      final provider = LikedSongsProvider(service);
      provider.dispose();
      await tester.pump(const Duration(seconds: 8));
      expect(service.likedRequests, isEmpty);
    });
  });

  group('发现页初始化和手动刷新', () {
    test('并发加载共享八个请求，空 FM 不再次自动加载', () async {
      final service = _FakeMusicService()..discoverGate = Completer<void>();
      final provider = DiscoverProvider(service);
      addTearDown(provider.dispose);
      final first = provider.loadAll();
      final second = provider.ensureLoaded();
      expect(second, same(first));
      expect(service.discoverCalls, hasLength(8));
      expect(service.discoverCalls.values, everyElement(1));
      service.discoverGate!.complete();
      await first;
      expect(provider.loading, isFalse);
      expect(provider.personalFmSongs, isEmpty);
      await provider.ensureLoaded();
      expect(service.discoverCalls.values, everyElement(1));
      await provider.loadAll();
      expect(service.discoverCalls.values, everyElement(2));
    });

    test('失败后停止 loading，不自动重试，允许显式刷新', () async {
      final service = _FakeMusicService()..failDiscovery = true;
      final provider = DiscoverProvider(service);
      addTearDown(provider.dispose);
      await provider.ensureLoaded();
      expect(provider.loading, isFalse);
      await provider.ensureLoaded();
      expect(service.discoverCalls.values, everyElement(1));
      service.failDiscovery = false;
      await provider.loadAll();
      expect(provider.loading, isFalse);
      expect(service.discoverCalls.values, everyElement(2));
    });
  });

  test('本地分组按曲库版本复用，搜索不失效，删除和扫描失效', () async {
    final service = _FakeLocalMusicService()
      ..result = [
        Song.fromLocal(title: 'B', artist: '歌手', album: '专辑', filePath: '/music/b.mp3'),
        Song.fromLocal(title: 'A', artist: '歌手', album: '专辑', filePath: '/music/a.mp3'),
      ];
    final provider = LocalMusicProvider(service: service);
    addTearDown(provider.dispose);
    await provider.scanMusic();
    final albums = provider.groupedByAlbum();
    final artists = provider.groupedByArtist();
    final folders = provider.groupedByFolder();
    expect(provider.groupedByAlbum(), same(albums));
    expect(provider.groupedByArtist(), same(artists));
    expect(provider.groupedByFolder(), same(folders));
    provider.search('A');
    expect(provider.songs, hasLength(1));
    expect(provider.groupedByAlbum(), same(albums));
    expect(albums.single.count, 2);
    await provider.removeSong(service.result.first);
    expect(provider.groupedByAlbum(), isNot(same(albums)));
    expect(provider.groupedByAlbum().single.count, 1);
    final beforeScan = provider.groupedByAlbum();
    await provider.scanMusic();
    expect(provider.groupedByAlbum(), isNot(same(beforeScan)));
    expect(provider.groupedByAlbum().single.count, 2);
  });
}
