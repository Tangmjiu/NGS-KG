import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../models/song.dart';
import '../models/lyric_line.dart';
import '../utils/palette_extractor.dart';
import '../services/music_service.dart';
import '../services/notification_service.dart';
import '../constants/quality.dart';
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
  Color? _backgroundColor;

  // ─── 通知节流 ───
  int _lastNotifUpdateMs = 0;

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

  /// 最终解析到的音质 key（如 'flac', '320'）
  /// 由 AudioEngine 在播放成功后设置
  String? get resolvedQuality => _engine.resolvedQuality;

  /// 当前歌曲的可用音质选项（来自 /privilege/lite）
  List<QualityOption> get qualityOptions => _engine.currentQualityOptions;

  /// 当前解析音质的显示标签
  String get resolvedQualityLabel {
    final q = _engine.resolvedQuality;
    if (q != null) return Song.qualityLabelMap[q] ?? q;
    return currentQualityLabel;
  }
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

  /// Computed: the index of the lyric line currently being sung.
  int get currentLyricLine {
    if (_lyrics.isEmpty) return 0;
    final idx = _lyrics.lastIndexWhere((l) => _position >= l.startTime);
    return idx == -1 ? 0 : idx;
  }

  /// Progress of the current line (0.0 – 1.0).  Used by the notification
  /// layer only; the lyrics view calculates its own progress internally.
  double get lyricLineProgress {
    if (_lyrics.isEmpty || currentLyricLine >= _lyrics.length) return 0.0;
    return _lyrics[currentLyricLine].getLineProgress(_position);
  }

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
      // 节流：每 10 秒更新通知位置（用于蓝牙 A2DP 进度同步）
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastNotifUpdateMs > 10000) {
        _lastNotifUpdateMs = now;
        _updateNotification();
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
    // 当前歌词行（如果有）
    String? lyricLine;
    final cl = currentLyricLine;
    if (_lyrics.isNotEmpty && cl < _lyrics.length) {
      final line = _lyrics[cl].text;
      if (line.isNotEmpty) lyricLine = line;
    }
    NotificationService.instance.showMediaNotification(
      title: song.name,
      artist: song.artistDisplay,
      albumArtUrl: song.albumCoverUrl,
      lyricLine: lyricLine,
      isPlaying: _isPlaying,
      duration: _duration.inSeconds,
      position: _position.inSeconds,
    );
  }

  /// 应用音质设置后直接调用引擎播放（用于自动切歌等非用户触发的播放）
  void _enginePlayWithQuality(Song? song, {int? version}) {
    final s = song ?? _queue.currentSong;
    if (s == null) return;
    _applyQualityFromSettings();
    _engine.play(s, version: version ?? _engine.currentVersion);
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
        _enginePlayWithQuality(_queue.currentSong ?? current);
        break;
      case PlayMode.sequential:
        if (_queue.currentIndex + 1 < _queue.playlist.length) {
          _engine.resetForNewSong();
          _queue.playIndex(_queue.currentIndex + 1);
          _enginePlayWithQuality(_queue.currentSong ?? current);
        } else if (_queue.playlistEndProvider != null) {
          _loadMoreAndContinue();
        } else {
          _engine.resetForNewSong();
          _queue.playIndex(0);
          _enginePlayWithQuality(_queue.currentSong ?? current);
        }
        break;
      case PlayMode.radio:
        if (_queue.currentIndex + 1 < _queue.playlist.length) {
          _engine.resetForNewSong();
          _queue.playIndex(_queue.currentIndex + 1);
          _enginePlayWithQuality(_queue.currentSong ?? current);
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
          _enginePlayWithQuality(next);
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
    // 同步上传开关到引擎
    _engine.uploadHistory = settings.uploadHistory;
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _queue.playlist.length) return;
    _queue.playIndex(index);
    // Reset lyric state for new song
    _lyrics = [];
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

  void clearPlaylist() {
    _queue.setPlaylist([]);
    _engine.pause();
    _isPlaying = false;
    notifyListeners();
  }

  void setPlayMode(PlayMode mode) {
    _queue.setPlayMode(mode);
  }

  void setPlayerScreenVisible(bool v) {
    _isPlayerScreenVisible = v;
    notifyListeners();
  }

  bool isCurrentQuality(String key) {
    final currentKey = Quality.levels[_qualityLevel % Quality.levels.length];
    return currentKey == key;
  }

  Future<void> setQualityIndex(int index) async {
    _qualityLevel = index % Quality.levels.length;
    _engine.qualityLevel = _qualityLevel;
    if (_isPlaying) {
      await playIndex(_queue.currentIndex);
    } else {
      notifyListeners();
    }
  }

  /// 获取全部音质列表
  List<String> getAvailableQualities() => List.unmodifiable(Quality.levels);

  /// 获取当前音质的显示标签（优先使用实际解析到的音质）
  String get currentQualityLabel {
    final resolved = _engine.resolvedQuality;
    if (resolved != null && Quality.labels.containsKey(resolved)) {
      return Quality.labels[resolved]!;
    }
    return Quality.label(Quality.levels[_qualityLevel % Quality.levels.length]);
  }

  /// 无缝切换音质（保持播放进度与播放/暂停状态）
  Future<bool> setQuality(String qualityKey) async {
    final song = _queue.currentSong;
    if (song == null || song.hash == null || song.hash!.isEmpty) return false;

    final idx = Quality.levels.indexOf(qualityKey);
    if (idx < 0) return false;

    // 更新 qualityLevel（用于下一首歌曲）
    _qualityLevel = idx;
    _engine.qualityLevel = idx;

    // 用 engine 的无缝切换
    final success = await _engine.switchQuality(song, qualityKey,
        currentPosition: _position);

    // 切换成功后强制刷新歌词
    if (success) {
      _lyrics = [];
    }
    notifyListeners();
    return success;
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

  /// Stores parsed lyrics.  The lyrics view handles progress internally.
  void setLyrics(List<LyricLine> lyrics) {
    _lyrics = lyrics;
    notifyListeners();
  }

  /// Clears all lyric state (called when switching to a song without lyrics).
  void clearLyrics() {
    _lyrics = [];
    notifyListeners();
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
