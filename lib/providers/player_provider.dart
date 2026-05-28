import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../models/song.dart';
import '../models/lyric_line.dart';
import '../utils/palette_extractor.dart';
import '../services/music_service.dart';
import '../services/notification_service.dart';
import 'mixins.dart';
import 'audio_engine.dart';
import 'playlist_queue.dart';
import 'audio_settings_provider.dart';

export 'playlist_queue.dart' show PlayMode;

class PlayerProvider extends ChangeNotifier with SleepTimerMixin, KeepScreenOnMixin {
  final MusicService _musicService;
  final AudioSettingsProvider? _audioSettings;
  late final AudioEngine _engine;
  late final PlaylistQueue _queue;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isPlayerScreenVisible = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  int _qualityLevel = 0;

  // ─── Dynamic palette & lyric state ───
  ExtractedPalette? _palette;
  List<LyricLine> _lyrics = [];
  int _currentLyricLine = 0;
  double _lyricLineProgress = 0.0;
  Color? _backgroundColor;

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

  // ─── Palette & lyric getters ───
  ExtractedPalette? get palette => _palette;
  List<LyricLine> get lyrics => _lyrics;
  int get currentLyricLine => _currentLyricLine;
  double get lyricLineProgress => _lyricLineProgress;
  Color? get backgroundColor => _backgroundColor;

  Future<List<Song>> Function()? get playlistEndProvider => _queue.playlistEndProvider;
  set playlistEndProvider(Future<List<Song>> Function()? v) {
    _queue.playlistEndProvider = v;
  }

  PlayerProvider(this._musicService, {AudioSettingsProvider? audioSettings})
      : _audioSettings = audioSettings {
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
        _engine.play(_queue.currentSong ?? current, version: _engine.currentVersion);
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

  /// 获取当前网络应是 WiFi 还是蜂窝（简单判定，无 connectivity_plus 时默认 WiFi）
  /// TODO: 接入 connectivity_plus 后改用真实网络类型
  bool get _isWifi {
    return true; // 默认 WiFi，用户可在设置中分别配置
  }

  /// 播放前根据 AudioSettingsProvider 设置目标音质
  void _applyQualityFromSettings() {
    final settings = _audioSettings;
    if (settings == null) return;
    final maxKey = settings.getEffectiveQuality(_isWifi);
    final idx = Song.qualityKeys.indexOf(maxKey);
    if (idx >= 0 && idx != _qualityLevel) {
      _qualityLevel = idx;
      _engine.qualityLevel = idx;
    }
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _queue.playlist.length) return;
    _queue.playIndex(index);
    // Reset lyric state for new song
    _lyrics = [];
    _currentLyricLine = 0;
    _lyricLineProgress = 0.0;
    final current = _queue.currentSong;
    if (current == null) return;
    _applyQualityFromSettings();
    _engine.resetForNewSong();
    notifyListeners();
    final version = _engine.currentVersion;
    await _engine.play(current, version: version);
    _updateNotification();
    // Extract palette from album art
    if (current.albumCoverUrl != null) {
      _extractPalette(current.albumCoverUrl!);
    }
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    _queue.playlistEndProvider = null;
    _engine.clearError();
    // Reset lyric state for new song
    _lyrics = [];
    _currentLyricLine = 0;
    _lyricLineProgress = 0.0;
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
    _applyQualityFromSettings();
    _engine.resetForNewSong();
    final version = _engine.currentVersion;
    notifyListeners();
    await _engine.play(current, version: version);
    _updateNotification();
    // Extract palette from album art
    if (current.albumCoverUrl != null) {
      _extractPalette(current.albumCoverUrl!);
    }
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
    if (songs.isEmpty) {
      _engine.pause();
      _isPlaying = false;
      notifyListeners();
    }
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

  /// 获取当前歌曲实际可用的音质列表（而非全部 5 个）
  List<String> getAvailableQualities() {
    final song = _queue.currentSong;
    if (song == null || song.qualities == null) return Song.qualityKeys;
    // 检查歌曲的 qualities 中哪些 key 实际存在
    final available = <String>[];
    for (final key in Song.qualityKeys) {
      if (song.qualities!.containsKey(key)) available.add(key);
    }
    return available.isNotEmpty ? available : Song.qualityKeys;
  }

  /// 获取当前音质的显示标签
  String get currentQualityLabel {
    final key = Song.qualityKeys[_qualityLevel % Song.qualityKeys.length];
    return Song.qualityLabelMap[key] ?? key;
  }

  Future<void> setQuality(String qualityKey) async {
    final idx = Song.qualityKeys.indexOf(qualityKey);
    if (idx < 0) return;
    _qualityLevel = idx;
    _engine.qualityLevel = idx;
    // 强制歌词重新加载（音质切换后 hash 不变，但需要刷新歌词）
    _lyrics = [];
    _currentLyricLine = 0;
    _lyricLineProgress = 0.0;
    if (_isPlaying) {
      await playIndex(_queue.currentIndex);
    } else {
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Palette extraction
  // ──────────────────────────────────────────────────────────────

  /// Extracts a color palette from the album art at [imageUrl] and updates
  /// [_palette] and [_backgroundColor]. Silently fails on error (palette is
  /// purely cosmetic).
  Future<void> _extractPalette(String imageUrl) async {
    try {
      _palette = await PaletteExtractor.instance.extract(imageUrl);
      _backgroundColor = _palette?.dominant;
      notifyListeners();
    } catch (_) {
      // Palette extraction is cosmetic — ignore failures.
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Lyric management
  // ──────────────────────────────────────────────────────────────

  /// Stores parsed lyrics and resets all progress state to the beginning.
  void setLyrics(List<LyricLine> lyrics) {
    _lyrics = lyrics;
    _currentLyricLine = 0;
    _lyricLineProgress = 0.0;
    notifyListeners();
  }

  /// Clears all lyric state (called when switching to a song without lyrics).
  void clearLyrics() {
    _lyrics = [];
    _currentLyricLine = 0;
    _lyricLineProgress = 0.0;
    notifyListeners();
  }

  /// Updates the current lyric line and intra-line progress based on
  /// [position]. Uses binary search over [_lyrics] to find the active line,
  /// then calculates fractional progress (0.0–1.0) between the current line
  /// and the next. Only calls [notifyListeners] when values actually change.
  void updateLyricProgress(Duration position) {
    if (_lyrics.isEmpty) return;

    // Binary search: find the last line whose time ≤ position
    int lo = 0;
    int hi = _lyrics.length - 1;
    int idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (_lyrics[mid].time <= position) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    // Compute intra-line progress (0.0 → 1.0)
    double progress;
    if (idx < _lyrics.length - 1) {
      final start = _lyrics[idx].time;
      final end = _lyrics[idx + 1].time;
      final range = end - start;
      if (range > Duration.zero) {
        progress =
            (position.inMilliseconds - start.inMilliseconds) / range.inMilliseconds;
        progress = progress.clamp(0.0, 1.0);
      } else {
        progress = 1.0;
      }
    } else {
      progress = 1.0;
    }

    if (idx != _currentLyricLine || progress != _lyricLineProgress) {
      _currentLyricLine = idx;
      _lyricLineProgress = progress;
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
