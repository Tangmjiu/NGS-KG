import 'package:flutter/foundation.dart';
import '../services/music_service.dart';

class LikedSongsProvider extends ChangeNotifier {
  final MusicService _musicService = MusicService();
  final Set<int> _likedIds = {};
  final Map<int, int> _fileidMap = {};
  bool _loaded = false;

  Set<int> get likedIds => _likedIds;
  bool get isLoaded => _loaded;

  LikedSongsProvider() {
    load();
  }

  Future<void> load() async {
    try {
      final songs = await _musicService.getPlaylistTracksById(1);
      _likedIds.clear();
      _fileidMap.clear();
      for (final s in songs) {
        final id = s['audio_id'] ?? s['id'] ?? 0;
        final aid = id is int ? id : int.tryParse(id.toString()) ?? 0;
        _likedIds.add(aid);
        final fid = s['fileid'];
        if (fid != null) _fileidMap[aid] = fid is int ? fid : int.tryParse(fid.toString()) ?? 0;
      }
      _loaded = true;
      notifyListeners();
    } catch (_) {}
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
      final res = await _musicService.addTracksToPlaylist(1, data);
      _likedIds.add(song.id);
      final dataMap = res['data'] as Map?;
      if (dataMap != null) {
        final info = dataMap['info'] as List?;
        if (info != null && info.isNotEmpty) {
          final fid = (info[0] as Map)['fileid'];
          if (fid != null) {
            _fileidMap[song.id] = fid is int ? fid : int.tryParse(fid.toString()) ?? 0;
          }
        }
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _unlike(SongInfo song) async {
    try {
      final fileid = _fileidMap[song.id];
      if (fileid != null) {
        await _musicService.removeTracksFromPlaylist(1, fileid.toString());
      }
      _likedIds.remove(song.id);
      _fileidMap.remove(song.id);
      notifyListeners();
      return true;
    } catch (_) {
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
