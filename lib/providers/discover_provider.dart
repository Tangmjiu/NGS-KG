// SPDX-License-Identifier: MIT
import 'dart:async';
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
import '../services/api_exception.dart';

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
  String _fmMode = 'normal'; // normal=红心 small=小众 peak=速览
  int _fmPoolId = 0; // 0=口味(Alpha) 1=风格(Beta) 2=探索(Gamma)
  List<Song> _personalFmBuffer = []; // 预取缓冲池
  PlayerProvider? _fmPlayer;
  VoidCallback? _fmPlayerListener;
  bool _observedFmMode = false;
  int _fmRevision = 0;
  int _fmPlaybackRequestId = 0;
  int _fmDataRequestId = 0;
  Future<void>? _fmRefillInFlight;
  Future<List<Song>>? _fmBatchInFlight;
  Map<String, dynamic>? _currentFmFeedback; // 当前歌曲反馈数据 {hash, songid, playtime}

  // ─── 状态 ───

  bool _loading = true;
  String? _error;
  bool _loaded = false;
  bool _disposed = false;
  Future<void>? _loadInFlight;

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
  bool get isFmActive => _fmPlayer?.isFmMode ?? false;

  bool get hasPlaylists => _topPlaylists.isNotEmpty;
  bool get hasRanks => _rankList.isNotEmpty;
  bool get hasTopSongs => _topSongs.isNotEmpty;
  bool get hasTopAlbums => _topAlbums.isNotEmpty;
  bool get hasScenes => _sceneCategories.isNotEmpty;
  bool get hasIp => _ipList.isNotEmpty;
  bool get hasFm => _fmList.isNotEmpty;
  bool get hasPersonalFm => _personalFmSongs.isNotEmpty;

  // ─── 加载 ───

  /// 首次加载（空结果也视为已尝试，避免组件重挂载触发循环请求）。
  Future<void> ensureLoaded() => loadAll(force: false);

  /// 加载全部发现数据；并发调用共享同一批请求，下拉刷新默认重新加载。
  Future<void> loadAll({bool force = true}) {
    if (_disposed) return Future<void>.value();
    final inFlight = _loadInFlight;
    if (inFlight != null) return inFlight;
    if (!force && _loaded) return Future<void>.value();
    final completer = Completer<void>();
    _loadInFlight = completer.future;
    _loading = true;
    _error = null;
    notifyListeners();
    _loadAll(completer);
    return completer.future;
  }

  Future<void> _loadAll(Completer<void> completer) async {
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
      _error = friendlyError(e);
    } finally {
      _loaded = true;
      _loading = false;
      _loadInFlight = null;
      if (!_disposed) notifyListeners();
      completer.complete();
    }
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
      _topPlaylists = await _musicService.getTopPlaylists(
          limit: DiscoverConstants.playlistLimit);
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
    final pending = _fmRefillInFlight;
    if (pending != null) {
      await pending;
      return;
    }
    final revision = _fmRevision;
    final requestId = ++_fmDataRequestId;
    final playbackRequestId = _fmPlaybackRequestId;
    try {
      final raw = await _musicService.getPersonalFm(
          mode: _fmMode, songPoolId: _fmPoolId);
      if (_disposed ||
          revision != _fmRevision ||
          requestId != _fmDataRequestId) {
        return;
      }
      final songs =
          _parseFmSongs(raw).take(DiscoverConstants.topSongsLimit).toList();
      _personalFmSongs = songs;
      // 页面刷新可以更新预览，但不能替换正在使用的推荐缓冲。
      if (!isFmActive && playbackRequestId == _fmPlaybackRequestId) {
        _personalFmBuffer = List.of(songs);
      }
    } catch (error, stack) {
      Log.e('DiscoverProvider', 'loadPersonalFm error', error, stack);
    }
  }

  static List<Song> _parseFmSongs(List<Map<String, dynamic>> raw) {
    final songs = <Song>[];
    for (final item in raw) {
      final song = SongMapper.fromFmJson(item);
      if (song == null || songs.any((other) => _sameSong(other, song))) {
        continue;
      }
      songs.add(song);
    }
    return songs;
  }

  static bool _sameSong(Song first, Song second) =>
      (first.hash?.isNotEmpty == true && first.hash == second.hash) ||
      (first.mixSongId != null && first.mixSongId == second.mixSongId) ||
      (first.id > 0 && first.id == second.id);

  void _invalidateFmRequests({bool clearBuffer = false}) {
    _fmRevision++;
    _fmPlaybackRequestId++;
    _fmDataRequestId++;
    _fmRefillInFlight = null;
    _fmBatchInFlight = null;
    if (clearBuffer) _personalFmBuffer.clear();
  }

  void _bindFmPlayer(PlayerProvider player) {
    if (identical(_fmPlayer, player)) return;
    if (_fmPlayerListener != null) {
      _fmPlayer?.removeListener(_fmPlayerListener!);
    }
    _fmPlayer = player;
    _observedFmMode = player.isFmMode;
    _fmPlayerListener = () {
      if (_disposed || _observedFmMode == player.isFmMode) return;
      final wasFm = _observedFmMode;
      _observedFmMode = player.isFmMode;
      if (wasFm && !_observedFmMode) {
        _invalidateFmRequests(clearBuffer: true);
        _currentFmFeedback = null;
      }
      notifyListeners();
    };
    player.addListener(_fmPlayerListener!);
  }

  /// 参数变化让旧推荐作废；播放中的歌曲由调用方决定何时切换。
  void setFmMode(String mode) {
    if (_disposed || mode == _fmMode) return;
    _fmMode = mode;
    _personalFmSongs = [];
    _invalidateFmRequests(clearBuffer: true);
    notifyListeners();
  }

  void setFmPoolId(int poolId) {
    if (_disposed || poolId == _fmPoolId) return;
    _fmPoolId = poolId;
    _personalFmSongs = [];
    _invalidateFmRequests(clearBuffer: true);
    notifyListeners();
  }

  /// 队列同时请求下一批时共享一次取歌，避免重复消费缓冲。
  Future<List<Song>> fetchNextFmBatch() {
    if (_disposed) return Future.value(<Song>[]);
    final pending = _fmBatchInFlight;
    if (pending != null) return pending;
    final revision = _fmRevision;
    late final Future<List<Song>> request;
    request = (() async {
      await _refillFmBuffer();
      if (_disposed || revision != _fmRevision) return <Song>[];
      final songs = _personalFmBuffer.take(10).toList();
      _personalFmBuffer.removeRange(0, songs.length);
      notifyListeners();
      return songs;
    })()
        .whenComplete(() {
      if (identical(_fmBatchInFlight, request)) _fmBatchInFlight = null;
    });
    _fmBatchInFlight = request;
    return request;
  }

  Future<void> _refillFmBuffer({int isOverplay = 0}) {
    if (_disposed) return Future.value();
    final pending = _fmRefillInFlight;
    if (pending != null) return pending;
    final revision = _fmRevision;
    final requestId = ++_fmDataRequestId;
    final mode = _fmMode;
    final pool = _fmPoolId;
    final feedback = _currentFmFeedback;
    late final Future<void> request;
    request = (() async {
      try {
        final raw = await _musicService.getPersonalFm(
          mode: mode,
          songPoolId: pool,
          hash: feedback?['hash'] as String?,
          songid: feedback?['songid'] as int?,
          playtime: feedback?['playtime'] as int?,
          action: 'play',
          isOverplay: isOverplay,
          remainSongcnt: _personalFmBuffer.length,
        );
        if (_disposed ||
            revision != _fmRevision ||
            requestId != _fmDataRequestId) {
          return;
        }
        for (final song in _parseFmSongs(raw)) {
          if (!_personalFmBuffer.any((other) => _sameSong(other, song))) {
            _personalFmBuffer.add(song);
          }
        }
        notifyListeners();
      } catch (error, stack) {
        Log.e('DiscoverProvider', 'refillFmBuffer error', error, stack);
      }
    })()
        .whenComplete(() {
      if (identical(_fmRefillInFlight, request)) _fmRefillInFlight = null;
    });
    _fmRefillInFlight = request;
    return request;
  }

  Future<void> refreshFmBuffer() => _refillFmBuffer();

  Future<void> replaceFmBuffer() {
    if (_disposed) return Future.value();
    _invalidateFmRequests(clearBuffer: true);
    return _refillFmBuffer();
  }

  /// 最新的模式切换才可替换队列，退出 FM 后迟到结果不得重新接管播放。
  Future<void> switchFmPlayback(PlayerProvider player) async {
    if (_disposed || !player.isFmMode) return;
    _bindFmPlayer(player);
    _invalidateFmRequests(clearBuffer: true);
    final revision = _fmRevision;
    final requestId = _fmPlaybackRequestId;
    final playbackIntentVersion = player.playbackIntentVersion;
    await _refillFmBuffer();
    if (_disposed ||
        revision != _fmRevision ||
        requestId != _fmPlaybackRequestId ||
        playbackIntentVersion != player.playbackIntentVersion ||
        !player.isFmMode) {
      return;
    }
    if (_personalFmBuffer.isEmpty) return;
    final songs = _personalFmBuffer.take(10).toList();
    _personalFmBuffer.removeRange(0, songs.length);
    player.replaceFmPlaylist(songs, bufferProvider: fetchNextFmBatch);
    notifyListeners();
  }

  Future<List<Song>> dislikeCurrentFmSong(Song song) async {
    if (_disposed) return [];
    final revision = _fmRevision;
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
      if (_disposed || revision != _fmRevision) return [];
      final songs = _parseFmSongs(raw);
      for (final replacement in songs) {
        if (!_personalFmBuffer.any((other) => _sameSong(other, replacement))) {
          _personalFmBuffer.add(replacement);
        }
      }
      notifyListeners();
      return songs;
    } catch (error, stack) {
      Log.e('DiscoverProvider', 'dislikeCurrentFmSong error', error, stack);
      return [];
    }
  }

  void updateFmFeedback(Song song, {int playtime = 0}) {
    if (_disposed) return;
    _currentFmFeedback = {
      'hash': song.hash,
      'songid': song.mixSongId ?? song.id,
      'playtime': playtime,
    };
  }

  Future<void> startFmPlayback(PlayerProvider player) async {
    if (_disposed) return;
    _bindFmPlayer(player);
    final revision = _fmRevision;
    final requestId = ++_fmPlaybackRequestId;
    final playbackIntentVersion = player.playbackIntentVersion;
    final previousSong = player.currentSong;
    final previousQueue = List<Song>.of(player.playlist);
    final previousFmMode = player.isFmMode;
    if (_personalFmBuffer.isEmpty) await _refillFmBuffer();
    if (_disposed ||
        revision != _fmRevision ||
        requestId != _fmPlaybackRequestId ||
        playbackIntentVersion != player.playbackIntentVersion ||
        !identical(player.currentSong, previousSong) ||
        !listEquals(player.playlist, previousQueue) ||
        player.isFmMode != previousFmMode ||
        _personalFmBuffer.isEmpty) {
      return;
    }
    final songs = _personalFmBuffer.take(10).toList();
    _personalFmBuffer.removeRange(0, songs.length);
    player.startFmPlaylist(
      songs,
      bufferProvider: fetchNextFmBatch,
      onDislike: () {
        final song = player.currentSong;
        if (song != null && player.isFmMode) dislikeCurrentFmSong(song);
      },
      onPlaybackUpdate: updateFmFeedback,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidateFmRequests(clearBuffer: true);
    if (_fmPlayerListener != null) {
      _fmPlayer?.removeListener(_fmPlayerListener!);
    }
    _fmPlayer = null;
    super.dispose();
  }
}
