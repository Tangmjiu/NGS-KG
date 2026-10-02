// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/providers/audio_engine.dart';
import 'package:ngskg_plus/services/music_service.dart';

class _AudioPlayer extends Fake implements AudioPlayer {
  bool _playing = false;

  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<ProcessingState> get processingStateStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<int?> get androidAudioSessionIdStream => const Stream.empty();
  @override
  bool get playing => _playing;
  @override
  Future<Duration?> setUrl(String url,
          {Map<String, String>? headers,
          Duration? initialPosition,
          bool preload = true,
          dynamic tag}) async =>
      const Duration(minutes: 3);
  @override
  Future<void> play() async => _playing = true;
  @override
  Future<void> stop() async => _playing = false;
  @override
  Future<void> dispose() async {}
}

class _MusicService extends Fake implements MusicService {
  final requests = <String, List<Completer<Map<String, dynamic>>>>{};
  final urlRequests = <String, Completer<SongUrl>>{};
  bool holdUrls = false;

  @override
  Future<Map<String, dynamic>> getPrivilegeLite(String hash) {
    final request = Completer<Map<String, dynamic>>();
    requests.putIfAbsent(hash, () => []).add(request);
    return request.future;
  }

  @override
  Future<SongUrl> getSongUrl(int songId, {String? hash, String? quality}) {
    if (holdUrls) {
      return urlRequests.putIfAbsent(hash!, Completer<SongUrl>.new).future;
    }
    return Future.value(SongUrl(id: songId, url: 'https://test.invalid/audio', type: 'mp3'));
  }
}

Map<String, dynamic> _privilege(String hash, {String quality = '128'}) => {
      'data': [
        {'hash': hash, 'quality': quality, 'level': 1},
      ],
    };

const _songA = Song(id: 1, name: 'A', artists: [], hash: 'A');
const _songB = Song(id: 2, name: 'B', artists: [], hash: 'B');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MusicService service;
  late AudioEngine engine;

  setUp(() {
    service = _MusicService();
    engine = AudioEngine(service, player: _AudioPlayer(), initializeSession: false);
  });
  tearDown(() => engine.dispose());

  test('预查与播放并发时共享一次 privilege 请求', () async {
    engine.resetForNewSong();
    final precheck = engine.precheckPrivilege(_songA);
    final playback = engine.play(_songA);
    expect(service.requests['A'], hasLength(1));
    service.requests['A']!.single.complete(_privilege('A'));
    await Future.wait([precheck, playback]);
    expect(engine.isLoading.value, isFalse);
    expect(engine.resolvedQuality, '128');
    await engine.precheckPrivilege(_songA);
    expect(service.requests['A'], hasLength(1));
  });

  test('查询失败后回收 in-flight，下一次允许重试', () async {
    final first = engine.precheckPrivilege(_songA);
    final shared = engine.precheckPrivilege(_songA);
    service.requests['A']!.single.completeError(StateError('offline'));
    await Future.wait([first, shared]);

    final retry = engine.precheckPrivilege(_songA);
    expect(service.requests['A'], hasLength(2));
    service.requests['A']!.last.complete(_privilege('A'));
    await retry;
  });

  test('失效前的迟到请求不能覆盖新缓存或移除新 in-flight', () async {
    final old = engine.precheckPrivilege(_songA);
    engine.invalidatePrivilege('A');
    final fresh = engine.precheckPrivilege(_songA);
    service.requests['A']!.first.complete(_privilege('old', quality: 'high'));
    await old;
    final shared = engine.precheckPrivilege(_songA);
    expect(service.requests['A'], hasLength(2));
    service.requests['A']!.last.complete(_privilege('fresh'));
    await Future.wait([fresh, shared]);
    await engine.precheckPrivilege(_songA);
    expect(engine.currentQualityOptions.single.hash, 'fresh');
    expect(service.requests['A'], hasLength(2));
  });

  test('全量失效后旧请求不能重新写入缓存', () async {
    final old = engine.precheckPrivilege(_songA);
    engine.clearPrivilegeCache();
    service.requests['A']!.single.complete(_privilege('old'));
    await old;
    final fresh = engine.precheckPrivilege(_songA);
    expect(service.requests['A'], hasLength(2));
    service.requests['A']!.last.complete(_privilege('fresh'));
    await fresh;
  });

  test('切歌后旧 privilege 不得覆盖新歌选项或关闭 loading', () async {
    engine.resetForNewSong();
    final oldPrecheck = engine.precheckPrivilege(_songA);
    final oldPlayback = engine.play(_songA);
    engine.resetForNewSong();
    final freshPrecheck = engine.precheckPrivilege(_songB);
    service.requests['B']!.single.complete(_privilege('B', quality: 'high'));
    await freshPrecheck;
    service.requests['A']!.single.complete(_privilege('A'));
    await Future.wait([oldPrecheck, oldPlayback]);
    expect(engine.isLoading.value, isTrue);
    expect(engine.currentQualityOptions.single.hash, 'B');
    expect(service.urlRequests, isEmpty);
  });

  test('切歌后旧 URL 请求结束不能复位新请求 loading', () async {
    service.holdUrls = true;
    final precheck = engine.precheckPrivilege(_songA);
    service.requests['A']!.single.complete(_privilege('A'));
    await precheck;
    engine.resetForNewSong();
    final old = engine.play(_songA);
    await Future<void>.delayed(Duration.zero);
    expect(service.urlRequests, contains('A'));

    engine.resetForNewSong();
    service.urlRequests['A']!.complete(
        const SongUrl(id: 1, url: 'https://test.invalid/old', type: 'mp3'));
    await old;
    expect(engine.isLoading.value, isTrue);
    expect(engine.resolvedQuality, isNull);
  });

  test('销毁后迟到的 privilege 不会通知已销毁 notifier', () async {
    final pending = engine.precheckPrivilege(_songA);
    engine.dispose();
    // 避免 tearDown 重复释放已销毁 notifier。
    engine = AudioEngine(service, player: _AudioPlayer(), initializeSession: false);
    service.requests['A']!.single.complete(_privilege('A'));
    await pending;
  });
}
