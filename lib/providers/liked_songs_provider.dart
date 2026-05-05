import 'package:flutter/foundation.dart';
import '../services/music_service.dart';

class LikedSongsProvider extends ChangeNotifier {
  final MusicService _musicService = MusicService();
  final Set<int> _likedIds = {};
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
      for (final s in songs) {
        final id = s['audio_id'] ?? s['id'] ?? 0;
        _likedIds.add(id is int ? id : int.tryParse(id.toString()) ?? 0);
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
      await _musicService.addTracksToPlaylist(1, data);
      _likedIds.add(song.id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _unlike(SongInfo song) async {
    try {
      final songs = await _musicService.getPlaylistTracksById(1);
      final match = songs.firstWhere(
        (s) => (s['audio_id'] ?? s['id']) == song.id,
        orElse: () => <String, dynamic>{},
      );
      final fileid = match['fileid'];
      if (fileid != null) {
        await _musicService.removeTracksFromPlaylist(1, fileid.toString());
      }
      _likedIds.remove(song.id);
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
