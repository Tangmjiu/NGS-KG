import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'navidrome_models.dart';

class NavidromeService {
  late final Dio _dio;
  String _baseUrl = '';
  String _username = '';
  String _password = '';

  /// Configure the service with server credentials.
  /// Creates a fresh Dio instance — NOT shared with the app's ApiClient.
  void configure(String baseUrl, String username, String password) {
    _baseUrl = baseUrl;
    _username = username;
    _password = password;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': 'NGS-KG+/1.0'},
    ));
  }

  bool get isConfigured => _baseUrl.isNotEmpty && _username.isNotEmpty;

  /// Generate Subsonic auth parameters using token-based auth.
  /// token = md5(password + salt)
  Map<String, dynamic> _authParams() {
    final salt = _randomSalt();
    final hash = md5.convert(utf8.encode('$_password$salt')).toString();
    return {
      'u': _username,
      't': hash,
      's': salt,
      'v': '1.16.1',
      'c': 'ngskg',
      'f': 'json',
    };
  }

  String _randomSalt() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Tests the connection by calling the ping endpoint.
  Future<bool> ping() async {
    try {
      final response = await _dio.get('/rest/ping.view',
          queryParameters: _authParams());
      final data = response.data;
      if (data is Map) {
        final sub = data['subsonic-response'] as Map?;
        if (sub != null && sub['status'] == 'ok') return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches all artists.
  Future<List<SubsonicArtist>> getArtists() async {
    final response = await _dio.get('/rest/getArtists.view',
        queryParameters: _authParams());
    final sub = _unwrap(response.data);
    final artists = <SubsonicArtist>[];
    final indexes = sub['artists']?['index'] as List? ?? [];
    for (final idx in indexes) {
      final artistList = idx['artist'] as List? ?? [];
      for (final a in artistList) {
        if (a is Map<String, dynamic>) {
          artists.add(SubsonicArtist.fromJson(a));
        }
      }
    }
    return artists;
  }

  /// Fetches all albums for a specific artist.
  Future<List<SubsonicAlbum>> getArtistAlbums(String artistId) async {
    final response = await _dio.get('/rest/getArtist.view',
        queryParameters: {..._authParams(), 'id': artistId});
    final sub = _unwrap(response.data);
    final albumList = sub['artist']?['album'] as List? ?? [];
    return albumList
        .whereType<Map<String, dynamic>>()
        .map((a) => SubsonicAlbum.fromJson(a))
        .toList();
  }

  /// Fetches all songs in a specific album.
  Future<List<SubsonicSong>> getAlbumSongs(String albumId) async {
    final response = await _dio.get('/rest/getAlbum.view',
        queryParameters: {..._authParams(), 'id': albumId});
    final sub = _unwrap(response.data);
    final songList = sub['album']?['song'] as List? ?? [];
    return songList
        .whereType<Map<String, dynamic>>()
        .map((s) => SubsonicSong.fromJson(s))
        .toList();
  }

  /// Searches across artists, albums, and songs.
  Future<List<SubsonicSong>> search(String query) async {
    final response = await _dio.get('/rest/search3.view',
        queryParameters: {..._authParams(), 'query': query});
    final sub = _unwrap(response.data);
    final result = sub['searchResult3'] as Map? ?? {};
    final songList = result['song'] as List? ?? [];
    return songList
        .whereType<Map<String, dynamic>>()
        .map((s) => SubsonicSong.fromJson(s))
        .toList();
  }

  /// Returns the full URL for streaming a song.
  String getStreamUrl(String songId) {
    final params = {..._authParams(), 'id': songId};
    final uri =
        Uri.parse('$_baseUrl/rest/stream.view').replace(queryParameters: params);
    return uri.toString();
  }

  /// Returns the full URL for getting a cover art image.
  String? getCoverArtUrl(String? coverArtId) {
    if (coverArtId == null || coverArtId.isEmpty) return null;
    final params = {..._authParams(), 'id': coverArtId};
    final uri = Uri.parse('$_baseUrl/rest/getCoverArt.view')
        .replace(queryParameters: params);
    return uri.toString();
  }

  /// Unwraps a Subsonic JSON response.
  /// Subsonic wraps everything in {"subsonic-response": {...}}
  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['subsonic-response'] is Map) {
      return data['subsonic-response'] as Map<String, dynamic>;
    }
    if (data is Map<String, dynamic>) return data;
    return {};
  }
}
