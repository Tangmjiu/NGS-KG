import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'navidrome_config.dart';
import 'navidrome_service.dart';
import 'navidrome_models.dart';

enum BrowseLevel { artists, albums, songs }

class NavidromeProvider extends ChangeNotifier {
  final NavidromeService _service;
  final NavidromeConfig _config;

  NavidromeProvider({NavidromeService? service, NavidromeConfig? config})
      : _service = service ?? NavidromeService(),
        _config = config ?? NavidromeConfig.instance;

  bool _disposed = false;
  int _sessionVersion = 0;
  int _browseVersion = 0;
  Future<void> _configWrite = Future<void>.value();

  // ── Connection state ──
  bool _connected = false;
  bool get connected => _connected;

  bool _connecting = false;
  bool get connecting => _connecting;

  String? _error;
  String? get error => _error;

  String? get serverUrl => _cachedUrl;
  String? _cachedUrl;

  String? get username => _cachedUsername;
  String? _cachedUsername;

  // ── Browse state ──
  BrowseLevel _currentLevel = BrowseLevel.artists;
  BrowseLevel get currentLevel => _currentLevel;

  String? get selectedArtistId => _selectedArtistId;
  String? _selectedArtistId;

  String? get selectedArtistName => _selectedArtistName;
  String? _selectedArtistName;

  String? get selectedAlbumId => _selectedAlbumId;
  String? _selectedAlbumId;

  String? get selectedAlbumName => _selectedAlbumName;
  String? _selectedAlbumName;

  // ── Data ──
  List<SubsonicArtist> _artists = [];
  List<SubsonicArtist> get artists => _artists;

  List<SubsonicAlbum> _albums = [];
  List<SubsonicAlbum> get albums => _albums;

  List<SubsonicSong> _songs = [];
  List<SubsonicSong> get songs => _songs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<SubsonicSong> _searchResults = [];
  List<SubsonicSong> get searchResults => _searchResults;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  Timer? _searchTimer;
  CancelToken? _searchCancelToken;
  Completer<void>? _searchCompleter;
  int _searchVersion = 0;
  static const _searchDebounce = Duration(milliseconds: 300);

  // 仅缓存当前专辑和当前搜索的映射，不在 build/播放器进度通知中重复签名。
  List<Song>? _playbackSongs;
  List<Song>? _searchPlaybackSongs;
  List<Song> get playbackSongs => _playbackSongs ??= toSongList(_songs);
  List<Song> get searchPlaybackSongs =>
      _searchPlaybackSongs ??= toSongList(_searchResults);

  // ── Connection ──

  /// Try to restore a saved connection on startup.
  Future<bool> tryAutoConnect() async {
    final version = _sessionVersion;
    final url = await _config.getServerUrl();
    final user = await _config.getUsername();
    final pass = await _config.getPassword();
    if (_disposed || version != _sessionVersion) return false;
    if (url != null && url.isNotEmpty && user != null && pass != null) {
      return connect(url, user, pass);
    }
    return false;
  }

  /// Connect to a Navidrome server.
  Future<bool> connect(String url, String username, String password) async {
    if (_disposed || _connecting) return false;
    final version = ++_sessionVersion;
    _resetData();
    _connected = false;
    _cachedUrl = null;
    _cachedUsername = null;
    _connecting = true;
    _error = null;
    notifyListeners();

    try {
      _service.configure(url, username, password);
      final ok = await _service.ping();
      if (!_isCurrentSession(version)) return false;
      if (!ok) {
        _error = '无法连接到服务器，请检查地址和认证信息';
        return false;
      }

      await _queueConfigWrite(() async {
        if (!_isCurrentSession(version)) return;
        await _config.setServerUrl(url);
        await _config.setUsername(username);
        await _config.setPassword(password);
      });
      if (!_isCurrentSession(version)) return false;
      _connected = true;
      _cachedUrl = url;
      _cachedUsername = username;
      await loadArtists();
      return _isCurrentSession(version) && _connected;
    } catch (_) {
      if (_isCurrentSession(version)) {
        _connected = false;
        _error = '无法连接到服务器，请检查地址和认证信息';
      }
      return false;
    } finally {
      if (_isCurrentSession(version)) {
        _connecting = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentSession(int version) =>
      !_disposed && version == _sessionVersion;

  // 将整组凭据保存和清理串行化，防止旧 clear 的后续删键覆盖新账号。
  Future<void> _queueConfigWrite(Future<void> Function() write) {
    final operation = _configWrite.then((_) => write());
    // 保留本次调用的错误传播，但不能让一次写入失败阻塞后续操作。
    _configWrite = operation.then<void>((_) {},
        onError: (Object _, StackTrace __) {});
    return operation;
  }

  /// Disconnect from the server and discard all session-scoped data.
  Future<void> disconnect() async {
    if (_disposed) return;
    ++_sessionVersion;
    _connected = false;
    _connecting = false;
    _cachedUrl = null;
    _cachedUsername = null;
    _error = null;
    _resetData();
    _service.dispose();
    final clear = _queueConfigWrite(_config.clear);
    notifyListeners();
    await clear;
  }

  void _resetData() {
    ++_browseVersion;
    _cancelSearch();
    _artists = [];
    _albums = [];
    _songs = [];
    _searchResults = [];
    _playbackSongs = null;
    _searchPlaybackSongs = null;
    _currentLevel = BrowseLevel.artists;
    _selectedArtistId = null;
    _selectedArtistName = null;
    _selectedAlbumId = null;
    _selectedAlbumName = null;
    _isSearching = false;
    _isLoading = false;
  }

  // ── Browse ──

  bool _isCurrentBrowse(int version) =>
      !_disposed && _connected && version == _browseVersion;

  Future<void> loadArtists() async {
    if (_disposed || !_connected) return;
    final version = ++_browseVersion;
    _isLoading = true;
    _error = null;
    _currentLevel = BrowseLevel.artists;
    notifyListeners();
    try {
      final artists = await _service.getArtists();
      if (_isCurrentBrowse(version)) _artists = artists;
    } catch (_) {
      if (_isCurrentBrowse(version)) _error = '加载歌手列表失败';
    } finally {
      if (_isCurrentBrowse(version)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectArtist(String id, String name) async {
    if (_disposed || !_connected) return;
    final version = ++_browseVersion;
    _selectedArtistId = id;
    _selectedArtistName = name;
    _selectedAlbumId = null;
    _selectedAlbumName = null;
    _songs = [];
    _playbackSongs = null;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final albums = await _service.getArtistAlbums(id);
      if (!_isCurrentBrowse(version)) return;
      _albums = albums;
      _currentLevel = BrowseLevel.albums;
    } catch (_) {
      if (_isCurrentBrowse(version)) _error = '加载专辑列表失败';
    } finally {
      if (_isCurrentBrowse(version)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectAlbum(String id, String name) async {
    if (_disposed || !_connected) return;
    final version = ++_browseVersion;
    _selectedAlbumId = id;
    _selectedAlbumName = name;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final songs = await _service.getAlbumSongs(id);
      if (!_isCurrentBrowse(version)) return;
      _songs = songs;
      _playbackSongs = null;
      _currentLevel = BrowseLevel.songs;
    } catch (_) {
      if (_isCurrentBrowse(version)) _error = '加载歌曲列表失败';
    } finally {
      if (_isCurrentBrowse(version)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void goBack() {
    if (_disposed) return;
    ++_browseVersion;
    _isLoading = false;
    switch (_currentLevel) {
      case BrowseLevel.songs:
        _songs = [];
        _playbackSongs = null;
        _selectedAlbumId = null;
        _selectedAlbumName = null;
        _currentLevel = BrowseLevel.albums;
        break;
      case BrowseLevel.albums:
        _albums = [];
        _selectedArtistId = null;
        _selectedArtistName = null;
        _currentLevel = BrowseLevel.artists;
        break;
      case BrowseLevel.artists:
        break;
    }
    notifyListeners();
  }

  // ── Search ──

  Future<void> search(String query) {
    if (_disposed || !_connected) return Future<void>.value();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return Future<void>.value();
    }
    _cancelSearch();
    final version = _searchVersion;
    final completer = Completer<void>();
    final cancelToken = CancelToken();
    _searchCompleter = completer;
    _searchCancelToken = cancelToken;
    _isSearching = true;
    _error = null;
    _searchResults = [];
    _searchPlaybackSongs = null;
    _searchTimer = Timer(_searchDebounce, () {
      _searchTimer = null;
      _runSearch(trimmed, version, cancelToken, completer);
    });
    notifyListeners();
    return completer.future;
  }

  Future<void> _runSearch(String query, int version, CancelToken cancelToken,
      Completer<void> completer) async {
    try {
      final results = await _service.search(query, cancelToken: cancelToken);
      if (_disposed || version != _searchVersion) return;
      _searchResults = results;
      _searchPlaybackSongs = null;
    } catch (_) {
      if (!_disposed && version == _searchVersion && !cancelToken.isCancelled) {
        _error = '搜索失败';
      }
    } finally {
      if (!_disposed && version == _searchVersion) {
        _isSearching = false;
        _searchCancelToken = null;
        _searchCompleter = null;
        notifyListeners();
      }
      if (!completer.isCompleted) completer.complete();
    }
  }

  void _cancelSearch() {
    ++_searchVersion;
    _searchTimer?.cancel();
    _searchTimer = null;
    _searchCancelToken?.cancel();
    _searchCancelToken = null;
    final completer = _searchCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    _searchCompleter = null;
  }

  void clearSearch() {
    if (_disposed) return;
    _cancelSearch();
    _isSearching = false;
    _searchResults = [];
    _searchPlaybackSongs = null;
    notifyListeners();
  }

  // ── Playback helper ──

  String? getCoverArtUrl(String? coverArtId) =>
      _service.getCoverArtUrl(coverArtId);

  Song navidromeSongToSong(SubsonicSong s) {
    return Song(
      id: s.id.hashCode,
      name: s.title,
      artists: [s.artist ?? '未知歌手'],
      albumName: s.album,
      albumCoverUrl: _service.getCoverArtUrl(s.coverArt),
      filePath: _service.getStreamUrl(s.id),
      duration: s.duration,
    );
  }

  List<Song> toSongList(List<SubsonicSong> songs) =>
      songs.map(navidromeSongToSong).toList();

  @override
  void dispose() {
    _disposed = true;
    ++_sessionVersion;
    ++_browseVersion;
    _cancelSearch();
    _service.dispose();
    super.dispose();
  }
}
