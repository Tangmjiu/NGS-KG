import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';

class LikedSongsProvider extends ChangeNotifier {
  /// 收藏歌单 listid，与酷狗官方客户端同步（2 = "我喜欢"）
  static const int likedListId = 2;

  final MusicService _musicService;
  final Set<int> _likedIds = {};
  final Map<int, int> _fileidMap = {};
  bool _loaded = false;

  Set<int> get likedIds => _likedIds;
  bool get isLoaded => _loaded;

  void clear() {
    _likedIds.clear();
    _fileidMap.clear();
    _loaded = false;
    notifyListeners();
  }

  LikedSongsProvider(this._musicService) {
    _retryLoad();
  }

  /// 延迟重试加载，等 AuthProvider 就绪（最多重试 5 次）
  void _retryLoad({int attempt = 1}) {
    if (attempt > 5) return;
    Future.delayed(Duration(milliseconds: 500 * attempt), () {
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

  Future<void> load() async {
    if (!_hasLogin) return;
    try {
      final songs = await _musicService.getPlaylistTracksById(likedListId);
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
    try {
      final data = song.hash.isNotEmpty
          ? '${song.name}|${song.hash}|${song.albumId}|${song.audioId}'
          : song.name;
      final res = await _musicService.addTracksToPlaylist(likedListId, data);
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
      notifyListeners();
      return true;
    } catch (e, s) {
      Log.e('liked_songs_provider', 'error', e, s);
      return false;
    }
  }

  Future<bool> _unlike(SongInfo song) async {
    try {
      final fileid = _fileidMap[song.id];
      if (fileid != null) {
        await _musicService.removeTracksFromPlaylist(
            likedListId, fileid.toString());
      }
      _likedIds.remove(song.id);
      _fileidMap.remove(song.id);
      notifyListeners();
      return true;
    } catch (e, s) {
      Log.e('liked_songs_provider', 'error', e, s);
      return false;
    }
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
