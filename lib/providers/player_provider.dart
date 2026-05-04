import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';
import '../services/music_service.dart';

enum PlayMode { sequential, shuffle, repeatOne }

class PlayerProvider extends ChangeNotifier {
  final MusicService _musicService = MusicService();
  final AudioPlayer _player = AudioPlayer();

  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;
  PlayMode _playMode = PlayMode.sequential;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;

  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  PlayMode get playMode => _playMode;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  double get progress =>
      _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

  PlayerProvider() {
    _positionSub = _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _stateSub = _player.onPlayerComplete.listen((_) => _onComplete());
  }

  void _onComplete() {
    switch (_playMode) {
      case PlayMode.repeatOne:
        playIndex(_currentIndex);
        break;
      case PlayMode.shuffle:
        final next = DateTime.now().microsecondsSinceEpoch % _playlist.length;
        playIndex(next);
        break;
      case PlayMode.sequential:
        if (_currentIndex + 1 < _playlist.length) {
          playIndex(_currentIndex + 1);
        } else {
          _isPlaying = false;
          notifyListeners();
        }
        break;
    }
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    _currentSong = _playlist[index];
    _isPlaying = true;
    _isLoading = true;
    notifyListeners();
    try {
      final song = _currentSong!;
      if (song.isLocal && song.filePath != null) {
        await _player.play(DeviceFileSource(song.filePath!));
      } else {
        final songUrl = await _musicService.getSongUrl(song.id, hash: song.hash);
        if (songUrl.url.isNotEmpty) {
          await _player.play(UrlSource(songUrl.url));
        }
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    if (playlist != null) {
      _playlist = playlist;
      _currentIndex = playlist.indexWhere((s) => s.id == song.id);
    }
    await playIndex(_currentIndex);
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null) return;
    if (_isPlaying) {
      await _player.pause();
      _isPlaying = false;
    } else {
      if (_position == Duration.zero || _position >= _duration) {
        await playIndex(_currentIndex);
      } else {
        await _player.resume();
        _isPlaying = true;
      }
    }
    notifyListeners();
  }

  void playNext() {
    if (_playlist.isEmpty) return;
    switch (_playMode) {
      case PlayMode.sequential:
        playIndex((_currentIndex + 1) % _playlist.length);
        break;
      case PlayMode.shuffle:
        final next = DateTime.now().microsecondsSinceEpoch % _playlist.length;
        playIndex(next);
        break;
      case PlayMode.repeatOne:
        playIndex(_currentIndex);
        break;
    }
  }

  void playPrevious() {
    if (_playlist.isEmpty) return;
    if (_position.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }
    final prev = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    playIndex(prev);
  }

  void seek(Duration pos) {
    _player.seek(pos);
  }

  void setPlaylist(List<Song> songs, {int startIndex = 0}) {
    _playlist = songs;
    _currentIndex = startIndex;
    if (songs.isNotEmpty) {
      _currentSong = songs[startIndex];
    }
    notifyListeners();
  }

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
