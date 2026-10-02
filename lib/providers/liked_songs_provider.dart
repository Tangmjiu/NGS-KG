import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../models/song.dart';

class LikedSongsProvider extends ChangeNotifier {
  /// 收藏歌单 listid，与酷狗官方客户端同步（2 = "我喜欢"）
  static const int likedListId = 2;

  final MusicService _musicService;
  final Set<int> _likedIds = {};
  final Map<int, int> _fileidMap = {};
  List<Song> _songs = [];
  bool _loaded = false;
  Timer? _retryTimer;
  Future<void>? _loadInFlight;
  String? _loadUserId;
  int _loadVersion = 0;
  bool _disposed = false;

  Set<int> get likedIds => _likedIds;
  List<Song> get songs => _songs;
  bool get isLoaded => _loaded;

  void clear() {
    ++_loadVersion;
    _loadInFlight = null;
    _loadUserId = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _likedIds.clear();
    _fileidMap.clear();
    _songs.clear();
    _loaded = false;
    notifyListeners();
  }

  LikedSongsProvider(this._musicService) {
    _retryLoad();
  }

  /// 延迟重试加载，等 AuthProvider 就绪（最多重试 5 次）
  void _retryLoad({int attempt = 1}) {
    if (_disposed || attempt > 5) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: 500 * attempt), () {
      _retryTimer = null;
      if (_disposed) return;
      if (!_loaded && _hasLogin) {
        load();
      } else if (!_loaded) {
        _retryLoad(attempt: attempt + 1);
      }
    });
  }

  /// 未登录时 userId 为空或 '0'，跳过加载静默处理
  bool get _hasLogin {
    final uid = ApiClient.userId;
    return uid != null && uid.isNotEmpty && uid != '0';
  }

  Future<void> load({bool force = false}) {
    if (_disposed || !_hasLogin) return Future<void>.value();
    final userId = ApiClient.userId!;
    final inFlight = _loadInFlight;
    if (!force && _loadUserId == userId && inFlight != null) {
      return inFlight;
    }
    final version = ++_loadVersion;
    final completer = Completer<void>();
    _loadInFlight = completer.future;
    if (_loadUserId != userId) {
      _songs = [];
      _likedIds.clear();
      _fileidMap.clear();
      _loaded = false;
    }
    _loadUserId = userId;
    _retryTimer?.cancel();
    _retryTimer = null;
    _loadSongs(userId, version, completer);
    return completer.future;
  }

  bool _isCurrentLoad(String userId, int version) =>
      !_disposed && version == _loadVersion && ApiClient.userId == userId;

  Future<void> _loadSongs(String userId, int version,
      Completer<void> completer) async {
    try {
      // 优先使用新版接口（带 pagesize=1000 以便拉齐所有收藏）
      var songs = await _musicService.getPlaylistTracksNew(
          likedListId, pageSize: 1000);
      if (!_isCurrentLoad(userId, version)) return;
      if (songs.isEmpty) {
        songs = await _musicService.getPlaylistTracksById(likedListId);
        if (!_isCurrentLoad(userId, version)) return;
      }
      _songs = songs;
      _likedIds.clear();
      _fileidMap.clear();
      for (final s in songs) {
        _likedIds.add(s.id);
        if (s.fileId != null) _fileidMap[s.id] = s.fileId!;
      }
      _loaded = true;
      notifyListeners();
    } catch (e, s) {
      Log.e('liked_songs_provider', 'error', e, s);
    } finally {
      if (version == _loadVersion) _loadInFlight = null;
      completer.complete();
    }
  }

  Future<bool> toggle(SongInfo song) async {
    if (_likedIds.contains(song.id)) {
      return _unlike(song);
    } else {
      return _like(song);
    }
  }

  Future<bool> _like(SongInfo song) async {
    if (_disposed || !_hasLogin) return false;
    final userId = ApiClient.userId;
    try {
      final data = song.hash.isNotEmpty
          ? '${song.name}|${song.hash}|${song.albumId}|${song.audioId}'
          : song.name;
      final res = await _musicService.addTracksToPlaylist(likedListId, data);
      if (_disposed || ApiClient.userId != userId) return false;
      _likedIds.add(song.id);
      final dataMap = res['data'] as Map?;
      if (dataMap != null) {
        final info = dataMap['info'] as List?;
        if (info != null && info.isNotEmpty) {
          final fid = (info[0] as Map)['fileid'];
          if (fid != null) {
            _fileidMap[song.id] =
                fid is int ? fid : int.tryParse(fid.toString()) ?? 0;
          }
        }
      }
      // 喜欢成功后重新全量拉取，保持 _songs 歌曲模型数组数据更新
      await load(force: true);
      return true;
    } catch (e, s) {
      Log.e('liked_songs_provider', 'error', e, s);
      return false;
    }
  }

  Future<bool> _unlike(SongInfo song) async {
    if (_disposed || !_hasLogin) return false;
    final userId = ApiClient.userId;
    try {
      final fileid = _fileidMap[song.id];
      if (fileid != null) {
        await _musicService.removeTracksFromPlaylist(
            likedListId, fileid.toString());
      }
      if (_disposed || ApiClient.userId != userId) return false;
      // 取消收藏已改变服务端快照，不能让之前开始的列表请求将它加回来。
      // 若旧请求还在补齐其他刚收藏的歌曲，必须补一次删除后的同步。
      final needsRefresh = _loadInFlight != null;
      ++_loadVersion;
      _loadInFlight = null;
      _likedIds.remove(song.id);
      _fileidMap.remove(song.id);
      _songs.removeWhere((s) => s.id == song.id);
      notifyListeners();
      if (needsRefresh) await load(force: true);
      return true;
    } catch (e, s) {
      Log.e('liked_songs_provider', 'error', e, s);
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_loadVersion;
    _retryTimer?.cancel();
    super.dispose();
  }
}

class SongInfo {
  final int id;
  final String name;
  final String hash;
  final int albumId;
  final int audioId;

  const SongInfo({
    required this.id,
    required this.name,
    this.hash = '',
    this.albumId = 0,
    this.audioId = 0,
  });
}
