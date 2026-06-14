// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show HSLColor;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../models/song.dart';
import '../utils/palette_extractor.dart';
import '../services/music_service.dart';
import '../services/notification_service.dart';
import '../constants/quality.dart';
import 'mixins.dart';
import 'audio_engine.dart';
import 'playlist_queue.dart';
import 'audio_settings_provider.dart';
import 'liked_songs_provider.dart';

export 'playlist_queue.dart' show PlayMode;

class PlayerProvider extends ChangeNotifier with SleepTimerMixin, KeepScreenOnMixin {
  final MusicService _musicService;
  final AudioSettingsProvider? _audioSettings;
  final LikedSongsProvider? _likedSongs;
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
  final LyricController _lyricController = LyricController();
  Color? _backgroundColor;

  // ─── 歌曲高潮标记 ───
  int? _climaxMs;  // 毫秒，当前歌曲的高潮开始时间

  int? get climaxMs => _climaxMs;

  // ─── 通知节流 ───
  int _lastNotifUpdateMs = 0;
  int _lastNotifLyricIdx = -1;

  // ─── 播放状态持久化（杀进程恢复） ───
  static const _keySavedSongId = 'playback_saved_song_id';
  static const _keySavedSongName = 'playback_saved_song_name';
  static const _keySavedSongHash = 'playback_saved_song_hash';
  static const _keySavedSongArtist = 'playback_saved_song_artist';
  static const _keySavedSongCover = 'playback_saved_song_cover';
  static const _keySavedSongAlbumId = 'playback_saved_song_album_id';
  static const _keySavedPosition = 'playback_saved_position_ms';
  static const _keySavedPlayMode = 'playback_saved_play_mode';
  static const _keySavedQuality = 'playback_saved_quality_level';

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

  /// The lyric controller driving the [LyricView] in PlayerScreen.
  LyricController get lyricController => _lyricController;

  /// Returns all available palette colours for the flowing light effect.
  /// Prefers the quantized [topColors] for richer variety, falls back to
  /// the hand-picked targets.
  ///
  /// Always stretches the lightness range to [0.12, 0.85] so the blobs
  /// have visibly deep darks and bright lights while keeping the original
  /// hue/saturation and the proportional spacing (natural gradation).
  List<Color> get paletteColors {
    final p = _palette;
    if (p == null) return const [];

    List<Color> colors;
    if (p.topColors.isNotEmpty) {
      colors = [p.dominant, ...p.topColors];
    } else {
      colors = [
        p.dominant,
        if (p.vibrant != null) p.vibrant!,
        if (p.muted != null) p.muted!,
        if (p.darkMuted != null) p.darkMuted!,
        if (p.lightVibrant != null) p.lightVibrant!,
      ];
    }

    // Linearly remap each colour's lightness so the set spans [0.12, 0.85].
    final lightnesses = colors
        .map((c) => HSLColor.fromColor(c).lightness)
        .toList();
    final minL = lightnesses.reduce((a, b) => a < b ? a : b);
    final maxL = lightnesses.reduce((a, b) => a > b ? a : b);
    const targetMin = 0.12;
    const targetMax = 0.85;
    final span = maxL - minL;
    if (span > 0.001) {
      colors = colors.map((c) {
        final hsl = HSLColor.fromColor(c);
        final normalized = (hsl.lightness - minL) / span;
        return hsl
            .withLightness(targetMin + normalized * (targetMax - targetMin))
            .toColor();
      }).toList();
    }

    return colors;
  }

  Color? get backgroundColor => _backgroundColor;

  Future<List<Song>> Function()? get playlistEndProvider => _queue.playlistEndProvider;
  set playlistEndProvider(Future<List<Song>> Function()? v) {
    _queue.playlistEndProvider = v;
  }

  PlayerProvider(this._musicService, {AudioSettingsProvider? audioSettings, LikedSongsProvider? likedSongs})
      : _audioSettings = audioSettings, _likedSongs = likedSongs {
    _engine = AudioEngine(_musicService);
    _queue = PlaylistQueue();

    _onPositionChanged = () {
      _position = _engine.position.value;
      _lyricController.setProgress(_position);
      notifyListeners();
      if (sleepTimerRemaining != null && sleepTimerRemaining!.inSeconds <= 0) {
        _engine.pause();
        _isPlaying = false;
        cancelSleepTimer();
        notifyListeners();
      }
      // 通知更新策略：
      // - 歌词行切换时 → 即时更新（锁屏歌词不卡顿）
      // - 仅位置变化 → 每 10 秒节流（用于蓝牙 A2DP 进度同步）
      final now = DateTime.now().millisecondsSinceEpoch;
      final lyricIdx = _lyricController.activeIndexNotifiter.value;
      final lyricChanged = lyricIdx != _lastNotifLyricIdx;
      if (lyricChanged) {
        _lastNotifLyricIdx = lyricIdx;
        _lastNotifUpdateMs = now;
        _updateNotification();
      } else if (now - _lastNotifUpdateMs > 10000) {
        _lastNotifUpdateMs = now;
        _updateNotification();
        _savePlaybackState(); // 同步持久化位置
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
    _onQueueChanged = () {
      notifyListeners();
      _savePlaybackState();
    };
    _queue.addListener(_onQueueChanged);

    // 启动后恢复上次的播放状态
    WidgetsBinding.instance.addPostFrameCallback((_) => restorePlaybackState());
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
    final cl = _lyricController.activeIndexNotifiter.value;
    final model = _lyricController.lyricNotifier.value;
    if (model != null && cl < model.lines.length) {
      final line = model.lines[cl].text;
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
      isBuffering: _engine.isLoading.value,
    );
    // 同步自定义按钮状态
    _notifyCustomButtons(song.id);
  }

  /// 同步收藏和播放模式状态到系统媒体控件
  void _notifyCustomButtons(int songId) {
    final liked = _likedSongs?.likedIds.contains(songId) ?? false;
    final modeLabel = switch (_queue.playMode) {
      PlayMode.sequential => 'sequential',
      PlayMode.shuffle => 'shuffle',
      PlayMode.repeatOne => 'repeatOne',
      PlayMode.radio => 'sequential',
    };
    NotificationService.instance.updateCustomButtons(
      liked: liked,
      playMode: modeLabel,
    );
  }

  /// 将当前播放状态持久化到 SharedPreferences（杀进程后恢复用）。
  /// 不保存完整队列，只保存当前歌曲 + 进度 + 模式。
  Future<void> _savePlaybackState() async {
    final song = _queue.currentSong;
    if (song == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySavedSongId, song.id);
      await prefs.setString(_keySavedSongName, song.name);
      await prefs.setString(_keySavedSongHash, song.hash ?? '');
      await prefs.setString(_keySavedSongArtist, song.artistDisplay);
      await prefs.setString(_keySavedSongCover, song.albumCoverUrl ?? '');
      await prefs.setInt(_keySavedSongAlbumId, song.albumId);
      await prefs.setInt(_keySavedPosition, _position.inMilliseconds);
      await prefs.setString(_keySavedPlayMode, _queue.playMode.name);
      await prefs.setInt(_keySavedQuality, _qualityLevel);
    } catch (_) {}
  }

  /// 从 SharedPreferences 恢复播放状态。
  /// 仅供初始化时调用，不自动播放 —— 只让 Mini Bar 显示上次的歌曲。
  Future<void> restorePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songId = prefs.getInt(_keySavedSongId);
      if (songId == null) return;
      final songName = prefs.getString(_keySavedSongName) ?? '';
      final songHash = prefs.getString(_keySavedSongHash) ?? '';
      final songArtist = prefs.getString(_keySavedSongArtist) ?? '';
      final songCover = prefs.getString(_keySavedSongCover) ?? '';
      final songAlbumId = prefs.getInt(_keySavedSongAlbumId) ?? 0;
      final positionMs = prefs.getInt(_keySavedPosition) ?? 0;
      final modeName = prefs.getString(_keySavedPlayMode) ?? 'sequential';
      final quality = prefs.getInt(_keySavedQuality) ?? 0;

      final song = Song(
        id: songId,
        name: songName,
        artists: songArtist.split(' / '),
        albumCoverUrl: songCover.isNotEmpty ? songCover : null,
        albumId: songAlbumId,
        hash: songHash.isNotEmpty ? songHash : null,
      );
      _queue.setPlaylist([song], startIndex: 0);
      _qualityLevel = quality;
      _engine.qualityLevel = quality;
      _position = Duration(milliseconds: positionMs);
      // 恢复播放模式
      final mode = PlayMode.values.where((m) => m.name == modeName).firstOrNull;
      if (mode != null) _queue.setPlayMode(mode);
      notifyListeners();
    } catch (_) {}
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
    _lyricController.loadLyricModel(LyricModel(lines: []));
    _climaxMs = null;
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
    // 异步查询高潮时间（不阻塞播放，失败静默）
    _fetchClimax(current);
    notifyListeners();
  }

  /// 异步获取歌曲高潮开始时间并更新到 Song 模型
  Future<void> _fetchClimax(Song song) async {
    final hash = song.hash;
    if (hash == null || hash.isEmpty) return;
    final ms = await _musicService.getSongClimax(hash);
    _climaxMs = ms;
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    _queue.playlistEndProvider = null;
    _engine.clearError();
    // Reset lyric state for new song
    _lyricController.loadLyricModel(LyricModel(lines: []));
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
    _savePlaybackState();
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
    _savePlaybackState();
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
      _lyricController.loadLyricModel(LyricModel(lines: []));
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

  /// Loads a [LyricModel] into the controller (replaces current lyrics).
  void loadLyricModel(LyricModel model) {
    _lyricController.loadLyricModel(model);
    notifyListeners();
    _updateNotification();
  }

  /// Clears all lyric state (called when switching to a song without lyrics).
  void clearLyrics() {
    _lyricController.loadLyricModel(LyricModel(lines: []));
    notifyListeners();
    _updateNotification();
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
    _lyricController.dispose();
    super.dispose();
  }
}
