import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

enum PlayMode { sequential, shuffle, repeatOne, radio }

class PlaylistQueue extends ValueNotifier<int> {
  final Random _random = Random();

  List<Song> _playlist = [];
  int _currentIndex = 0;
  PlayMode _playMode = PlayMode.sequential;
  List<int> _shuffleOrder = [];
  int _shufflePos = 0;

  bool _isLoadingMore = false;

  Future<List<Song>> Function()? playlistEndProvider;

  PlaylistQueue() : super(0);

  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  PlayMode get playMode => _playMode;
  bool get isLoadingMore => _isLoadingMore;
  Song? get currentSong =>
      _playlist.isNotEmpty && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  void setPlaylist(List<Song> songs, {int startIndex = 0}) {
    _playlist = songs;
    _currentIndex = startIndex;
    _shuffleOrder = [];
    notifyListeners();
  }

  void playIndex(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    notifyListeners();
  }

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    if (mode == PlayMode.shuffle) _initShuffle();
    notifyListeners();
  }

  bool hasNext() {
    if (_playlist.isEmpty) return false;
    switch (_playMode) {
      case PlayMode.repeatOne:
        return true;
      case PlayMode.shuffle:
        return _shuffleOrder.isNotEmpty;
      case PlayMode.sequential:
      case PlayMode.radio:
        return _currentIndex + 1 < _playlist.length ||
            playlistEndProvider != null;
    }
  }

  int? nextIndex() {
    if (_playlist.isEmpty) return null;
    switch (_playMode) {
      case PlayMode.shuffle:
        return _nextShuffleIndex();
      case PlayMode.repeatOne:
        return _currentIndex;
      case PlayMode.sequential:
        if (_currentIndex + 1 < _playlist.length) {
          return _currentIndex + 1;
        }
        return null; // caller checks playlistEndProvider
      case PlayMode.radio:
        if (_currentIndex + 1 < _playlist.length) {
          return _currentIndex + 1;
        }
        return null;
    }
  }

  int? previousIndex() {
    if (_playlist.isEmpty) return null;
    if (_playMode == PlayMode.shuffle) {
      _shufflePos = (_shufflePos - 1 + _shuffleOrder.length) % _shuffleOrder.length;
      return _shuffleOrder[_shufflePos];
    }
    return (_currentIndex - 1 + _playlist.length) % _playlist.length;
  }

  void append(List<Song> songs) {
    if (songs.isEmpty) return;
    _playlist.addAll(songs);
    notifyListeners();
  }

  void setLoadingMore(bool v) {
    _isLoadingMore = v;
    notifyListeners();
  }

  void _initShuffle() {
    _shuffleOrder = List.generate(_playlist.length, (i) => i);
    _shuffleOrder.shuffle(_random);
    final currentPos = _shuffleOrder.indexOf(_currentIndex);
    if (currentPos >= 0) {
      _shuffleOrder.removeAt(currentPos);
      _shuffleOrder.insert(0, _currentIndex);
      _shufflePos = 0;
    } else {
      _shufflePos = -1;
    }
  }

  int _nextShuffleIndex() {
    if (_shuffleOrder.isEmpty) _initShuffle();
    _shufflePos = (_shufflePos + 1) % _shuffleOrder.length;
    if (_shufflePos == 0 && _shuffleOrder.length > 1) {
      final last = _shuffleOrder.last;
      _shuffleOrder.shuffle(_random);
      if (_shuffleOrder[0] == last && _shuffleOrder.length > 1) {
        _shuffleOrder[0] = _shuffleOrder[1];
        _shuffleOrder[1] = last;
      }
    }
    return _shuffleOrder[_shufflePos];
  }
}
