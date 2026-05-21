import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../models/playlist.dart';
import '../services/music_service.dart';

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

  Future<void> fetchTopPlaylists({int limit = 30}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _topPlaylists = await _musicService.getTopPlaylists(limit: limit);
    } catch (e, s) { Log.e('playlist_provider', 'error', e, s); }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPlaylistDetail(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentPlaylist = await _musicService.getPlaylistDetail(id);
      if (_currentPlaylist!.songs.isEmpty) {
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
    } catch (e, s) { Log.e('playlist_provider', 'error', e, s); }
  }

  Future<void> fetchUserPlaylist(int? userId) async {
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _userPlaylists = await _musicService.getUserPlaylist(userId: userId);
    } catch (e, s) { Log.e('playlist_provider', 'error', e, s); }
    _isLoading = false;
    notifyListeners();
  }
}
