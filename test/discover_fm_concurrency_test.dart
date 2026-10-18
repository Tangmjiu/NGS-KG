// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/album.dart';
import 'package:ngskg_plus/models/playlist.dart';
import 'package:ngskg_plus/models/radio.dart';
import 'package:ngskg_plus/models/rank_entry.dart';
import 'package:ngskg_plus/models/scene_category.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/providers/discover_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/services/music_service.dart';

class _FmRequest {
  final String mode;
  final int pool;
  final String? action;
  final response = Completer<List<Map<String, dynamic>>>();

  _FmRequest(this.mode, this.pool, this.action);

  void complete(int id) => response.complete([
        {'songid': id, 'songname': '歌曲 $id', 'hash': 'hash-$id'},
      ]);
}

class _Service extends Fake implements MusicService {
  final requests = <_FmRequest>[];

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
  }) {
    final request = _FmRequest(mode, songPoolId, action);
    requests.add(request);
    return request.response.future;
  }

  @override
  Future<List<RadioStation>> getFmRecommend() async => [];
  @override
  Future<List<Playlist>> getTopPlaylists(
          {int limit = 200, int offset = 0, int categoryId = 0}) async =>
      [];
  @override
  Future<List<RankEntry>> getRankList() async => [];
  @override
  Future<List<Song>> getTopSongs() async => [];
  @override
  Future<List<Album>> getTopAlbums(
          {int? type, int page = 1, int pageSize = 30}) async =>
      [];
  @override
  Future<List<SceneCategory>> getSceneLists() async => [];
  @override
  Future<List<Map<String, dynamic>>> getTopIp() async => [];
}

class _Player extends ChangeNotifier implements PlayerProvider {
  bool fm = false;
  bool playing = false;
  int _playbackIntentVersion = 0;
  List<Song> songs = [];
  int starts = 0;
  final replacements = <List<Song>>[];

  @override
  bool get isFmMode => fm;
  @override
  bool get isPlaying => playing;
  @override
  int get playbackIntentVersion => _playbackIntentVersion;
  @override
  Song? get currentSong => songs.firstOrNull;
  @override
  List<Song> get playlist => songs;

  @override
  void startFmPlaylist(
    List<Song> songs, {
    required Future<List<Song>> Function() bufferProvider,
    VoidCallback? onDislike,
    void Function(Song song, {int playtime})? onPlaybackUpdate,
  }) {
    _playbackIntentVersion++;
    starts++;
    fm = true;
    playing = true;
    this.songs = songs;
    notifyListeners();
  }

  @override
  void replaceFmPlaylist(
    List<Song> songs, {
    required Future<List<Song>> Function() bufferProvider,
  }) {
    _playbackIntentVersion++;
    replacements.add(songs);
    playing = true;
    this.songs = songs;
    notifyListeners();
  }

  void chooseNormal(int id) {
    _playbackIntentVersion++;
    fm = false;
    playing = true;
    songs = [Song(id: id, name: '普通歌曲 $id', artists: const [])];
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _playbackIntentVersion++;
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _playbackIntentVersion++;
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    _playbackIntentVersion++;
    playing = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Service service;
  late _Player player;
  late DiscoverProvider provider;

  setUp(() {
    service = _Service();
    player = _Player();
    provider = DiscoverProvider(service);
  });

  tearDown(() {
    provider.dispose();
    player.dispose();
  });

  test('连续模式切换只采纳最新结果，旧结果不覆盖队列与缓冲', () async {
    player.fm = true;
    provider.setFmMode('small');
    final old = provider.switchFmPlayback(player);
    provider.setFmMode('peak');
    final latest = provider.switchFmPlayback(player);
    expect(service.requests.map((request) => request.mode), ['small', 'peak']);

    service.requests[1].complete(2);
    await latest;
    service.requests[0].complete(1);
    await old;

    expect(player.replacements, hasLength(1));
    expect(player.currentSong!.id, 2);
    expect(provider.personalFmBuffer, isEmpty);
    expect(provider.isFmActive, isTrue);
  });

  test('FM 请求期间退出 FM，迟到结果不能接管普通播放', () async {
    player.fm = true;
    final pending = provider.switchFmPlayback(player);
    player.chooseNormal(9);
    service.requests.single.complete(1);
    await pending;

    expect(player.currentSong!.id, 9);
    expect(player.replacements, isEmpty);
    expect(provider.personalFmBuffer, isEmpty);
    expect(provider.isFmActive, isFalse);
  });

  test('连续启动共享网络请求且只启动一次播放', () async {
    final first = provider.startFmPlayback(player);
    final second = provider.startFmPlayback(player);
    expect(service.requests, hasLength(1));
    service.requests.single.complete(1);
    await Future.wait([first, second]);

    expect(player.starts, 1);
    expect(player.currentSong!.id, 1);
    expect(provider.isFmActive, isTrue);
    player.chooseNormal(9);
    expect(provider.isFmActive, isFalse);
  });

  test('FM 启动等待期间用户选择新歌曲，不抢回播放', () async {
    player.chooseNormal(8);
    final pending = provider.startFmPlayback(player);
    player.chooseNormal(9);
    service.requests.single.complete(1);
    await pending;

    expect(player.starts, 0);
    expect(player.currentSong!.id, 9);
    expect(provider.isFmActive, isFalse);
  });

  for (final switching in [false, true]) {
    for (final stopping in [false, true]) {
      test(
          'FM ${switching ? '切换' : '启动'}等待期间${stopping ? '停止' : '暂停'}，迟到结果不换队列或恢复播放',
          () async {
        player.chooseNormal(8);
        player.fm = switching;
        final previousSong = player.currentSong;
        final previousQueue = List<Song>.of(player.playlist);
        final pending = switching
            ? provider.switchFmPlayback(player)
            : provider.startFmPlayback(player);

        if (stopping) {
          await player.stop();
        } else {
          await player.pause();
        }
        service.requests.single.complete(1);
        await pending;

        expect(player.currentSong, same(previousSong));
        expect(player.playlist, previousQueue);
        expect(player.isFmMode, switching);
        expect(player.isPlaying, isFalse);
        expect(player.starts, 0);
        expect(player.replacements, isEmpty);
        // 推荐本身仍有效，可供用户下一次明确点播时使用。
        expect(provider.personalFmBuffer.single.id, 1);
      });
    }

    test('FM ${switching ? '切换' : '启动'}等待期间暂停后恢复原歌，旧请求仍不得抢播', () async {
      player.chooseNormal(8);
      player.fm = switching;
      final previousSong = player.currentSong;
      final pending = switching
          ? provider.switchFmPlayback(player)
          : provider.startFmPlayback(player);
      await player.pause();
      await player.play();
      service.requests.single.complete(1);
      await pending;

      expect(player.currentSong, same(previousSong));
      expect(player.isPlaying, isTrue);
      expect(player.isFmMode, switching);
      expect(player.starts, 0);
      expect(player.replacements, isEmpty);
    });
  }

  test('暂停使旧FM启动失效后，再次明确点播可复用缓冲正常播放', () async {
    player.chooseNormal(8);
    final pending = provider.startFmPlayback(player);
    await player.pause();
    service.requests.single.complete(1);
    await pending;
    expect(player.starts, 0);

    await provider.startFmPlayback(player);
    expect(service.requests, hasLength(1));
    expect(player.starts, 1);
    expect(player.currentSong!.id, 1);
    expect(player.isPlaying, isTrue);
    expect(player.isFmMode, isTrue);
    expect(provider.personalFmBuffer, isEmpty);
  });

  test('旧补队列请求作废后，不能取走新推荐池的缓冲', () async {
    final oldBatch = provider.fetchNextFmBatch();
    provider.setFmPoolId(2);
    final replacement = provider.replaceFmBuffer();
    service.requests[1].complete(2);
    await replacement;
    service.requests[0].complete(1);
    expect(await oldBatch, isEmpty);
    expect(provider.personalFmBuffer.single.id, 2);
    expect(service.requests.last.pool, 2);
  });

  test('同时请求下一批共享结果，不重复消耗缓冲', () async {
    final first = provider.fetchNextFmBatch();
    final second = provider.fetchNextFmBatch();
    expect(second, same(first));
    expect(service.requests, hasLength(1));
    service.requests.single.complete(1);
    final result = await first;
    expect(await second, same(result));
    expect(result.single.id, 1);
    expect(provider.personalFmBuffer, isEmpty);
  });

  test('发现页迟到初始化不能覆盖用户选好的新模式', () async {
    final initial = provider.loadAll();
    provider.setFmMode('small');
    final replacement = provider.replaceFmBuffer();
    service.requests[1].complete(2);
    await replacement;
    service.requests[0].complete(1);
    await initial;

    expect(provider.personalFmBuffer.single.id, 2);
    expect(provider.fmMode, 'small');
  });

  test('发现页刷新复用正在进行的补货，不使播放补货失效', () async {
    final batch = provider.fetchNextFmBatch();
    final discovery = provider.loadAll();
    expect(service.requests, hasLength(1));
    service.requests.single.complete(3);
    expect((await batch).single.id, 3);
    await discovery;
  });

  test('旧模式的不喜欢反馈不能污染新推荐池', () async {
    final oldFeedback = provider.dislikeCurrentFmSong(
        const Song(id: 1, name: '旧歌曲', artists: [], hash: 'old'));
    provider.setFmMode('peak');
    final replacement = provider.replaceFmBuffer();
    service.requests[1].complete(2);
    await replacement;
    service.requests[0].complete(3);
    expect(await oldFeedback, isEmpty);
    expect(provider.personalFmBuffer.single.id, 2);
  });

  test('释放提供者后迟到 FM 结果不通知或启动播放', () async {
    final temporary = DiscoverProvider(service);
    final pending = temporary.startFmPlayback(player);
    temporary.dispose();
    service.requests.single.complete(1);
    await pending;
    expect(player.starts, 0);
    expect(temporary.personalFmBuffer, isEmpty);
  });

  test('失败解除在途请求，下一次可以正常重试', () async {
    final first = provider.refreshFmBuffer();
    service.requests.single.response.completeError(StateError('离线'));
    await first;
    final retry = provider.refreshFmBuffer();
    expect(service.requests, hasLength(2));
    service.requests.last.complete(2);
    await retry;
    expect(provider.personalFmBuffer.single.id, 2);
  });
}
