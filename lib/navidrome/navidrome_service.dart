import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'navidrome_models.dart';

class NavidromeService {
  Dio? _dio;
  String _baseUrl = '';
  String _username = '';
  String _password = '';
  String _coverAuthQuery = '';

  /// Configure the service with server credentials.
  /// Creates a fresh Dio instance — NOT shared with the app's ApiClient.
  void configure(String baseUrl, String username, String password) {
    _dio?.close(force: true);
    _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    _username = username;
    _password = password;
    // 封面 URL 同一会话内保持稳定，让图片缓存命中；重连时重新签名，
    // 不以纯 coverArtId 作为缓存键，避免跨服务器/账号复用认证或封面。
    _coverAuthQuery = _encodeQuery(_authParams());
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': 'NGS-KG+/1.0'},
    ));
  }

  bool get isConfigured => _baseUrl.isNotEmpty && _username.isNotEmpty;

  /// Generate Subsonic auth parameters using token-based auth.
  /// token = md5(password + salt)
  Map<String, String> _authParams() {
    final random = Random.secure();
    final salt = List.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
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

  static String _encodeQuery(Map<String, String> params) => params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');

  Uri _buildUri(String endpoint, {Map<String, String>? extra}) {
    final params = {..._authParams(), ...?extra};
    return Uri.parse('$_baseUrl/rest/$endpoint?${_encodeQuery(params)}');
  }

  Future<Map<String, dynamic>> _get(String endpoint,
      {Map<String, String>? params, CancelToken? cancelToken}) async {
    final dio = _dio;
    if (dio == null || !isConfigured) {
      throw StateError('Navidrome 尚未连接');
    }
    final uri = _buildUri(endpoint, extra: params);
    final res = await dio.getUri(uri, cancelToken: cancelToken);
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
  Future<List<SubsonicSong>> search(String query,
      {CancelToken? cancelToken}) async {
    final res = await _get('search3', params: {
      'query': query,
      'songCount': '50',
      'artistCount': '0',
      'albumCount': '0',
    }, cancelToken: cancelToken);
    final searchResult = res['searchResult3'] as Map<String, dynamic>?;
    final songs = searchResult?['song'] as List<dynamic>? ?? [];
    return songs
        .map((s) => SubsonicSong.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Generate a stream URL for a song.
  String getStreamUrl(String songId) =>
      _buildUri('stream', extra: {'id': songId}).toString();

  /// Generate a cover art URL, stable until the next configure call.
  String? getCoverArtUrl(String? coverArtId) {
    if (!isConfigured || coverArtId == null || coverArtId.isEmpty) return null;
    return '$_baseUrl/rest/getCoverArt?id=${Uri.encodeComponent(coverArtId)}&$_coverAuthQuery';
  }

  void dispose() {
    _dio?.close(force: true);
    _dio = null;
    _baseUrl = '';
    _username = '';
    _password = '';
    _coverAuthQuery = '';
  }
}
