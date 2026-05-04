import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';
import '../services/music_service.dart';
import '../services/notification_service.dart';

enum PlayMode { sequential, shuffle, repeatOne }

class PlayerProvider extends ChangeNotifier {
  final MusicService _musicService = MusicService();
  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;
  PlayMode _playMode = PlayMode.sequential;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isPlayerScreenVisible = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  List<int> _shuffleOrder = [];
  int _shufflePos = 0;
  int _playAttempts = 0;
  int _qualityLevel = 0;
  static const int _maxRetries = 2;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;

  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  PlayMode get playMode => _playMode;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isPlayerScreenVisible => _isPlayerScreenVisible;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get error => _error;
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

  void _setError(String msg) {
    _error = msg;
    debugPrint('[PlayerProvider] $msg');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _updateNotification() {
    final song = _currentSong;
    if (song == null) {
      NotificationService.instance.cancelMediaNotification();
      return;
    }
    NotificationService.instance.showMediaNotification(
      title: song.name,
      artist: song.artistDisplay,
      isPlaying: _isPlaying,
      duration: _duration.inSeconds,
      position: _position.inSeconds,
    );
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

  void _onComplete() {
    switch (_playMode) {
      case PlayMode.repeatOne:
        playIndex(_currentIndex);
        break;
      case PlayMode.shuffle:
        playIndex(_nextShuffleIndex());
        break;
      case PlayMode.sequential:
        if (_currentIndex + 1 < _playlist.length) {
          playIndex(_currentIndex + 1);
        } else {
          _isPlaying = false;
          _setError('播放列表已结束');
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
    _error = null;
    _playAttempts = 0;
    notifyListeners();
    await _doPlay();
  }

  Future<void> _doPlay() async {
    if (_playAttempts > _maxRetries) {
      _isLoading = false;
      _setError('播放失败: 已重试 $_maxRetries 次');
      return;
    }
    try {
      final song = _currentSong!;
      if (song.isLocal && song.filePath != null) {
        if (song.filePath!.startsWith('http')) {
          await _player.play(UrlSource(song.filePath!));
        } else {
          await _player.play(DeviceFileSource(song.filePath!));
        }
      } else {
        final playHash = _qualityHash;
        final songUrl = await _musicService.getSongUrl(song.id,
            hash: playHash ?? song.hash);
        if (songUrl.url.isNotEmpty) {
          await _player.play(UrlSource(songUrl.url));
          _musicService.uploadPlayHistory(song.id, duration: song.duration);
        } else {
          _playAttempts++;
          await _doPlay();
          return;
        }
      }
    } catch (e, s) {
      _playAttempts++;
      debugPrint('[PlayerProvider] play error (attempt $_playAttempts): $e');
      if (_playAttempts <= _maxRetries) {
        await _doPlay();
        return;
      }
      _isLoading = false;
      _setError('播放失败: $e');
      debugPrint('[PlayerProvider] $e\n$s');
      return;
    }
    _isLoading = false;
    _updateNotification();
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    _error = null;
    if (playlist != null) {
      _playlist = playlist;
      _currentIndex = playlist.indexWhere((s) => s.id == song.id);
      if (_playMode == PlayMode.shuffle) _initShuffle();
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
    _updateNotification();
  }

  void playNext() {
    if (_playlist.isEmpty) return;
    switch (_playMode) {
      case PlayMode.shuffle:
        playIndex(_nextShuffleIndex());
        break;
      case PlayMode.sequential:
        playIndex((_currentIndex + 1) % _playlist.length);
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
    if (_playMode == PlayMode.shuffle) {
      _shufflePos = (_shufflePos - 1 + _shuffleOrder.length) % _shuffleOrder.length;
      playIndex(_shuffleOrder[_shufflePos]);
    } else {
      final prev = (_currentIndex - 1 + _playlist.length) % _playlist.length;
      playIndex(prev);
    }
  }

  void seek(Duration pos) {
    _player.seek(pos);
  }

  void setPlaylist(List<Song> songs, {int startIndex = 0}) {
    _playlist = songs;
    _currentIndex = startIndex;
    _shuffleOrder = [];
    if (songs.isNotEmpty) {
      _currentSong = songs[startIndex];
    }
    notifyListeners();
  }

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    if (mode == PlayMode.shuffle) _initShuffle();
    notifyListeners();
  }

  void setPlayerScreenVisible(bool v) {
    _isPlayerScreenVisible = v;
    notifyListeners();
  }

  String? get _qualityHash {
    final q = _currentSong?.qualities;
    if (q == null || q.isEmpty) return null;
    final keys = ['128', '320', 'high'];
    return q[keys[_qualityLevel % keys.length]];
  }

  Future<void> switchQuality() async {
    final q = _currentSong?.qualities;
    if (q == null || q.isEmpty) return;
    _qualityLevel = (_qualityLevel + 1) % ['128', '320', 'high'].length;
    if (_isPlaying) {
      await playIndex(_currentIndex);
    } else {
      notifyListeners();
    }
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
