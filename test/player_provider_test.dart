// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/providers/audio_engine.dart';
import 'package:ngskg_plus/providers/audio_settings_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/services/audio_handler.dart';
import 'package:ngskg_plus/services/music_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Engine extends Fake implements AudioEngine {
  @override
  final position = ValueNotifier(Duration.zero);
  @override
  final duration = ValueNotifier(Duration.zero);
  @override
  final isLoading = ValueNotifier(false);
  @override
  final isPlaying = ValueNotifier(false);
  @override
  final error = ValueNotifier<String?>(null);
  @override
  final resolvedQualityNotifier = ValueNotifier<String?>(null);
  @override
  VoidCallback? onComplete;
  @override
  int qualityLevel = 0;
  @override
  bool uploadHistory = true;
  @override
  int crossfadeMs = 0;
  @override
  Duration? startPosition;
  int version = 0;
  int stopCalls = 0;
  final played = <Song>[];

  @override
  int get currentVersion => version;
  @override
  double get speed => 1;
  @override
  bool get needsLoad => true;
  @override
  void clearError() => error.value = null;
  @override
  void setSpeed(double speed) {}
  @override
  void resetForNewSong() {
    version++;
    startPosition = null;
    isLoading.value = true;
    isPlaying.value = false;
  }

  @override
  Future<void> precheckPrivilege(Song song) async {}
  @override
  Future<void> play(Song song, {int? version, String effectKey = 'none'}) async {
    played.add(song);
    isPlaying.value = true;
    isLoading.value = false;
  }

  @override
  Future<void> resume(Song song, {String effectKey = 'none'}) =>
      play(song, effectKey: effectKey);
  @override
  Future<void> pause() async => isPlaying.value = false;
  @override
  Future<void> stop() async {
    version++;
    stopCalls++;
    isPlaying.value = false;
    isLoading.value = false;
  }

  @override
  void dispose() {
    position.dispose();
    duration.dispose();
    isLoading.dispose();
    isPlaying.dispose();
    error.dispose();
    resolvedQualityNotifier.dispose();
  }
}

class _Connectivity extends Fake implements Connectivity {
  final initial = Completer<List<ConnectivityResult>>();
  final changes = StreamController<List<ConnectivityResult>>.broadcast(sync: true);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() => initial.future;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
}

class _MusicService extends Fake implements MusicService {
  int metadataRequests = 0;
  @override
  Future<Map<String, dynamic>?> getKrmAudio(int albumAudioId) async {
    metadataRequests++;
    return null;
  }

  @override
  Future<Map<String, dynamic>> searchLyricByHash(String hash,
          {String? keywords}) async =>
      {};
  @override
  Future<int?> getSongClimax(String hash) async => null;
}

class _Handler extends Fake implements MusicAudioHandler {
  int updates = 0;
  int cancellations = 0;

  @override
  void updateNotification({
    required String id,
    required String title,
    required String artist,
    String? albumArtUrl,
    String? lyricLine,
    required bool isPlaying,
    required int durationSec,
    required int positionSec,
    required bool isBuffering,
    required double speed,
    bool liked = false,
    String playMode = 'sequential',
  }) {
    updates++;
  }

  @override
  void cancelNotification() => cancellations++;
}

// 只跳过测试环境不存在的屏幕唤醒插件，播放器其他释放逻辑保持真实。
class _Player extends PlayerProvider {
  _Player(super.service,
      {required super.audioHandler,
      required super.audioEngine,
      required super.connectivity,
      super.audioSettings,
      super.ready});

  @override
  Future<void> disposeKeepScreenOn() async {}
}

Song _song(int id) => Song(
      id: id,
      name: 'local $id',
      artists: const [],
      filePath: '/local/$id.mp3',
    );

String _savedState() => jsonEncode({
      'songId': 7,
      'queueIndex': 0,
      'positionMs': 23000,
      'durationMs': 180000,
      'queue': [
        {'id': 7, 'name': 'saved', 'hash': 'saved-hash', 'artist': ''},
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Engine engine;
  late _Connectivity connectivity;
  late _MusicService service;
  late _Handler handler;
  _Player? player;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    engine = _Engine();
    connectivity = _Connectivity();
    service = _MusicService();
    handler = _Handler();
    player = null;
  });
  tearDown(() async {
    player?.dispose();
    await connectivity.changes.close();
  });

  _Player create({Future<void>? ready, AudioSettingsProvider? settings}) {
    final result = _Player(service,
        audioHandler: handler,
        audioEngine: engine,
        connectivity: connectivity,
        audioSettings: settings,
        ready: ready);
    player = result;
    return result;
  }

  testWidgets('进度只通知局部通道，歌词仍收到进度且全局 Consumer 不重建', (tester) async {
    final provider = create();
    await tester.pump();
    var globalNotifications = 0;
    var progressNotifications = 0;
    provider.addListener(() => globalNotifications++);
    provider.playbackProgress.addListener(() => progressNotifications++);

    engine.duration.value = const Duration(seconds: 100);
    engine.position.value = const Duration(seconds: 25);
    expect(globalNotifications, 0);
    expect(progressNotifications, 2);
    expect(provider.position, const Duration(seconds: 25));
    expect(provider.playbackProgress.value.position, provider.position);
    expect(provider.playbackProgress.value.duration, provider.duration);

    // 音质不再依赖进度的顺带通知。
    engine.resolvedQualityNotifier.value = 'high';
    expect(globalNotifications, 1);
  });

  testWidgets('网络未确定/蜂窝按蜂窝音质，WiFi事件切换，旧初查不覆盖新事件', (tester) async {
    final settings = AudioSettingsProvider();
    addTearDown(settings.dispose);
    final provider = create(settings: settings);
    await provider.playSong(_song(1));
    expect(engine.qualityLevel, 0);

    connectivity.changes.add([ConnectivityResult.wifi]);
    await provider.playIndex(0);
    expect(engine.qualityLevel, 3);
    connectivity.initial.complete([ConnectivityResult.mobile]);
    await tester.pump();
    await provider.playIndex(0);
    expect(engine.qualityLevel, 3);

    connectivity.changes.add([ConnectivityResult.mobile]);
    await provider.playIndex(0);
    expect(engine.qualityLevel, 0);
    connectivity.changes.addError(StateError('connectivity unavailable'));
    await provider.playIndex(0);
    expect(engine.qualityLevel, 0);

    provider.dispose();
    player = null;
    expect(connectivity.changes.hasListener, isFalse);
  });

  testWidgets('恢复等待ready，不抢先网络请求，完成后只恢复不自动播放', (tester) async {
    SharedPreferences.setMockInitialValues({'playback_state_v2': _savedState()});
    final ready = Completer<void>();
    final provider = create(ready: ready.future);
    await tester.pump();
    expect(provider.currentSong, isNull);
    expect(service.metadataRequests, 0);
    ready.complete();
    // 恢复要依次经过 ready、SharedPreferences、队列解析多次异步跳转，
    // 单次 pump 不足以跑完。
    for (var i = 0; i < 10 && provider.currentSong == null; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(provider.currentSong?.id, 7);
    expect(provider.position, const Duration(seconds: 23));
    expect(provider.playbackProgress.value.position, provider.position);
    expect(service.metadataRequests, 1);
    expect(engine.played, isEmpty);
  });

  testWidgets('等待ready时用户选新队列，迟到恢复不会覆盖它', (tester) async {
    SharedPreferences.setMockInitialValues({'playback_state_v2': _savedState()});
    final ready = Completer<void>();
    final provider = create(ready: ready.future);
    await tester.pump();
    await provider.playSong(_song(1));
    ready.complete();
    await tester.pump();
    expect(provider.currentSong?.id, 1);
    expect(service.metadataRequests, 0);
  });

  testWidgets('ready到达前销毁不会启动恢复网络或通知已销毁对象', (tester) async {
    SharedPreferences.setMockInitialValues({'playback_state_v2': _savedState()});
    final ready = Completer<void>();
    final provider = create(ready: ready.future);
    await tester.pump();
    provider.dispose();
    player = null;
    ready.complete();
    await tester.pump();
    expect(service.metadataRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧FM补队列结果不污染手动选择的新普通队列', (tester) async {
    final provider = create();
    final pending = Completer<List<Song>>();
    provider.startFmPlaylist([_song(1)], bufferProvider: () => pending.future);
    await tester.pump();
    provider.playNext();
    expect(provider.isLoadingMore, isTrue);
    await provider.playSong(_song(2));
    expect(provider.isLoadingMore, isFalse);
    final count = engine.played.length;
    pending.complete([_song(3)]);
    await tester.pump();
    expect(provider.isFmMode, isFalse);
    expect(provider.playlist.map((s) => s.id), [2]);
    expect(engine.played, hasLength(count));
  });

  testWidgets('旧FM请求结束不会清掉新FM请求loading，新批次只播放一次', (tester) async {
    final provider = create();
    final old = Completer<List<Song>>();
    final fresh = Completer<List<Song>>();
    provider.startFmPlaylist([_song(1)], bufferProvider: () => old.future);
    await tester.pump();
    provider.playNext();
    provider.replaceFmPlaylist([_song(2)], bufferProvider: () => fresh.future);
    await tester.pump();
    provider.playNext();
    old.complete([_song(3)]);
    await tester.pump();
    expect(provider.isLoadingMore, isTrue);
    expect(provider.playlist.map((s) => s.id), [2]);
    fresh.complete([_song(4)]);
    await tester.pump();
    expect(provider.isLoadingMore, isFalse);
    expect(provider.currentSong?.id, 4);
    expect(provider.playlist.map((s) => s.id), [2, 4]);
    expect(engine.played.where((s) => s.id == 4), hasLength(1));
  });

  testWidgets('系统stop后直接切歌会恢复媒体通知', (tester) async {
    final provider = create();
    await provider.playSong(_song(1));
    await provider.stop();
    final count = handler.updates;
    await provider.playSong(_song(2));
    expect(handler.updates, greaterThan(count));
  });

  testWidgets('删除最后一首会停止音源并撤下通知', (tester) async {
    final provider = create();
    await provider.playSong(_song(1));
    provider.removeFromQueue(0);
    expect(provider.currentSong, isNull);
    expect(provider.isPlaying, isFalse);
    expect(engine.stopCalls, 1);
    expect(handler.cancellations, greaterThan(0));
  });

  testWidgets('持久化200首窗口包含当前歌曲，song和queue快照保持一致', (tester) async {
    final provider = create();
    final songs = List.generate(260, _song);
    provider.setPlaylist(songs, startIndex: 230);
    provider.setPlaylist(songs, startIndex: 240);
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    final state = jsonDecode(prefs.getString('playback_state_v2')!) as Map;
    final queue = state['queue'] as List;
    expect(queue.length, lessThanOrEqualTo(200));
    expect(state['songId'], 240);
    expect(queue[state['queueIndex'] as int]['id'], 240);
  });
}
