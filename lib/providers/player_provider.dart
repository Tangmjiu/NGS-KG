import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../models/song.dart';
import '../services/music_service.dart';
import '../services/notification_service.dart';
import 'mixins.dart';
import 'audio_engine.dart';
import 'playlist_queue.dart';

export 'playlist_queue.dart' show PlayMode;

class PlayerProvider extends ChangeNotifier with SleepTimerMixin, KeepScreenOnMixin {
  final MusicService _musicService;
  late final AudioEngine _engine;
  late final PlaylistQueue _queue;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isPlayerScreenVisible = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  int _qualityLevel = 0;

  late final VoidCallback _onPositionChanged;
  late final VoidCallback _onDurationChanged;
  late final VoidCallback _onLoadingChanged;
  late final VoidCallback _onErrorChanged;
  late final VoidCallback _onPlayingChanged;
  late final VoidCallback _onQueueChanged;

  Song? get currentSong => _queue.currentSong;
  List<Song> get playlist => _queue.playlist;
  int get currentIndex => _queue.currentIndex;
  PlayMode get playMode => _queue.playMode;
  int get qualityLevel => _qualityLevel;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _queue.isLoadingMore;
  bool get isPlayerScreenVisible => _isPlayerScreenVisible;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get error => _error;
  double get progress =>
      _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

  Future<List<Song>> Function()? get playlistEndProvider => _queue.playlistEndProvider;
  set playlistEndProvider(Future<List<Song>> Function()? v) {
    _queue.playlistEndProvider = v;
  }

  PlayerProvider(this._musicService) {
    _engine = AudioEngine(_musicService);
    _queue = PlaylistQueue();

    _onPositionChanged = () {
      _position = _engine.position.value;
      notifyListeners();
      if (sleepTimerRemaining != null && sleepTimerRemaining!.inSeconds <= 0) {
        _engine.pause();
        _isPlaying = false;
        cancelSleepTimer();
        notifyListeners();
      }
    };
    _engine.position.addListener(_onPositionChanged);

    _onDurationChanged = () {
      _duration = _engine.duration.value;
      notifyListeners();
    };
    _engine.duration.addListener(_onDurationChanged);

    _onLoadingChanged = () {
      _isLoading = _engine.isLoading.value;
      notifyListeners();
    };
    _engine.isLoading.addListener(_onLoadingChanged);

    _onErrorChanged = () {
      _error = _engine.error.value;
      notifyListeners();
    };
    _engine.error.addListener(_onErrorChanged);

    _onPlayingChanged = () {
      _isPlaying = _engine.isPlaying.value;
      notifyListeners();
      _updateNotification();
    };
    _engine.isPlaying.addListener(_onPlayingChanged);

    _engine.onComplete = _onComplete;
    _onQueueChanged = notifyListeners;
    _queue.addListener(_onQueueChanged);
  }

  void clearError() {
    _engine.clearError();
  }

  void _updateNotification() {
    final song = _queue.currentSong;
    if (song == null) {
      NotificationService.instance.cancelMediaNotification();
      return;
    }
    NotificationService.instance.showMediaNotification(
      title: song.name,
      artist: song.artistDisplay,
      isPlaying: _isPlaying,
      duration: _duration.inSeconds,
      position: _position.inSeconds,
    );
  }

  void _onComplete() {
    if (!_engine.isCompleting.value) return;
    final current = _queue.currentSong;
    if (current == null) return;
    switch (_queue.playMode) {
      case PlayMode.repeatOne:
        _engine.isCompleting.value = false;
        _engine.seekAndPlay(Duration.zero);
        break;
      case PlayMode.shuffle:
        final idx = _queue.nextIndex();
        if (idx == null) return;
        _engine.resetForNewSong();
        _queue.playIndex(idx);
        _engine.play(current, version: _engine.currentVersion);
        break;
      case PlayMode.sequential:
        if (_queue.currentIndex + 1 < _queue.playlist.length) {
          _engine.resetForNewSong();
          _queue.playIndex(_queue.currentIndex + 1);
          _engine.play(_queue.currentSong ?? current, version: _engine.currentVersion);
        } else if (_queue.playlistEndProvider != null) {
          _loadMoreAndContinue();
        } else {
          _engine.resetForNewSong();
          _queue.playIndex(0);
          _engine.play(_queue.currentSong ?? current, version: _engine.currentVersion);
        }
        break;
      case PlayMode.radio:
        if (_queue.currentIndex + 1 < _queue.playlist.length) {
          _engine.resetForNewSong();
          _queue.playIndex(_queue.currentIndex + 1);
          _engine.play(_queue.currentSong ?? current, version: _engine.currentVersion);
        } else {
          _loadMoreAndContinue();
        }
        break;
    }
  }

  Future<void> _loadMoreAndContinue() async {
    if (_queue.isLoadingMore) return;
    _queue.setLoadingMore(true);
    _isLoading = true;
    notifyListeners();
    try {
      final moreSongs = await _queue.playlistEndProvider?.call() ?? [];
      if (moreSongs.isNotEmpty) {
        _queue.append(moreSongs);
        _queue.setLoadingMore(false);
        _engine.resetForNewSong();
        _queue.playIndex(_queue.currentIndex + 1);
        final next = _queue.currentSong;
        if (next != null) {
          _engine.play(next, version: _engine.currentVersion);
          return;
        }
      }
    } catch (e, s) { Log.e('player_provider', 'loadMore error', e, s); }
    _queue.setLoadingMore(false);
    _isLoading = false;
    _isPlaying = false;
    _updateNotification();
    notifyListeners();
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _queue.playlist.length) return;
    _queue.playIndex(index);
    final current = _queue.currentSong;
    if (current == null) return;
    _engine.resetForNewSong();
    notifyListeners();
    final version = _engine.currentVersion;
    await _engine.play(current, version: version);
    _updateNotification();
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    _queue.playlistEndProvider = null;
    _engine.clearError();
    if (playlist != null) {
      final idx = playlist.indexWhere((s) => s.id == song.id);
      _queue.setPlaylist(playlist, startIndex: idx < 0 ? 0 : idx);
      if (idx < 0 && playlist.isNotEmpty) {
        _queue.setPlaylist([song]);
      }
      if (_queue.playMode == PlayMode.shuffle) {
        _queue.setPlayMode(PlayMode.shuffle);
      }
    } else {
      _queue.setPlaylist([song]);
    }
    final current = _queue.currentSong;
    if (current == null) return;
    _engine.resetForNewSong();
    final version = _engine.currentVersion;
    notifyListeners();
    await _engine.play(current, version: version);
    _updateNotification();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    final song = _queue.currentSong;
    if (song == null) return;
    if (_isPlaying) {
      await _engine.pause();
      _isPlaying = false;
    } else {
      if (_position == Duration.zero || _position >= _duration) {
        _engine.resetForNewSong();
        final version = _engine.currentVersion;
        notifyListeners();
        await _engine.play(song, version: version);
      } else {
        _engine.clearError();
        _isLoading = false;
        await _engine.togglePlayPause(song);
      }
    }
    notifyListeners();
    _updateNotification();
  }

  void playNext() {
    if (_queue.playlist.isEmpty) return;
    final next = _queue.nextIndex();
    if (next != null) {
      playIndex(next);
    } else if (_queue.playlistEndProvider != null) {
      _loadMoreAndContinue();
    } else {
      playIndex((_queue.currentIndex + 1) % _queue.playlist.length);
    }
  }

  void playPrevious() {
    if (_queue.playlist.isEmpty) return;
    if (_position.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }
    playIndex(_queue.previousIndex() ?? 0);
  }

  Future<void> seek(Duration pos) async {
    await _engine.seek(pos);
  }

  void setPlaylist(List<Song> songs, {int startIndex = 0}) {
    _queue.setPlaylist(songs, startIndex: startIndex);
  }

  void setPlayMode(PlayMode mode) {
    _queue.setPlayMode(mode);
  }

  void setPlayerScreenVisible(bool v) {
    _isPlayerScreenVisible = v;
    notifyListeners();
  }

  bool isCurrentQuality(String key) {
    final q = _queue.currentSong?.qualities;
    if (q == null || q.isEmpty) return false;
    const keys = Song.qualityKeys;
    final currentKey = keys[_qualityLevel % keys.length];
    return currentKey == key;
  }

  Future<void> setQualityIndex(int index) async {
    final q = _queue.currentSong?.qualities;
    if (q == null || q.isEmpty) return;
    _qualityLevel = index % Song.qualityKeys.length;
    _engine.qualityLevel = _qualityLevel;
    if (_isPlaying) {
      await playIndex(_queue.currentIndex);
    } else {
      notifyListeners();
    }
  }

  Future<void> switchQuality() async {
    final q = _queue.currentSong?.qualities;
    if (q == null || q.isEmpty) return;
    _qualityLevel = (_qualityLevel + 1) % Song.qualityKeys.length;
    _engine.qualityLevel = _qualityLevel;
    if (_isPlaying) {
      await playIndex(_queue.currentIndex);
    } else {
      notifyListeners();
    }
  }

  @override
  void onSleepTimerExpired() {
    _engine.pause();
    _isPlaying = false;
  }

  void setVolume(double volume) {
    _engine.setVolume(volume);
  }

  void setSpeed(double speed) {
    _engine.setSpeed(speed);
  }

  @override
  void dispose() {
    _engine.position.removeListener(_onPositionChanged);
    _engine.duration.removeListener(_onDurationChanged);
    _engine.isLoading.removeListener(_onLoadingChanged);
    _engine.error.removeListener(_onErrorChanged);
    _engine.isPlaying.removeListener(_onPlayingChanged);
    _queue.removeListener(_onQueueChanged);
    disposeSleepTimer();
    disposeKeepScreenOn();
    _engine.dispose();
    _queue.dispose();
    super.dispose();
  }
}
