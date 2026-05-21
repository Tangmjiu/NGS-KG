import 'base_repository.dart';
import '../models/song.dart';
import '../models/artist.dart';

class ArtistRepository extends BaseRepository {
  ArtistRepository(super.client);

  Future<List<Artist>> getArtistList({int limit = 100, int offset = 0}) async {
    final res =
        await get('/artist/lists', params: {'limit': limit, 'offset': offset});
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Artist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getArtistDetail(int artistId) async {
    return get('/artist/detail', params: {'id': artistId});
  }

  Future<List<Song>> getArtistAudios(int artistId,
      {int page = 1, int pageSize = 200, String sort = 'hot'}) async {
    final res = await get('/artist/audios', params: {
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
    await get('/artist/follow', params: {'id': artistId});
  }

  Future<void> unfollowArtist(int artistId) async {
    await get('/artist/unfollow', params: {'id': artistId});
  }
}
