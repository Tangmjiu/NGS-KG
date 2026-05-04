import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../services/music_service.dart';

class PlaylistProvider extends ChangeNotifier {
  final MusicService _musicService = MusicService();

  List<Playlist> _topPlaylists = [];
  PlaylistDetail? _currentPlaylist;
  List<Playlist> _userPlaylists = [];
  bool _isLoading = false;

  List<Playlist> get topPlaylists => _topPlaylists;
  PlaylistDetail? get currentPlaylist => _currentPlaylist;
  List<Playlist> get userPlaylists => _userPlaylists;
  bool get isLoading => _isLoading;

  Future<void> fetchTopPlaylists({int limit = 30}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _topPlaylists = await _musicService.getTopPlaylists(limit: limit);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPlaylistDetail(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentPlaylist = await _musicService.getPlaylistDetail(id);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPlaylistByGcId(String gcId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentPlaylist = await _musicService.getPlaylistDetailByGcId(gcId);
    } catch (e) {
      // Fallback: fetch tracks directly
      try {
        final songs = await _musicService.getPlaylistTracks(gcId);
        _currentPlaylist = PlaylistDetail(
          playlist: Playlist(id: 0, name: '', globalCollectionId: gcId),
          songs: songs,
        );
      } catch (_) {}
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchUserPlaylist(int? userId) async {
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _userPlaylists = await _musicService.getUserPlaylist(userId: userId);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }
}
