import 'package:flutter/foundation.dart';
import '../models/radio.dart';
import '../models/playlist.dart';
import '../models/rank_entry.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../models/scene_category.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../constants/discover_constants.dart';
import 'player_provider.dart';

/// 发现页状态管理
///
/// 替代原来 _DiscoverScreenState 中的 15 个 List 字段，
/// 统一管理所有区块数据、加载状态、错误处理。
class DiscoverProvider extends ChangeNotifier {
  final MusicService _musicService;

  DiscoverProvider(this._musicService);

  // ─── 数据 ───

  List<RadioStation> _fmList = [];
  List<Playlist> _topPlaylists = [];
  List<RankEntry> _rankList = [];
  List<Song> _topSongs = [];
  List<Album> _topAlbums = [];
  List<SceneCategory> _sceneCategories = [];
  List<Map<String, dynamic>> _ipList = [];
  List<Song> _personalFmSongs = [];

  // ─── 私人 FM 状态 ───
  String _fmMode = 'normal';                       // normal=红心 small=小众 peak=速览
  int _fmPoolId = 0;                               // 0=口味(Alpha) 1=风格(Beta) 2=探索(Gamma)
  List<Song> _personalFmBuffer = [];               // 预取缓冲池
  static const int _fmBufferThreshold = 4;          // 自动补货阈值
  bool _isFmActive = false;                        // 当前是否处于 FM 播放模式
  Map<String, dynamic>? _currentFmFeedback;         // 当前歌曲反馈数据 {hash, songid, playtime}

  // ─── 状态 ───

  bool _loading = true;
  String? _error;

  // ─── Getters ───

  List<RadioStation> get fmList => _fmList;
  List<Playlist> get topPlaylists => _topPlaylists;
  List<RankEntry> get rankList => _rankList;
  List<Song> get topSongs => _topSongs;
  List<Album> get topAlbums => _topAlbums;
  List<SceneCategory> get sceneCategories => _sceneCategories;
  List<Map<String, dynamic>> get ipList => _ipList;
  List<Song> get personalFmSongs => _personalFmSongs;
  bool get loading => _loading;
  String? get error => _error;

  // ─── FM Getters ───
  String get fmMode => _fmMode;
  int get fmPoolId => _fmPoolId;
  List<Song> get personalFmBuffer => _personalFmBuffer;
  bool get isFmActive => _isFmActive;

  bool get hasPlaylists => _topPlaylists.isNotEmpty;
  bool get hasRanks => _rankList.isNotEmpty;
  bool get hasTopSongs => _topSongs.isNotEmpty;
  bool get hasTopAlbums => _topAlbums.isNotEmpty;
  bool get hasScenes => _sceneCategories.isNotEmpty;
  bool get hasIp => _ipList.isNotEmpty;
  bool get hasFm => _fmList.isNotEmpty;
  bool get hasPersonalFm => _personalFmSongs.isNotEmpty;

  // ─── 加载 ───

  /// 加载全部发现数据（首屏 + 下拉刷新）
  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadFm(),
        _loadPlaylists(),
        _loadRanks(),
        _loadTopSongs(),
        _loadTopAlbums(),
        _loadSceneCategories(),
        _loadIp(),
        _loadPersonalFm(),
      ]);
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadAll error', e, s);
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadFm() async {
    try {
      final fm = await _musicService.getFmRecommend();
      _fmList = fm.take(DiscoverConstants.fmLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadFm error', e, s);
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      _topPlaylists =
          await _musicService.getTopPlaylists(limit: DiscoverConstants.playlistLimit);
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadPlaylists error', e, s);
    }
  }

  Future<void> _loadRanks() async {
    try {
      final ranks = await _musicService.getRankList();
      _rankList = ranks.take(DiscoverConstants.rankLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadRanks error', e, s);
    }
  }

  Future<void> _loadTopSongs() async {
    try {
      final songs = await _musicService.getTopSongs();
      _topSongs = songs.take(DiscoverConstants.topSongsLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadTopSongs error', e, s);
    }
  }

  Future<void> _loadTopAlbums() async {
    try {
      _topAlbums = await _musicService.getTopAlbums(
        pageSize: DiscoverConstants.topAlbumsPageSize,
      );
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadTopAlbums error', e, s);
    }
  }

  Future<void> _loadSceneCategories() async {
    try {
      final scenes = await _musicService.getSceneLists();
      _sceneCategories = scenes.take(DiscoverConstants.sceneLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadSceneCategories error', e, s);
    }
  }

  Future<void> _loadIp() async {
    try {
      final ip = await _musicService.getTopIp();
      _ipList = ip.take(DiscoverConstants.ipLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadIp error', e, s);
    }
  }

  Future<void> _loadPersonalFm() async {
    try {
      final raw = await _musicService.getPersonalFm(mode: _fmMode, songPoolId: _fmPoolId);
      debugPrint('[FM] getPersonalFm raw count: ${raw.length}');
      final songs = raw
          .map((e) => SongMapper.fromFmJson(e))
          .whereType<Song>()
          .toList();
      debugPrint('[FM] after mapping: ${songs.length} songs');
      if (songs.isNotEmpty) {
        debugPrint('[FM] first song: ${songs.first.name} / ${songs.first.artistDisplay} / cover: ${songs.first.albumCoverUrl}');
      }
      // 去重
      final deduped = <Song>[];
      for (final song in songs) {
        if (!deduped.any((existing) =>
            (existing.hash != null && song.hash != null && existing.hash == song.hash) ||
            (existing.mixSongId != null && song.mixSongId != null && existing.mixSongId == song.mixSongId) ||
            existing.id == song.id)) {
          deduped.add(song);
        }
      }
      _personalFmSongs = deduped.take(DiscoverConstants.topSongsLimit).toList();
      _personalFmBuffer = List.from(_personalFmSongs);
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadPersonalFm error', e, s);
    }
  }

  // ═══════════════════════════════════════════
  //  私人 FM 操作方法
  // ═══════════════════════════════════════════

  /// 切换 FM 推荐模式（不中断当前播放，下次补货使用新模式）
  void setFmMode(String mode) {
    if (mode == _fmMode) return;
    _fmMode = mode;
    // 不清理 buffer，不退出 FM 状态 — 下次 _refillFmBuffer 会使用新模式
    notifyListeners();
  }

  /// 切换 AI 算法池（不中断当前播放，下次补货使用新算法池）
  void setFmPoolId(int poolId) {
    if (poolId == _fmPoolId) return;
    _fmPoolId = poolId;
    // 不清理 buffer，不退出 FM 状态 — 下次 _refillFmBuffer 会使用新算法池
    notifyListeners();
  }

  /// 提供者回调：由 PlayerProvider 在 FM 队列播完时调用，获取下一批歌曲
  /// 始终先补货再取歌，确保不返回空列表
  Future<List<Song>> fetchNextFmBatch() async {
    // 先补货
    await _refillFmBuffer();
    // 从 buffer 取最多 10 首
    final batchSize = _personalFmBuffer.length >= 10 ? 10 : _personalFmBuffer.length;
    if (batchSize == 0) return [];
    final batch = _personalFmBuffer.take(batchSize).toList();
    _personalFmBuffer.removeRange(0, batch.length);
    notifyListeners();
    return batch;
  }

  /// 补货缓冲池（携带当前反馈数据）
  ///
  /// [isOverplay] 当前歌曲是否完整播完（1=是，0=跳过），传入 -1 表示从 _fmPendingOverplay 读取
  Future<void> _refillFmBuffer({int isOverplay = 0}) async {
    try {
      final raw = await _musicService.getPersonalFm(
        mode: _fmMode,
        songPoolId: _fmPoolId,
        hash: _currentFmFeedback?['hash'] as String?,
        songid: _currentFmFeedback?['songid'] as int?,
        playtime: _currentFmFeedback?['playtime'] as int?,
        action: 'play',
        isOverplay: isOverplay,
        remainSongcnt: _personalFmBuffer.length,
      );
      final newSongs = raw
          .map((e) => SongMapper.fromFmJson(e))
          .whereType<Song>()
          .toList();
      // 去重合并：以 hash > mixSongId > id 三级 key 去重
      for (final song in newSongs) {
        if (!_songExistsInBuffer(song)) {
          _personalFmBuffer.add(song);
        }
      }
      notifyListeners();
    } catch (e, s) {
      Log.e('DiscoverProvider', '_refillFmBuffer error', e, s);
    }
  }

  /// 由 UI 调用：刷新 FM 缓冲池（例如切换模式/算法池后触发预取）
  Future<void> refreshFmBuffer() async {
    if (_personalFmBuffer.length > _fmBufferThreshold) return;
    await _refillFmBuffer();
  }

  /// 三级 key 去重：hash > mixSongId > id
  bool _songExistsInBuffer(Song song) {
    return _personalFmBuffer.any((existing) =>
        (existing.hash != null &&
            song.hash != null &&
            existing.hash == song.hash) ||
        (existing.mixSongId != null &&
            song.mixSongId != null &&
            existing.mixSongId == song.mixSongId) ||
        existing.id == song.id);
  }

  /// 上报「不喜欢」并获取替代推荐
  Future<List<Song>> dislikeCurrentFmSong(Song song) async {
    try {
      final raw = await _musicService.getPersonalFm(
        mode: _fmMode,
        songPoolId: _fmPoolId,
        hash: song.hash,
        songid: song.mixSongId ?? song.id,
        playtime: 0,
        action: 'garbage',
        isOverplay: 0,
        remainSongcnt: _personalFmBuffer.length,
      );
      final newSongs = raw
          .map((e) => SongMapper.fromFmJson(e))
          .whereType<Song>()
          .toList();
      // 去重合并
      for (final song in newSongs) {
        if (!_songExistsInBuffer(song)) {
          _personalFmBuffer.add(song);
        }
      }
      notifyListeners();
      return newSongs;
    } catch (e, s) {
      Log.e('DiscoverProvider', 'dislikeCurrentFmSong error', e, s);
      return [];
    }
  }

  /// 更新当前 FM 歌曲的反馈数据（播放时由 PlayerProvider 调用）
  void updateFmFeedback(Song song, {int playtime = 0}) {
    _currentFmFeedback = {
      'hash': song.hash,
      'songid': song.mixSongId ?? song.id,
      'playtime': playtime,
    };
  }

  /// 启动私人 FM 播放
  Future<void> startFmPlayback(PlayerProvider player) async {
    if (_personalFmBuffer.isEmpty) {
      await _refillFmBuffer();
    }
    if (_personalFmBuffer.isNotEmpty) {
      final initialSongs = _personalFmBuffer.take(10).toList();
      _personalFmBuffer.removeRange(0, initialSongs.length);
      _isFmActive = true;
      notifyListeners();
      // 传入 dislike 回调，让 player 在上一曲时触发
      player.startFmPlaylist(
        initialSongs,
        bufferProvider: fetchNextFmBatch,
        onDislike: () => _fmDislikeCallback(player),
      );
    }
  }

  /// 被 PlayerProvider 调用的 dislike 回调
  void _fmDislikeCallback(PlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return;
    dislikeCurrentFmSong(song);
  }
}
