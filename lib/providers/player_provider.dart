import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import '../services/music_service.dart';
import '../services/notification_service.dart';
import 'mixins.dart';

enum PlayMode { sequential, shuffle, repeatOne }

class PlayerProvider extends ChangeNotifier with SleepTimerMixin, KeepScreenOnMixin {
  final MusicService _musicService;
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
  int _playRequestVersion = 0;
  DateTime? _lastUrlFetchTime;
  static const int _maxRetries = 2;
  static const _urlStaleDuration = Duration(minutes: 10);

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _processingStateSub;

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

  bool _isCompleting = false;

  PlayerProvider(this._musicService) {
    _initSession();
    _initPlayer();
    _positionSub = _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
      if (sleepTimerRemaining != null && sleepTimerRemaining!.inSeconds <= 0) {
        _player.pause();
        _isPlaying = false;
        cancelSleepTimer();
        notifyListeners();
      }
    });
    _durationSub = _player.durationStream.listen((d) {
      if (d != null) {
        _duration = d;
        notifyListeners();
      }
    });
    _processingStateSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (!_isCompleting) {
          _isCompleting = true;
          _onComplete();
        }
      }
    });
  }

  void _initSession() {
    AudioSession.instance.then((session) => session.configure(const AudioSessionConfiguration(
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    )));
  }

  void _initPlayer() {
    _player.playbackEventStream.listen((event) {
      _isPlaying = _player.playing;
      notifyListeners();
    });
  }

  Future<void> _refreshUrlAndPlay() async {
    final song = _currentSong;
    if (song == null || song.isLocal) return;
    try {
      final quality = _currentQuality;
      final pos = _position;
      final songUrl = await _musicService.getSongUrl(song.id,
          hash: song.hash, quality: quality);
      if (songUrl.url.isEmpty) return;
      _lastUrlFetchTime = DateTime.now();
      await _player.setUrl(songUrl.url);
      await _player.seek(pos);
      await _player.play();
      _isPlaying = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[PlayerProvider] refresh URL error: $e');
      _setError('刷新播放地址失败');
    }
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
          _updateNotification();
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
    _playRequestVersion++;
    _isCompleting = false;
    final version = _playRequestVersion;
    notifyListeners();
    await _doPlay(version);
  }

  Future<void> _doPlay([int? version]) async {
    version ??= _playRequestVersion;
    if (version != _playRequestVersion) return;
    if (_playAttempts > _maxRetries) {
      _isLoading = false;
      _setError('播放失败: 已重试 $_maxRetries 次');
      return;
    }
    try {
      final song = _currentSong!;
      if (song.isLocal && song.filePath != null) {
        if (song.filePath!.startsWith('http')) {
          await _player.setUrl(song.filePath!);
          if (version != _playRequestVersion) return;
          await _player.play();
        } else {
          await _player.setFilePath(song.filePath!);
          if (version != _playRequestVersion) return;
          await _player.play();
        }
      } else {
        final quality = _currentQuality;
        final songUrl = await _musicService.getSongUrl(song.id,
            hash: song.hash, quality: quality);
        if (version != _playRequestVersion) return;
        if (songUrl.url.isNotEmpty) {
          await _player.setUrl(songUrl.url);
          if (version != _playRequestVersion) return;
          _lastUrlFetchTime = DateTime.now();
          await _player.play();
          _musicService.uploadPlayHistory(song.id, duration: song.duration).catchError((_) {});
        } else {
          _playAttempts++;
          await _doPlay(version);
          return;
        }
      }
    } catch (e, s) {
      _playAttempts++;
      debugPrint('[PlayerProvider] play error (attempt $_playAttempts): $e');
      if (_playAttempts <= _maxRetries) {
        await _doPlay(version);
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
      if (_currentIndex < 0) {
        _playlist = [song];
        _currentIndex = 0;
      }
      if (_playMode == PlayMode.shuffle) _initShuffle();
    } else {
      _playlist = [song];
      _currentIndex = 0;
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
        final isStale = _lastUrlFetchTime != null &&
            DateTime.now().difference(_lastUrlFetchTime!) > _urlStaleDuration;
        if (isStale && !_currentSong!.isLocal) {
          await _refreshUrlAndPlay();
        } else {
          await _player.play();
          _isPlaying = true;
        }
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

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
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

  String? get _currentQuality {
    final q = _currentSong?.qualities;
    if (q == null || q.isEmpty) return null;
    final keys = ['128', '320', 'high'];
    final key = keys[_qualityLevel % keys.length];
    return q.containsKey(key) ? key : null;
  }

  bool isCurrentQuality(String key) {
    final q = _currentSong?.qualities;
    if (q == null || q.isEmpty) return false;
    final keys = ['128', '320', 'high'];
    final currentKey = keys[_qualityLevel % keys.length];
    return currentKey == key;
  }

  Future<void> setQualityIndex(int index) async {
    final q = _currentSong?.qualities;
    if (q == null || q.isEmpty) return;
    _qualityLevel = index % ['128', '320', 'high'].length;
    if (_isPlaying) {
      await playIndex(_currentIndex);
    } else {
      notifyListeners();
    }
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
  void onSleepTimerExpired() {
    _player.pause();
    _isPlaying = false;
  }

  void setVolume(double volume) {
    _player.setVolume(volume);
  }

  void setSpeed(double speed) {
    _player.setSpeed(speed);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _processingStateSub?.cancel();
    disposeSleepTimer();
    _player.dispose();
    disposeKeepScreenOn();
    super.dispose();
  }
}