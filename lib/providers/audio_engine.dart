import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../utils/error_dialog.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import '../services/music_service.dart';
import '../services/api_exception.dart';

class AudioEngine {
  final MusicService _musicService;
  final AudioPlayer _player = AudioPlayer();

  int _playAttempts = 0;
  int _playRequestVersion = 0;
  DateTime? _lastUrlFetchTime;

  static const int _maxRetries = 2;
  static const _urlStaleDuration = Duration(minutes: 10);
  int qualityLevel = 0;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _processingStateSub;
  StreamSubscription? _playbackSub;
  bool _hasActivePlayback = false;

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);
  final ValueNotifier<bool> isCompleting = ValueNotifier(false);

  VoidCallback? onComplete;
  VoidCallback? onReady;

  AudioEngine(this._musicService) {
    _initSession();
    _positionSub = _player.positionStream.listen((p) {
      position.value = p;
    });
    _durationSub = _player.durationStream.listen((d) {
      if (d != null) duration.value = d;
    });
    _processingStateSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (!isCompleting.value) {
          isCompleting.value = true;
          onComplete?.call();
        }
      } else if (state == ProcessingState.ready) {
        isCompleting.value = false;
        onReady?.call();
      } else if (state == ProcessingState.idle) {
        if (_hasActivePlayback) {
          _hasActivePlayback = false;
          isLoading.value = false;
          error.value = '播放出错，请重试';
        }
      }
    });
    _playbackSub = _player.playbackEventStream.listen((event) {
      isPlaying.value = _player.playing;
    });
  }

  void _initSession() {
    AudioSession.instance.then((session) => session.configure(const AudioSessionConfiguration(
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ))).catchError((e) {
      Log.e('audio_engine', 'AudioSession init failed', e);
    });
  }

  int get requestVersion => _playRequestVersion;

  double get progress {
    final d = duration.value.inMilliseconds;
    return d > 0 ? position.value.inMilliseconds / d : 0.0;
  }

  int get currentVersion => _playRequestVersion;
  bool get isPlaying_ => _player.playing;

  Future<void> play(Song song, {int? version}) async {
    version ??= _playRequestVersion;
    if (version != _playRequestVersion) {
      isLoading.value = false;
      return;
    }
    if (_playAttempts > _maxRetries) {
      isLoading.value = false;
      error.value = '播放失败: 已重试 $_maxRetries 次';
      return;
    }
    try {
      // Direct filePath URL (cloud disk, etc.)
      if (song.filePath != null && song.filePath!.isNotEmpty) {
        final fp = song.filePath!;
        if (fp.startsWith('http') || fp.startsWith('https')) {
          await _player.setUrl(fp);
          if (version != _playRequestVersion) { isLoading.value = false; return; }
          _lastUrlFetchTime = DateTime.now();
          await _player.play();
          _hasActivePlayback = true;
        } else {
          await _player.setFilePath(fp);
          if (version != _playRequestVersion) { isLoading.value = false; return; }
          await _player.play();
          _hasActivePlayback = true;
        }
      } else {
        final qualities = _qualityFallbackChain(qualityLevel);
        bool played = false;
        for (var qi = 0; qi < qualities.length && !played; qi++) {
          final quality = qualities[qi];
          final songUrl = await _musicService.getSongUrl(song.id,
              hash: song.hash, quality: quality);
          if (version != _playRequestVersion) { isLoading.value = false; return; }
          if (songUrl.url.isNotEmpty) {
            await _player.setUrl(songUrl.url);
            if (version != _playRequestVersion) { isLoading.value = false; return; }
            _lastUrlFetchTime = DateTime.now();
            await _player.play();
            _hasActivePlayback = true;
            _musicService.uploadPlayHistory(song.id, duration: song.duration).catchError((_) {});
            played = true;
          }
        }
        if (!played) {
          _playAttempts++;
          await play(song, version: version);
          return;
        }
      }
    } catch (e, s) {
      _playAttempts++;
      Log.w('audio_engine', 'play error (attempt $_playAttempts)', e, s);
      if (e is NoCopyrightException) {
        isLoading.value = false;
        error.value = '播放失败: $e';
        showErrorDialog(title: '播放失败', errorCode: 'API 3', message: '$e');
        return;
      }
      if (e is NeedLoginException) {
        isLoading.value = false;
        error.value = '播放失败: $e';
        showErrorDialog(title: '登录失效', errorCode: 'API 20010', message: '播放需要重新登录', showLogin: true);
        return;
      }
      if (_playAttempts <= _maxRetries) {
        await play(song, version: version);
        return;
      }
      isLoading.value = false;
      error.value = '播放失败: $e';
      Log.e('audio_engine', '', e, s);
      return;
    }
    isLoading.value = false;
  }

  Future<void> togglePlayPause(Song? currentSong) async {
    if (currentSong == null) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (position.value == Duration.zero || position.value >= duration.value) {
        error.value = null;
        isLoading.value = true;
        _playRequestVersion++;
        _playAttempts = 0;
        await play(currentSong);
      } else {
        final lastFetch = _lastUrlFetchTime;
        final isStale = lastFetch != null &&
            DateTime.now().difference(lastFetch) > _urlStaleDuration;
        if (isStale && !currentSong.isLocal) {
          await _refreshUrlAndPlay(currentSong);
        } else {
          await _player.play();
        }
      }
    }
  }

  Future<void> _refreshUrlAndPlay(Song song) async {
    try {
      final quality = _currentQuality(song);
      final pos = position.value;
      final songUrl = await _musicService.getSongUrl(song.id,
          hash: song.hash, quality: quality);
      if (songUrl.url.isEmpty) return;
      _lastUrlFetchTime = DateTime.now();
      await _player.setUrl(songUrl.url);
      await _player.seek(pos);
      await _player.play();
      isLoading.value = false;
    } catch (e, s) {
      Log.e('audio_engine', 'refresh URL error', e, s);
      error.value = '刷新播放地址失败';
    }
  }

  void clearError() {
    error.value = null;
  }

  void resetForNewSong() {
    _playAttempts = 0;
    _playRequestVersion++;
    error.value = null;
    isLoading.value = true;
    isCompleting.value = false;
  }

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
  }

  Future<void> seekAndPlay(Duration pos) async {
    await _player.seek(pos);
    await _player.play();
    isPlaying.value = true;
    isLoading.value = false;
  }

  Future<void> pause() async {
    await _player.pause();
  }

  void setVolume(double volume) {
    _player.setVolume(volume);
  }

  void setSpeed(double speed) {
    _player.setSpeed(speed);
  }

  /// 获取当前请求的音质 key
  /// 优先用 qualityLevel 选定的音质，不依赖 song.qualities（API 端协商）
  /// [fallbackLevel] 用于音质降级重试（0=128, 1=320, 2=high, ...）
  String _currentQuality(Song? song, {int fallbackLevel = -1}) {
    final level = fallbackLevel >= 0
        ? fallbackLevel
        : qualityLevel % Song.qualityKeys.length;
    return Song.qualityKeys[level];
  }

  /// 音质降级链：从用户选定的音质开始，逐级降到 128
  static List<String> _qualityFallbackChain(int startLevel) {
    final keys = Song.qualityKeys;
    final start = startLevel % keys.length;
    final chain = <String>[];
    for (var i = start; i >= 0; i--) {
      chain.add(keys[i]);
    }
    return chain;
  }

  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _processingStateSub?.cancel();
    _playbackSub?.cancel();
    position.dispose();
    duration.dispose();
    isLoading.dispose();
    isPlaying.dispose();
    error.dispose();
    isCompleting.dispose();
    _player.dispose();
  }
}
