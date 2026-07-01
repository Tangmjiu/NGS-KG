import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../models/playlist.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';

class PlaylistProvider extends ChangeNotifier {
  final MusicService _musicService;

  List<Playlist> _topPlaylists = [];

  PlaylistProvider(this._musicService);
  PlaylistDetail? _currentPlaylist;
  List<Playlist> _userPlaylists = [];
  bool _isLoading = false;

  List<Playlist> get topPlaylists => _topPlaylists;
  PlaylistDetail? get currentPlaylist => _currentPlaylist;
  List<Playlist> get userPlaylists => _userPlaylists;
  bool get isLoading => _isLoading;

  int? get _currentUserId {
    final uid = ApiClient.userId;
    if (uid != null && uid.isNotEmpty && uid != '0') {
      return int.tryParse(uid);
    }
    return null;
  }

  Future<void> fetchTopPlaylists({int limit = 30}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _topPlaylists = await _musicService.getTopPlaylists(limit: limit);
    } catch (e, s) {
      Log.e('playlist_provider', 'error', e, s);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPlaylistDetail(String id) async {
    _isLoading = true;
    _currentPlaylist = null;  // Clear previous playlist immediately
    notifyListeners();
    try {
      _currentPlaylist = await _musicService.getPlaylistDetail(id);
      if (_currentPlaylist?.songs.isEmpty ?? true) {
        await _fetchTracksFallback(id);
      }
    } catch (e) {
      await _fetchTracksFallback(id);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchTracksFallback(String id) async {
    try {
      final songs = await _musicService.getPlaylistTracks(id);
      _currentPlaylist = PlaylistDetail(
        playlist: _currentPlaylist?.playlist ??
            Playlist(id: 0, name: '', globalCollectionId: id),
        songs: songs,
      );
    } catch (e, s) {
      Log.e('playlist_provider', 'error', e, s);
    }
  }

  Future<bool> createPlaylist(String name, {int isPri = 0}) async {
    try {
      await _musicService.createPlaylist(name, isPri: isPri);
      final uid = _currentUserId ?? int.tryParse(ApiClient.userId ?? '');
      if (uid != null) {
        await fetchUserPlaylist(uid);
      } else {
        _isLoading = false;
        notifyListeners();
      }
      return true;
    } catch (e, s) {
      Log.e('playlist_provider', 'createPlaylist error', e, s);
      return false;
    }
  }

  Future<bool> deletePlaylist(int listid) async {
    try {
      await _musicService.deletePlaylist(listid);
      final uid = _currentUserId ?? int.tryParse(ApiClient.userId ?? '');
      if (uid != null) {
        await fetchUserPlaylist(uid);
      } else {
        _isLoading = false;
        notifyListeners();
      }
      return true;
    } catch (e, s) {
      Log.e('playlist_provider', 'deletePlaylist error', e, s);
      return false;
    }
  }

  Future<void> fetchUserPlaylist(int? userId) async {
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _userPlaylists = await _musicService.getUserPlaylist(userId: userId);
    } catch (e, s) {
      Log.e('playlist_provider', 'error', e, s);
    }
    _isLoading = false;
    notifyListeners();
  }
}
