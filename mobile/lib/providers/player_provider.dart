import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/music_service.dart';

enum PlayMode { sequential, shuffle, repeatOne }

class PlayerProvider extends ChangeNotifier {
  final MusicService _musicService = MusicService();

  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;
  PlayMode _playMode = PlayMode.sequential;
  bool _isPlaying = false;
  bool _isLoading = false;

  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  PlayMode get playMode => _playMode;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  void playSong(Song song, {List<Song>? playlist}) {
    if (playlist != null) {
      _playlist = playlist;
      _currentIndex = playlist.indexWhere((s) => s.id == song.id);
    }
    _currentSong = song;
    _isPlaying = true;
    notifyListeners();
  }

  void togglePlayPause() {
    if (_currentSong != null) {
      _isPlaying = !_isPlaying;
      notifyListeners();
    }
  }

  void playNext() {
    if (_playlist.isEmpty) return;
    switch (_playMode) {
      case PlayMode.sequential:
        _currentIndex = (_currentIndex + 1) % _playlist.length;
        break;
      case PlayMode.shuffle:
        _currentIndex = DateTime.now().microsecondsSinceEpoch % _playlist.length;
        break;
      case PlayMode.repeatOne:
        break;
    }
    _currentSong = _playlist[_currentIndex];
    _isPlaying = true;
    notifyListeners();
  }

  void playPrevious() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    _currentSong = _playlist[_currentIndex];
    _isPlaying = true;
    notifyListeners();
  }

  void setPlaylist(List<Song> songs, {int startIndex = 0}) {
    _playlist = songs;
    _currentIndex = startIndex;
    if (songs.isNotEmpty) {
      _currentSong = songs[startIndex];
    }
    notifyListeners();
  }
}
