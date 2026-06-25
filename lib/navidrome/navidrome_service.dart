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
  Map<String, String> _authParams() {
    final salt = Random().nextInt(1000000).toString();
    final token = md5.convert(utf8.encode('$_password$salt')).toString();
    return {
      'u': _username,
      't': token,
      's': salt,
      'c': 'ngskg',
      'f': 'json',
      'v': '1.16.1',
    };
  }

  Uri _buildUri(String endpoint, {Map<String, String>? extra}) {
    final params = {..._authParams(), ...?extra};
    final query = params.entries.map((e) =>
        '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    return Uri.parse('$_baseUrl/rest/$endpoint?$query');
  }

  Future<Map<String, dynamic>> _get(String endpoint,
      {Map<String, String>? params}) async {
    final uri = _buildUri(endpoint, extra: params);
    final res = await _dio.getUri(uri);
    final data = res.data as Map<String, dynamic>;
    final subsonic = data['subsonic-response'] as Map<String, dynamic>;
    if (subsonic['status'] == 'failed') {
      throw Exception(subsonic['error']?['message'] ?? 'Subsonic error');
    }
    return subsonic;
  }

  /// Ping the server to check connectivity.
  Future<bool> ping() async {
    try {
      await _get('ping');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get all artists.
  Future<List<SubsonicArtist>> getArtists() async {
    final res = await _get('getArtists');
    final artists = res['artists'] as Map<String, dynamic>?;
    final indexList = artists?['index'] as List<dynamic>? ?? [];
    final result = <SubsonicArtist>[];
    for (final idx in indexList) {
      final artistList = (idx as Map)['artist'] as List<dynamic>? ?? [];
      for (final a in artistList) {
        result.add(SubsonicArtist.fromJson(a as Map<String, dynamic>));
      }
    }
    return result;
  }

  /// Get albums for an artist.
  Future<List<SubsonicAlbum>> getArtistAlbums(String artistId) async {
    final res = await _get('getArtist', params: {'id': artistId});
    final artist = res['artist'] as Map<String, dynamic>?;
    final albumList = artist?['album'] as List<dynamic>? ?? [];
    return albumList
        .map((a) => SubsonicAlbum.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// Get songs in an album.
  Future<List<SubsonicSong>> getAlbumSongs(String albumId) async {
    final res = await _get('getAlbum', params: {'id': albumId});
    final album = res['album'] as Map<String, dynamic>?;
    final songList = album?['song'] as List<dynamic>? ?? [];
    return songList
        .map((s) => SubsonicSong.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Search for songs by title/artist.
  Future<List<SubsonicSong>> search(String query) async {
    final res = await _get('search3', params: {
      'query': query,
      'songCount': '50',
      'artistCount': '0',
      'albumCount': '0',
    });
    final searchResult = res['searchResult3'] as Map<String, dynamic>?;
    final songs = searchResult?['song'] as List<dynamic>? ?? [];
    return songs
        .map((s) => SubsonicSong.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Generate a stream URL for a song.
  String getStreamUrl(String songId) {
    final params = {
      ..._authParams(),
      'id': songId,
    };
    final query = params.entries.map((e) =>
        '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    return '$_baseUrl/rest/stream?$query';
  }

  /// Generate a cover art URL.
  String? getCoverArtUrl(String? coverArtId) {
    if (coverArtId == null || coverArtId.isEmpty) return null;
    return '$_baseUrl/rest/getCoverArt?${Uri.encodeComponent('id')}=${Uri.encodeComponent(coverArtId)}&${_authParams().entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
  }
}
