import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../services/music_service.dart';

class PlaylistProvider extends ChangeNotifier {
  final MusicService _musicService = MusicService();

  List<Playlist> _topPlaylists = [];
  PlaylistDetail? _currentPlaylist;
  bool _isLoading = false;

  List<Playlist> get topPlaylists => _topPlaylists;
  PlaylistDetail? get currentPlaylist => _currentPlaylist;
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
}
