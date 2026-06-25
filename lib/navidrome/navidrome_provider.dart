import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'navidrome_config.dart';
import 'navidrome_service.dart';
import 'navidrome_models.dart';

enum BrowseLevel { artists, albums, songs }

class NavidromeProvider extends ChangeNotifier {
  final NavidromeService _service = NavidromeService();
  final NavidromeConfig _config = NavidromeConfig.instance;

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

  // ── Connection ──

  /// Try to restore a saved connection on startup.
  Future<bool> tryAutoConnect() async {
    final url = await _config.getServerUrl();
    final user = await _config.getUsername();
    final pass = await _config.getPassword();
    if (url != null && url.isNotEmpty && user != null && pass != null) {
      return connect(url, user, pass);
    }
    return false;
  }

  /// Connect to a Navidrome server.
  Future<bool> connect(String url, String username, String password) async {
    _connecting = true;
    _error = null;
    notifyListeners();

    _service.configure(url, username, password);
    final ok = await _service.ping();

    if (ok) {
      _connected = true;
      _cachedUrl = url;
      _cachedUsername = username;
      await _config.setServerUrl(url);
      await _config.setUsername(username);
      await _config.setPassword(password);
      await loadArtists();
    } else {
      _error = '无法连接到服务器，请检查地址和认证信息';
    }

    _connecting = false;
    notifyListeners();
    return ok;
  }

  /// Disconnect from the server.
  Future<void> disconnect() async {
    _connected = false;
    _artists = [];
    _albums = [];
    _songs = [];
    _searchResults = [];
    _currentLevel = BrowseLevel.artists;
    _selectedArtistId = null;
    _selectedArtistName = null;
    _selectedAlbumId = null;
    _selectedAlbumName = null;
    _isSearching = false;
    await _config.clear();
    notifyListeners();
  }

  // ── Browse ──

  Future<void> loadArtists() async {
    if (!_connected) return;
    _isLoading = true;
    _currentLevel = BrowseLevel.artists;
    notifyListeners();
    try {
      _artists = await _service.getArtists();
    } catch (e) {
      _error = '加载歌手列表失败';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectArtist(String id, String name) async {
    _selectedArtistId = id;
    _selectedArtistName = name;
    _isLoading = true;
    notifyListeners();
    try {
      _albums = await _service.getArtistAlbums(id);
      _currentLevel = BrowseLevel.albums;
    } catch (e) {
      _error = '加载专辑列表失败';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectAlbum(String id, String name) async {
    _selectedAlbumId = id;
    _selectedAlbumName = name;
    _isLoading = true;
    notifyListeners();
    try {
      _songs = await _service.getAlbumSongs(id);
      _currentLevel = BrowseLevel.songs;
    } catch (e) {
      _error = '加载歌曲列表失败';
    }
    _isLoading = false;
    notifyListeners();
  }

  void goBack() {
    switch (_currentLevel) {
      case BrowseLevel.songs:
        _songs = [];
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

  Future<void> search(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _service.search(query);
    } catch (e) {
      _error = '搜索失败';
    }
    notifyListeners();
  }

  void clearSearch() {
    _isSearching = false;
    _searchResults = [];
    notifyListeners();
  }

  // ── Playback helper ──

  /// Returns the full cover art URL for a given cover art ID, or null.
  String? getCoverArtUrl(String? coverArtId) =>
      _service.getCoverArtUrl(coverArtId);

  /// Convert a SubsonicSong to the app's Song model for playback.
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

  /// Convert a list of SubsonicSongs for playback queue.
  List<Song> toSongList(List<SubsonicSong> songs) {
    return songs.map(navidromeSongToSong).toList();
  }
}
