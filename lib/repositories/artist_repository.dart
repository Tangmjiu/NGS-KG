import '../services/api_client.dart';
import '../models/song.dart';
import '../models/artist.dart';

class ArtistRepository {
  final ApiClient _client;

  ArtistRepository(this._client);

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, dynamic>? params, bool withAuth = true}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (withAuth) {
      p['cookie'] = await _client.getCookieString();
    }
    final res = await _client.get(path, params: p);
    return res.data as Map<String, dynamic>;
  }

  Future<List<Artist>> getArtistList({int limit = 100, int offset = 0}) async {
    final res =
        await _get('/artist/lists', params: {'limit': limit, 'offset': offset});
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Artist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getArtistDetail(int artistId) async {
    return _get('/artist/detail', params: {'id': artistId});
  }

  Future<List<Song>> getArtistAudios(int artistId,
      {int page = 1, int pageSize = 200, String sort = 'hot'}) async {
    final res = await _get('/artist/audios', params: {
      'id': artistId,
      'page': page,
      'pagesize': pageSize,
      'sort': sort,
    });
    final raw = res['data'];
    if (raw is List) {
      return raw.map((e) {
        final json = e as Map<String, dynamic>;
        return Song(
          id: json['audio_id'] as int? ?? 0,
          name: json['audio_name'] as String? ?? '',
          artists: [(json['author_name'] as String? ?? '')],
          albumName: json['album_name'] as String?,
          albumId: (json['album_id'] as int?) ?? 0,
          duration: ((json['timelength'] as int?) ?? 0) ~/ 1000,
          hash: json['hash'] as String?,
        );
      }).toList();
    }
    return [];
  }

  Future<void> followArtist(int artistId) async {
    await _get('/artist/follow', params: {'id': artistId});
  }

  Future<void> unfollowArtist(int artistId) async {
    await _get('/artist/unfollow', params: {'id': artistId});
  }
}
