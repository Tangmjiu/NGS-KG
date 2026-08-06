// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show HSLColor;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ym_lyric/model/krc_language_model.dart';
import 'package:ym_lyric/model/krc_lyric_line_model.dart';
import 'package:ym_lyric/utils/krc_lyric_util.dart';
import '../utils/logger.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../utils/palette_extractor.dart';
import '../services/music_service.dart';
import '../services/audio_handler.dart';
import '../constants/quality.dart';
import 'mixins.dart';
import 'audio_engine.dart';
import 'playlist_queue.dart';
import 'audio_settings_provider.dart';
import 'liked_songs_provider.dart';

export 'playlist_queue.dart' show PlayMode;

/// 独立 FM 队列：进入 FM 前保存的普通队列快照
class FmQueueSnapshot {
  final List<Song> songs;
  final int index;
  final PlayMode playMode;

  const FmQueueSnapshot({
    required this.songs,
    required this.index,
    required this.playMode,
  });
}

class PlayerProvider extends ChangeNotifier
    with SleepTimerMixin, KeepScreenOnMixin {
  final MusicService _musicService;
  final AudioSettingsProvider? _audioSettings;
  final LikedSongsProvider? _likedSongs;
  final MusicAudioHandler _audioHandler;
  late final AudioEngine _engine;
  late final PlaylistQueue _queue;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isPlayerScreenVisible = false;
  bool _isMiniPlayerDismissed = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  int _qualityLevel = 0;
  String _effectKey = 'none';

  // ─── Dynamic palette & lyric state ───
  ExtractedPalette? _palette;
  List<Color>? _cachedPaletteColors;
  final LyricController _lyricController = LyricController();
  Color? _backgroundColor;

  // ─── 歌词处理状态 ───
  bool _lyricLoading = false;
  Map<int, List<String>> _lyricLangMap = {};
  List<KrcLyricLineModel>? _krcLines;
  int _selectedLyricLang = 0;
  bool _showTranslation = true;
  String? _lastLoadedHash;
  int? _lastLoadedSongId;

  // ─── /krm/audio 元数据缓存 ───
  Map<String, dynamic>? _currentKrmAudio;
  Map<String, dynamic>? get currentKrmAudio => _currentKrmAudio;

  List<Map<String, dynamic>> get currentSongAuthors {
    if (_currentKrmAudio == null) return [];
    final list = _currentKrmAudio!['authors'] as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) {
      if (e is Map) {
        final base = e['base'] as Map?;
        return {
          'id': SongMapper.safeInt(base?['author_id']),
          'name': base?['author_name'] as String? ?? '',
        };
      }
      return <String, dynamic>{};
    }).where((e) => e['name'] != null && (e['name'] as String).isNotEmpty).toList();
  }

  int get currentSongAlbumId {
    if (_currentKrmAudio != null) {
      final albumInfo = _currentKrmAudio!['album_info'] as Map?;
      final aid = SongMapper.safeInt(albumInfo?['album_id'] ?? _currentKrmAudio!['base']?['album_id']);
      if (aid != null && aid > 0) return aid;
    }
    return currentSong?.albumId ?? 0;
  }

  // ─── 歌曲高潮标记 ───
  int? _climaxMs; // 毫秒，当前歌曲的高潮开始时间

  // ─── 私人 FM 隔离状态 ───
  VoidCallback? _fmDislikeCallback;

  /// FM 播放反馈回调 — 由 DiscoverProvider 传入，定期上报 hash/songid/playtime
  void Function(Song song, {int playtime})? _fmPlaybackUpdateCallback;

  /// 重入保护：防止 _onComplete / _loadMoreAndContinue 在极短歌曲时被多次调用
  bool _handlingComplete = false;

  /// 进入 FM 前保存的正常队列快照（exitFmMode 时恢复）
  FmQueueSnapshot? _fmSavedNormalSnapshot;

  int? get climaxMs => _climaxMs;

  // ─── 通知节流 ───
  int _lastNotifUpdateMs = 0;
  int _lastNotifLyricIdx = -1;
  int _lastPositionNotifyMs = 0;

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
  static const _keySavedQueueJson = 'playback_saved_queue_json';
  static const _keySavedQueueIndex = 'playback_saved_queue_index';

  /// 新版播放状态存储 key（单个 JSON，避免 13 次 prefs 写入）。
  static const _keySavedPlaybackStateV2 = 'playback_state_v2';

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

  /// 当前播放速度（0.5x ~ 2.0x）
  double get currentSpeed => _engine.speed;

  /// 最终解析到的音质 key（如 'flac', '320'）
  /// 由 AudioEngine 在播放成功后设置
  String? get resolvedQuality => _engine.resolvedQuality;

  /// 当前歌曲的可用编码音质选项（来自 /privilege/lite）
  List<QualityOption> get qualityOptions => _engine.currentQualityOptions;

  /// 当前歌曲的可用音效选项（来自 /privilege/lite）
  List<QualityOption> get effectOptions => _engine.currentEffectOptions;

  /// 当前选中的音效 key（'none' 表示无效果）
  String get effectKey => _effectKey;

  /// 当前音效的显示标签
  String get effectLabel => Quality.effectLabel(_effectKey);

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
  bool get isMiniPlayerDismissed => _isMiniPlayerDismissed;

  void dismissMiniPlayer() {
    if (!_isMiniPlayerDismissed) {
      _isMiniPlayerDismissed = true;
      notifyListeners();
    }
  }

  void showMiniPlayer() {
    if (_isMiniPlayerDismissed) {
      _isMiniPlayerDismissed = false;
      notifyListeners();
    }
  }
  bool get isFmMode => _queue.type == QueueType.fm;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get error => _error;
  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0.0;

  // ─── Palette & lyric getters ───
  ExtractedPalette? get palette => _palette;

  /// The lyric controller driving the [LyricView] in PlayerScreen.
  LyricController get lyricController => _lyricController;

  bool get lyricLoading => _lyricLoading;
  Map<int, List<String>> get lyricLangMap => _lyricLangMap;
  List<KrcLyricLineModel>? get krcLines => _krcLines;
  int get selectedLyricLang => _selectedLyricLang;
  bool get showTranslation => _showTranslation;
  bool get hasLangData => _lyricLangMap.isNotEmpty;

  /// Returns all available palette colours for the flowing light effect.
  /// Prefers the quantized [topColors] for richer variety, falls back to
  /// the hand-picked targets.
  ///
  /// Always stretches the lightness range to [0.12, 0.85] so the blobs
  /// have visibly deep darks and bright lights while keeping the original
  /// hue/saturation and the proportional spacing (natural gradation).
  List<Color> get paletteColors {
    final p = _palette;
    if (p == null) {
      _cachedPaletteColors = null;
      if (_backgroundColor != null) {
        return [_backgroundColor!, _backgroundColor!.withValues(alpha: 0.7), _backgroundColor!.withValues(alpha: 0.5)];
      }
      return const [Color(0xFF121212), Color(0xFF1DB954), Color(0xFF2A2D28)];
    }

    if (_cachedPaletteColors != null) return _cachedPaletteColors!;

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
    final lightnesses =
        colors.map((c) => HSLColor.fromColor(c).lightness).toList();
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

    // ── Ensure at least 3 colors for the flow light effect ──
    // When an album cover has poor colour variety the extractor may return
    // 1-2 colours.  We synthesize additional variants so the blob layer
    // always has enough material for a visually interesting result.
    const int minFlowColors = 3;
    while (colors.length < minFlowColors) {
      final src = colors.isEmpty ? const Color(0xFF121212) : colors.last;
      final hsl = HSLColor.fromColor(src);
      // Alternate lighter/darker so each new colour is perceptibly different.
      final double delta = ((colors.length % 2) == 0 ? 0.18 : -0.18) * colors.length;
      colors.add(
        hsl
            .withLightness((hsl.lightness + delta).clamp(0.05, 0.95))
            .toColor(),
      );
    }

    _cachedPaletteColors = colors;
    return colors;
  }

  Color? get backgroundColor => _backgroundColor;

  Future<List<Song>> Function()? get playlistEndProvider =>
      _queue.playlistEndProvider;
  set playlistEndProvider(Future<List<Song>> Function()? v) {
    _queue.playlistEndProvider = v;
  }

  PlayerProvider(this._musicService,
      {required MusicAudioHandler audioHandler,
      AudioSettingsProvider? audioSettings,
      LikedSongsProvider? likedSongs})
      : _audioSettings = audioSettings,
        _likedSongs = likedSongs,
        _audioHandler = audioHandler {
    _engine = AudioEngine(_musicService);
    _queue = PlaylistQueue();

    _onPositionChanged = () {
      _position = _engine.position.value;
      _lyricController.setProgress(_position);
      // 对 UI rebuild 节流：200ms 内最多通知一次。
      // 歌词同步仍保持高精度，不随 notifyListeners 节流。
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastPositionNotifyMs > 200) {
        _lastPositionNotifyMs = now;
        notifyListeners();
      }
      if (sleepTimerRemaining != null && sleepTimerRemaining!.inSeconds <= 0) {
        _engine.pause();
        _isPlaying = false;
        cancelSleepTimer();
        notifyListeners();
      }
      // 通知更新策略：
      // - 歌词行切换时 → 即时更新（锁屏歌词不卡顿）
      // - 仅位置变化 → 每 10 秒节流（用于蓝牙 A2DP 进度同步）
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
      if (!_isLoading) {
        // 加载完成（成功或失败）时同步底层的播放状态
        _isPlaying = _engine.isPlaying.value;
        // 加载期间播放事件可能被 isLoading 保护跳过，
        // 加载完成时必须强制刷新一次系统通知，否则控制栏状态会滞留旧值
        _updateNotification();
      }
      notifyListeners();
    };
    _engine.isLoading.addListener(_onLoadingChanged);

    _onErrorChanged = () {
      _error = _engine.error.value;
      notifyListeners();
    };
    _engine.error.addListener(_onErrorChanged);

    _onPlayingChanged = () {
      if (_engine.isLoading.value) {
        // 正在加载新歌时，不要让上一首 stop() 引起的 isPlaying=false 覆盖当前为 true 的状态
        return;
      }
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

    // 启动后恢复上次的播放状态和队列列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      restorePlaybackState();
      restoreQueueNames();
    });
  }

  /// Clears the entire playlist.
  void clearPlaylist() {
    _queue.setPlaylist([]);
    notifyListeners();
  }

  void clearError() {
    _engine.clearError();
  }

  void _updateNotification() {
    final song = _queue.currentSong;
    if (song == null) {
      _audioHandler.cancelNotification();
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
    final liked = _likedSongs?.likedIds.contains(song.id) ?? false;
    final modeLabel = switch (_queue.playMode) {
      PlayMode.sequential => 'sequential',
      PlayMode.shuffle => 'shuffle',
      PlayMode.repeatOne => 'repeatOne',
      PlayMode.radio => 'sequential',
    };
    _audioHandler.updateNotification(
      id: song.id.toString(),
      title: song.name,
      artist: song.artistDisplay,
      albumArtUrl: song.albumCoverUrl,
      lyricLine: lyricLine,
      isPlaying: _isPlaying,
      durationSec: _duration.inSeconds,
      positionSec: _position.inSeconds,
      isBuffering: _engine.isLoading.value,
      speed: _engine.speed,
      liked: liked,
      playMode: modeLabel,
    );
  }

  /// 将当前播放状态持久化到 SharedPreferences（杀进程后恢复用）。
  /// 保存完整队列（上限 200 首）、当前歌曲、进度、模式。
  /// 使用单个 JSON 字符串一次性写入，避免 13 次独立 prefs 写入。
  Future<void> _savePlaybackState() async {
    final song = _queue.currentSong;
    if (song == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueLimit = _queue.playlist.take(200);
      final state = {
        'songId': song.id,
        'name': song.name,
        'hash': song.hash ?? '',
        'artist': song.artistDisplay,
        'cover': song.albumCoverUrl ?? '',
        'albumId': song.albumId,
        'positionMs': _position.inMilliseconds,
        'playMode': _queue.playMode.name,
        'quality': _qualityLevel,
        'speed': _engine.speed,
        'filePath': song.filePath ?? '',
        'queueIndex': _queue.currentIndex,
        'queue': queueLimit.map((s) => {
          'id': s.id,
          'name': s.name,
          'hash': s.hash ?? '',
          'artist': s.artistDisplay,
          'cover': s.albumCoverUrl ?? '',
          'albumId': s.albumId,
          'filePath': s.filePath ?? '',
          'isLocal': s.isLocal,
          'lyrics': s.lyrics ?? '',
        }).toList(),
      };
      await prefs.setString(_keySavedPlaybackStateV2, jsonEncode(state));
    } catch (_) {}
  }

  /// 从 SharedPreferences 恢复播放状态。
  /// 仅供初始化时调用，不自动播放 —— 只让 Mini Bar 显示上次的歌曲。
  Future<void> restorePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v2Str = prefs.getString(_keySavedPlaybackStateV2);
      if (v2Str != null && v2Str.isNotEmpty) {
        await _restoreFromV2(v2Str);
        return;
      }
      // 兼容旧版分 key 存储
      await _restoreLegacy(prefs);
    } catch (_) {}
  }

  /// 从新版单个 JSON 字符串恢复。
  Future<void> _restoreFromV2(String v2Str) async {
    final state = jsonDecode(v2Str) as Map<String, dynamic>;
    final queueJson = (state['queue'] as List<dynamic>?) ?? [];
    final savedIndex = (state['queueIndex'] as num?)?.toInt() ?? 0;
    final restoreSongs = queueJson.isNotEmpty
        ? _parseQueueJson(queueJson)
        : _singleSongFromState(state);
    _applyRestoredState(restoreSongs, savedIndex, state);
  }

  /// 兼容旧版分 key 存储的恢复逻辑。
  Future<void> _restoreLegacy(SharedPreferences prefs) async {
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
    final savedSpeed = prefs.getDouble('playback_saved_speed');

    final queueJsonStr = prefs.getString(_keySavedQueueJson);
    final savedIndex = prefs.getInt(_keySavedQueueIndex) ?? 0;
    final savedFilePath = prefs.getString('playback_saved_file_path') ?? '';
    final restoreSongs = (queueJsonStr != null && queueJsonStr.isNotEmpty)
        ? _parseQueueJson(jsonDecode(queueJsonStr) as List<dynamic>)
        : [
            Song(
              id: songId,
              name: songName,
              artists: songArtist.split(' / '),
              albumCoverUrl: songCover.isNotEmpty ? songCover : null,
              albumId: songAlbumId,
              hash: songHash.isNotEmpty ? songHash : null,
              filePath: savedFilePath.isNotEmpty ? savedFilePath : null,
            ),
          ];

    _applyRestoredState(
      restoreSongs,
      savedIndex,
      {
        'positionMs': positionMs,
        'playMode': modeName,
        'quality': quality,
        'speed': savedSpeed,
      },
    );
  }

  /// 从队列 JSON 列表解析 [Song] 列表。
  List<Song> _parseQueueJson(List<dynamic> list) {
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final isLocal = m['isLocal'] == true;
      final filePath = m['filePath'] as String? ?? '';
      return Song(
        id: m['id'] as int,
        name: m['name'] as String? ?? '',
        artists: (m['artist'] as String? ?? '').split(' / '),
        albumCoverUrl: (m['cover'] is String && (m['cover'] as String).isNotEmpty)
            ? m['cover'] as String
            : null,
        albumId: (m['albumId'] as num?)?.toInt() ?? 0,
        hash: (m['hash'] is String && (m['hash'] as String).isNotEmpty)
            ? m['hash'] as String
            : null,
        filePath: isLocal && filePath.isNotEmpty ? filePath : null,
        lyrics: m['lyrics'] as String?,
      );
    }).toList();
  }

  /// 从新版 state 中单曲降级恢复（无队列时）。
  List<Song> _singleSongFromState(Map<String, dynamic> state) {
    final cover = state['cover'] as String?;
    final hash = state['hash'] as String?;
    final filePath = state['filePath'] as String? ?? '';
    return [
      Song(
        id: (state['songId'] as num?)?.toInt() ?? 0,
        name: state['name'] as String? ?? '',
        artists: (state['artist'] as String? ?? '').split(' / '),
        albumCoverUrl: cover != null && cover.isNotEmpty ? cover : null,
        albumId: (state['albumId'] as num?)?.toInt() ?? 0,
        hash: hash != null && hash.isNotEmpty ? hash : null,
        filePath: filePath.isNotEmpty ? filePath : null,
      ),
    ];
  }

  /// 应用恢复的歌曲列表和状态。
  void _applyRestoredState(List<Song> restoreSongs, int savedIndex, Map<String, dynamic> state) {
    final validIndex = savedIndex.clamp(0, restoreSongs.length - 1);
    _queue.setPlaylist(restoreSongs, startIndex: validIndex);
    _qualityLevel = (state['quality'] as num?)?.toInt() ?? 0;
    _engine.qualityLevel = _qualityLevel;
    _position = Duration(milliseconds: (state['positionMs'] as num?)?.toInt() ?? 0);
    final modeName = state['playMode'] as String? ?? 'sequential';
    final mode = PlayMode.values.where((m) => m.name == modeName).firstOrNull;
    if (mode != null) _queue.setPlayMode(mode);
    // 应用音质设置 & uploadHistory 开关（覆盖引擎默认值）
    _applyQualityFromSettings();
    final savedSpeed = (state['speed'] as num?)?.toDouble();
    if (savedSpeed != null && savedSpeed > 0) {
      _engine.setSpeed(savedSpeed);
    }

    final current = _queue.currentSong;
    if (current != null) {
      // 1. 冷启动立即提取专辑流光和KRM元数据
      _onSongChanged(current);
      // 2. 冷启动立即拉取歌词（支持本地内嵌及网络歌词）
      loadLyricsForSong(current);
      // 3. 异步预查特权以在播放前同步正确的最高音质级别
      _engine.precheckPrivilege(current);
    }

    notifyListeners();
  }

  /// 应用音质设置后直接调用引擎播放（用于自动切歌等非用户触发的播放）
  void _enginePlayWithQuality(Song? song, {int? version}) {
    final s = song ?? _queue.currentSong;
    if (s == null) return;
    _applyQualityFromSettings();
    _engine.play(s, version: version ?? _engine.currentVersion, effectKey: _effectKey);
  }

  void _onComplete() {
    if (!_engine.isCompleting.value) return;
    // 重入保护：极短歌曲或异步回调可能触发多次
    if (_handlingComplete) return;
    _handlingComplete = true;
    final current = _queue.currentSong;
    if (current == null) {
      _handlingComplete = false;
      return;
    }
    // FM 模式：上报歌曲播放完成反馈（完整播完）
    if (_queue.type == QueueType.fm) {
      _fmPlaybackUpdateCallback?.call(current, playtime: current.duration);
      debugPrint('[FM] _onComplete: idx=${_queue.currentIndex}/${_queue.playlist.length}'
          ' hasEndProvider=${_queue.playlistEndProvider != null}'
          ' song=${current.name}');
    }
    switch (_queue.playMode) {
      case PlayMode.repeatOne:
        _engine.isCompleting.value = false;
        _engine.seekAndPlay(Duration.zero);
        _handlingComplete = false;
        return; // 不切歌，无需通知
      case PlayMode.shuffle:
        final idx = _queue.nextIndex();
        if (idx == null) {
          _handlingComplete = false;
          return;
        }
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
          return;
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
          return;
        }
        break;
    }
    _handlingComplete = false;
    // 通知 UI 更新歌词、封面等信息
    _lyricController.loadLyricModel(LyricModel(lines: []));
    _climaxMs = null;
    _isPlaying = true;
    
    final nextSong = _queue.currentSong;
    if (nextSong != null) {
      loadLyricsForSong(nextSong);
      _onSongChanged(nextSong);
      _engine.precheckPrivilege(nextSong);
    }
    notifyListeners();
  }

  Future<void> _loadMoreAndContinue() async {
    if (_queue.isLoadingMore) return;
    _queue.setLoadingMore(true);
    _isLoading = true;
    notifyListeners();
    debugPrint('[FM] _loadMoreAndContinue: START type=${_queue.type}');
    try {
      final moreSongs = await _queue.playlistEndProvider?.call() ?? [];
      debugPrint('[FM] _loadMoreAndContinue: got ${moreSongs.length} songs,'
          ' queueLen=${_queue.playlist.length} curIdx=${_queue.currentIndex}');
      if (moreSongs.isNotEmpty) {
        _queue.append(moreSongs);
        _queue.setLoadingMore(false);
        _engine.resetForNewSong();
        _queue.playIndex(_queue.currentIndex + 1);
        final next = _queue.currentSong;
        if (next != null) {
          loadLyricsForSong(next);
          _onSongChanged(next);
          _engine.precheckPrivilege(next);
          _enginePlayWithQuality(next);
          _handlingComplete = false;
          return;
        }
      }
    } catch (e, s) {
      Log.e('player_provider', 'loadMore error', e, s);
    }
    _queue.setLoadingMore(false);
    _isLoading = false;
    _handlingComplete = false;
    _updateNotification();
    notifyListeners();
  }

  /// 获取当前网络应是 WiFi 还是蜂窝，用于选择对应的音质设置。
  bool get _isWifi {
    // connectivity_plus 6.x checkConnectivity 返回 Future，同步调用无效
    // 降级为返回 true（WiFi），避免类型强转崩溃
    return true;
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
    // 同步淡入设置到引擎
    _engine.crossfadeMs = settings.crossfadeEnabled ? settings.crossfadeMs : 0;
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _queue.playlist.length) return;
    _queue.playIndex(index);
    // Reset state for new song
    _isMiniPlayerDismissed = false;
    _engine.clearError();
    _lyricController.loadLyricModel(LyricModel(lines: []));
    _climaxMs = null;
    _lastNotifLyricIdx = -1;
    final current = _queue.currentSong;
    if (current == null) return;

    // 1. 立即加载新歌歌词（支持本地内嵌及网络）
    loadLyricsForSong(current);
    // 2. 立即提取专辑流光和KRM元数据
    _onSongChanged(current);
    // 3. 异步预查特权以立刻在 UI 展现最高可用音质
    _engine.precheckPrivilege(current);

    _applyQualityFromSettings();
    _engine.resetForNewSong();
    _isPlaying = true; // ← 立即标记，UI 及时响应
    notifyListeners();
    final version = _engine.currentVersion;
    await _engine.play(current, version: version, effectKey: _effectKey);
    _updateNotification();
    // 异步查询高潮时间（不阻塞播放，失败静默）
    _fetchClimax(current);
    // Upload play history via new API
    if (current.mixSongId != null) {
      _musicService.uploadMixPlayHistory(current.mixSongId.toString());
    }
    // FM 模式：上报歌曲开始播放，让 API 获知当前上下文
    if (_queue.type == QueueType.fm) {
      _fmPlaybackUpdateCallback?.call(current, playtime: 0);
    }
    notifyListeners();
  }

  /// Load embedded lyrics (song.lyrics) into the lyric controller.
  /// Supports both LRC format and plain text.
  void _loadEmbeddedLyrics(Song song) {
    if (song.lyrics == null || song.lyrics!.isEmpty) return;
    final text = song.lyrics!;
    // 检测 LRC 格式：[mm:ss.xx] 或 [mm:ss] 出现在内容中（不限行首）
    if (RegExp(r'\[\d{2}:\d{2}([.:]\d{2,3})?\]').hasMatch(text)) {
      _lyricController.loadLyric(text);
    } else {
      // 纯文本：每行作为一行歌词
      final lines = text
          .split(RegExp(r'[\r\n]+'))
          .where((l) => l.trim().isNotEmpty)
          .map((l) => LyricLine(
                start: Duration.zero,
                text: l.trim(),
              ))
          .toList();
      if (lines.isNotEmpty) {
        _lyricController.loadLyricModel(LyricModel(lines: lines));
      }
    }
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
    // 退出 FM 模式（恢复普通队列，下方 setPlaylist 会覆盖为新的播放列表）
    if (_queue.type == QueueType.fm) {
      exitFmMode();
    }
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
    // Delegate to playIndex for unified playback logic
    await playIndex(_queue.currentIndex);
  }

  /// 启动私人 FM 播放列表（独立队列）
  ///
  /// 自动保存当前普通队列快照，切换到 FM 独立队列（QueueType.fm）。
  /// 退出 FM 模式后自动恢复普通队列。
  void startFmPlaylist(List<Song> songs,
      {required Future<List<Song>> Function() bufferProvider,
      VoidCallback? onDislike,
      void Function(Song song, {int playtime})? onPlaybackUpdate}) {
    if (songs.isEmpty) return;
    // 进入 FM 模式前保存当前普通队列快照
    if (_queue.type != QueueType.fm) {
      _fmSavedNormalSnapshot = FmQueueSnapshot(
        songs: List.from(_queue.playlist),
        index: _queue.currentIndex,
        playMode: _queue.playMode,
      );
    }
    _queue.setType(QueueType.fm);
    _fmDislikeCallback = onDislike;
    _fmPlaybackUpdateCallback = onPlaybackUpdate;
    _queue.playlistEndProvider = null;
    _engine.clearError();
    _queue.setPlaylist(songs, startIndex: 0);
    _queue.setPlayMode(PlayMode.sequential);
    _queue.playlistEndProvider = bufferProvider;
    playIndex(0);
  }

  /// 退出 FM 模式，恢复之前保存的普通队列快照。
  ///
  /// 调用后队列类型恢复为 [QueueType.normal]。
  /// 如果 [exitFmMode] 后紧接着调用 [playSong] 等设置新播放列表的方法，
  /// 恢复的快照会被覆盖，这是预期行为。
  void exitFmMode() {
    if (_queue.type != QueueType.fm) return;
    debugPrint('[FM] exitFmMode: restoring saved queue'
        ' (${_fmSavedNormalSnapshot?.songs.length ?? 0} songs)');
    _queue.playlistEndProvider = null;
    _fmDislikeCallback = null;
    _fmPlaybackUpdateCallback = null;
    _queue.setType(QueueType.normal);
    if (_fmSavedNormalSnapshot != null) {
      _queue.setPlaylist(
        List.from(_fmSavedNormalSnapshot!.songs),
        startIndex: _fmSavedNormalSnapshot!.index,
      );
      _queue.setPlayMode(_fmSavedNormalSnapshot!.playMode);
    }
    _fmSavedNormalSnapshot = null;
    notifyListeners();
  }

  /// 替换 FM 播放列表（用于切换模式/算法池时立即更新播放内容）
  /// 不保存/恢复队列快照，保留现有 FM 回调。前一首歌到下一首的过渡动画由调用方处理。
  void replaceFmPlaylist(List<Song> songs,
      {required Future<List<Song>> Function() bufferProvider}) {
    if (songs.isEmpty) return;
    _queue.playlistEndProvider = null; // 防止切换过程中触发加载
    _engine.clearError();
    _queue.setPlaylist(songs, startIndex: 0);
    _queue.setPlayMode(PlayMode.sequential);
    _queue.playlistEndProvider = bufferProvider;
    playIndex(0);
  }

  /// 将整张歌单/专辑追加到当前队列末尾。
  /// 不改变当前播放，新歌曲按顺序加到最后。
  void enqueuePlaylist(List<Song> songs) {
    if (songs.isEmpty) return;
    _queue.append(songs);
    notifyListeners();
  }

  void addToQueue(Song song) {
    _queue.append([song]);
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
        await _engine.play(song, version: version, effectKey: _effectKey);
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
    // FM 模式：上一曲变成「不喜欢 + 下一首」
    if (_queue.type == QueueType.fm) {
      _fmDislikeCallback?.call();
      playNext();
      return;
    }
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
    notifyListeners();
    _savePlaybackState();
  }

  void removeFromQueue(int index) {
    final wasCurrent = index == _queue.currentIndex;
    _queue.removeAt(index);
    if (wasCurrent && _queue.playlist.isNotEmpty) {
      playIndex(_queue.currentIndex);
    }
  }

  void moveInQueue(int from, int to) {
    _queue.move(from, to);
  }

  void playNextSong(Song song) {
    _queue.insertAt(_queue.currentIndex + 1, song);
  }

  // ─── 多队列管理 ───

  /// 队列名称 → 歌曲列表
  final Map<String, List<Song>> _savedQueues = {};
  static const _keySavedQueueNames = 'saved_queue_names';

  /// 所有已保存的队列名称列表
  List<String> get savedQueueNames => _savedQueues.keys.toList();

  /// 获取已保存队列的歌曲列表
  List<Song>? playlistOfSavedQueue(String name) => _savedQueues[name];

  /// 将当前播放队列保存为指定名称
  void saveQueueAs(String name) {
    _savedQueues[name] = List.from(_queue.playlist);
    notifyListeners();
    _persistQueueNames();
  }

  /// 加载已保存的队列替换当前播放列表
  void loadQueue(String name) {
    final songs = _savedQueues[name];
    if (songs == null) return;
    _queue.setPlaylist(List.from(songs), startIndex: 0);
    notifyListeners();
  }

  /// 删除已保存的队列
  void deleteQueue(String name) {
    _savedQueues.remove(name);
    notifyListeners();
    _persistQueueNames();
  }

  /// 将当前队列追加到已保存队列末尾
  void appendToSavedQueue(String name) {
    _savedQueues[name]?.addAll(_queue.playlist);
    notifyListeners();
    _persistQueueNames();
  }

  /// 持久化队列名称列表（仅保存名称，歌曲数据在内存中）
  Future<void> _persistQueueNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _keySavedQueueNames, jsonEncode(_savedQueues.keys.toList()));
    } catch (_) {}
  }

  /// 从 SharedPreferences 恢复队列名称列表
  Future<void> restoreQueueNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keySavedQueueNames);
      if (json != null && json.isNotEmpty) {
        final names = jsonDecode(json) as List<dynamic>;
        for (final name in names) {
          _savedQueues[name as String] = [];
        }
      }
    } catch (_) {}
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

  /// 获取当前歌曲的实际可用音质 key 列表（来自 privilege）
  /// privilege 无数据时回退到全部 levels
  List<String> getAvailableQualities() {
    final opts = _engine.currentQualityOptions;
    if (opts.isNotEmpty) {
      return opts.map((o) => o.value).toList();
    }
    return List.unmodifiable(Quality.levels);
  }

  /// 检查某个音质 key 当前是否可用
  bool isQualityAvailable(String key) {
    final opts = _engine.currentQualityOptions;
    if (opts.isEmpty) return true; // 无 privilege 数据时全部可用
    return opts.any((o) => o.value == key);
  }

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
        currentPosition: _position, effectKey: _effectKey);

    // 切换成功后强制刷新歌词
    if (success) {
      _lyricController.loadLyricModel(LyricModel(lines: []));
    }
    notifyListeners();
    return success;
  }

  /// 设置音效（保持播放进度）
  Future<bool> setEffect(String effectKey) async {
    final normalized = Quality.normalizeEffect(effectKey);
    if (_effectKey == normalized) return true;
    _effectKey = normalized;
    notifyListeners();

    // 如果正在播放，用 engine 重新加载带效果/不带效果的 URL
    if (_isPlaying || _isPlayerScreenVisible) {
      final song = _queue.currentSong;
      if (song != null && song.hash != null && song.hash!.isNotEmpty) {
        await _engine.switchQuality(song,
            Quality.levels[_qualityLevel % Quality.levels.length],
            currentPosition: _position,
            effectKey: _effectKey);
      }
    }
    return true;
  }

  /// 检查音效当前是否有 privilege 可用
  bool isEffectAvailable(String key) {
    if (key == 'none') return true;
    final opts = _engine.currentEffectOptions;
    if (opts.isEmpty) return false;
    return opts.any((o) => o.value == key);
  }

  // ──────────────────────────────────────────────────────────────
  //  Palette extraction
  // ──────────────────────────────────────────────────────────────

  /// Extracts a color palette from [song]'s cover using its
  /// [Song.coverImageProvider] (handles both network and local file:// URIs).
  Future<void> _extractPaletteFromCover(Song song) async {
    if (song.albumCoverUrl == null) return;
    try {
      _cachedPaletteColors = null;
      final provider = song.coverImageProvider;
      _palette = await PaletteExtractor.instance
          .extractFromProvider(provider, song.albumCoverUrl!);
      _backgroundColor = _palette?.dominant;
      notifyListeners();
    } catch (_) {
      // Palette extraction is cosmetic — ignore failures.
    }
  }

  Future<void> _loadKrmAudio(Song song) async {
    _currentKrmAudio = null;
    final songId = song.mixSongId ?? song.id;
    if (songId <= 0 || song.isLocal) return;

    try {
      final data = await _musicService.getKrmAudio(songId);
      if (data == null || currentSong?.id != song.id) return;

      // ── hash 校验：确认 /krm/audio 返回的确实是同一首歌 ──
      // 酷狗 KRM 数据库中部分 mixSongId 映射错乱，会返回其他歌曲的元数据。
      // 用音频内容唯一指纹 hash 做精确比对，不匹配则丢弃。
      final krmHash = (data['base'] as Map?)?['hash'] as String?;
      if (krmHash != null &&
          song.hash != null &&
          krmHash.toUpperCase() != song.hash!.toUpperCase()) {
        Log.w('KRM', 'hash 不匹配，丢弃 KRM 数据: '
            'song.hash=${song.hash}, krm.hash=$krmHash');
        return;
      }

      _currentKrmAudio = data;
      notifyListeners();
    } catch (_) {}
  }

  void _onSongChanged(Song song) {
    _extractPaletteFromCover(song);
    _loadKrmAudio(song);
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
    _lyricLangMap = {};
    _krcLines = null;
    _selectedLyricLang = 0;
    _lyricController.loadLyricModel(LyricModel(lines: []));
    notifyListeners();
    _updateNotification();
  }

  // ─── 歌词自动拉取与转换核心逻辑 ───

  void loadLyricsForSong(Song song) {
    _lyricLangMap = {};
    _krcLines = null;
    _selectedLyricLang = 0;

    // 1. 本地/已嵌入歌词直接加载
    if (song.lyrics != null && song.lyrics!.isNotEmpty) {
      _lyricLoading = false;
      _loadEmbeddedLyrics(song);
      notifyListeners();
      return;
    }

    // 2. 线上歌曲通过 Hash 加载歌词
    if (song.hash != null) {
      _lyricLoading = true;
      notifyListeners();
      _loadLyrics(song.hash!, songName: song.name);
    } else {
      clearLyrics();
    }
  }

  Future<void> _loadLyrics(String hash, {String? songName}) async {
    try {
      final searchRes =
          await _musicService.searchLyricByHash(hash, keywords: songName);
      final data = searchRes['data'] as Map<String, dynamic>? ?? searchRes;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = int.parse(c['id'].toString());
        final key = c['accesskey'] as String? ?? '';

        // 优先 KRC
        final krcBytes = await _musicService.fetchKrcContent(id, key);
        if (krcBytes.isNotEmpty) {
          try {
            final krcModel = KrcLyricUtil.parseLyrics(krcBytes);
            if (krcModel.krcLyricList.isEmpty) throw 'empty krc';

            _lyricLangMap = {};
            if (krcModel.lyricTag.language != null &&
                krcModel.lyricTag.language!.isNotEmpty) {
              try {
                final langJson = jsonDecode(
                  utf8.decode(base64Decode(krcModel.lyricTag.language!)),
                );
                final krcLang = KrcLanguage.fromJson(langJson);
                for (final c in krcLang.content) {
                  _lyricLangMap[c.language] = c.lyricContent
                      .map((words) => words.join())
                      .toList();
                }
              } catch (e, s) {
                Log.e('player_provider', 'krc lang parse error', e, s);
              }
            }

            _krcLines = krcModel.krcLyricList;
            _selectedLyricLang = _lyricLangMap.keys.contains(0)
                ? 0
                : (_lyricLangMap.keys.firstOrNull ?? 0);

            final transMap = _buildTransMap(_selectedLyricLang);
            final lines = _buildLyricLines(krcModel.krcLyricList, transMap);

            if (hash == _queue.currentSong?.hash) {
              _lyricController.loadLyricModel(LyricModel(lines: lines));
              _updateNotification();
            }
            _lyricLoading = false;
            notifyListeners();
            return;
          } catch (e, s) {
            Log.e('player_provider', 'krc parse error', e, s);
          }
        }

        // 降级 LRC
        final rawContent = await _musicService.fetchLyricContent(id, key);
        if (rawContent.isNotEmpty) {
          try {
            String decoded;
            try {
              decoded = utf8.decode(base64Decode(rawContent));
            } catch (_) {
              decoded = rawContent;
            }
            if (hash == _queue.currentSong?.hash) {
              _lyricController.loadLyric(decoded);
              _updateNotification();
            }
          } catch (e, s) {
            Log.e('player_provider', 'lrc parse error', e, s);
          }
        }
      } else {
        clearLyrics();
      }
    } catch (e, s) {
      Log.e('player_provider', 'lyric load error', e, s);
    }
    _lyricLoading = false;
    notifyListeners();
  }

  Map<int, String> _buildTransMap(int lang) {
    final map = <int, String>{};
    final lines = _lyricLangMap[lang];
    if (lines == null || _krcLines == null) return map;
    for (int i = 0; i < _krcLines!.length && i < lines.length; i++) {
      if (lines[i].isNotEmpty) {
        map[_krcLines![i].startTime] = lines[i];
      }
    }
    return map;
  }

  List<LyricLine> _buildLyricLines(
    List<KrcLyricLineModel> krcLines,
    Map<int, String> transMap,
  ) {
    final result = <LyricLine>[];
    for (final line in krcLines) {
      String text;
      try {
        text = line.getWordLine();
      } catch (_) {
        continue;
      }
      if (text.trim().isEmpty) continue;

      final words = <LyricWord>[];
      if (line.line != null) {
        final lineStart = line.startTime;
        for (final w in line.line!) {
          if (w.word == null || w.word!.isEmpty) continue;
          final ws = (w.startTime ?? 0) + lineStart;
          final we = ws + (w.duration ?? 0);
          words.add(LyricWord(
            text: w.word!,
            start: Duration(milliseconds: ws),
            end: Duration(milliseconds: we),
          ));
        }
      }

      result.add(LyricLine(
        start: Duration(milliseconds: line.startTime),
        end: Duration(milliseconds: line.startTime + line.duration),
        text: text,
        words: words.isNotEmpty ? words : null,
        translation: _showTranslation ? transMap[line.startTime] : null,
      ));
    }
    return result;
  }

  void applyLyricLang(int lang) {
    if (_krcLines == null || !_lyricLangMap.containsKey(lang)) return;
    _selectedLyricLang = lang;
    _showTranslation = true;
    final transMap = _buildTransMap(lang);
    final lines = _buildLyricLines(_krcLines!, transMap);
    _lyricController.loadLyricModel(LyricModel(lines: lines));
    notifyListeners();
  }

  void toggleTranslation() {
    _showTranslation = !_showTranslation;
    if (_showTranslation) {
      applyLyricLang(_selectedLyricLang);
    } else {
      final lines = _buildLyricLines(_krcLines ?? [], {});
      _lyricController.loadLyricModel(LyricModel(lines: lines));
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

  // ✅ 新增适配代码：当前音量（平板手势调音量基准）
  double get volume => _engine.volume;

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
