import 'base_repository.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../models/album.dart';

class ArtistRepository extends BaseRepository {
  ArtistRepository(super.client);

  Future<List<Artist>> getArtistList({int limit = 100, int offset = 0}) async {
    final res =
        await get('/artist/lists', params: {'limit': limit, 'offset': offset});
    final raw = res['data'];
    // API 实际返回结构: data.info[].singer[].{singerid, singername, imgurl}
    if (raw is Map) {
      final info = raw['info'] as List<dynamic>?;
      if (info != null) {
        final artists = <Artist>[];
        for (final entry in info) {
          if (entry is Map) {
            final singerList = entry['singer'] as List<dynamic>?;
            if (singerList != null) {
              for (final s in singerList) {
                if (s is Map<String, dynamic>) {
                  artists.add(Artist.fromJson(s));
                }
              }
            }
          }
        }
        return artists;
      }
    }
    // 兼容其他代理可能直接返回列表的情况
    if (raw is List) {
      return raw
          .map((e) => Artist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 获取歌手详情（头像、简介、统计等）
  /// API: GET /artist/detail?id=xxx
  Future<Map<String, dynamic>> getArtistDetail(int artistId) async {
    return get('/artist/detail', params: {'id': artistId});
  }

  /// 获取歌手单曲
  /// API: GET /artist/audios?id=xxx&sort=hot&page=1&pagesize=50
  Future<List<Song>> getArtistAudios(int artistId,
      {int page = 1, int pageSize = 50, String? sort}) async {
    final params = <String, dynamic>{
      'id': artistId,
      'page': page,
      'pagesize': pageSize,
    };
    if (sort != null && sort.isNotEmpty) params['sort'] = sort;
    final res = await get('/artist/audios', params: params);
    final raw = res['data'];
    if (raw is List) {
      return raw.map((e) {
        final json = e as Map<String, dynamic>;
        // 多字段回退查封面
        var cover = json['cover'] as String? ??
            json['album_cover'] as String? ??
            json['sizable_cover'] as String? ??
            json['imgurl'] as String?;
        // /artist/audios 的封面藏在 trans_param.union_cover
        if (cover == null || cover.isEmpty) {
          final tp = json['trans_param'];
          if (tp is Map) {
            cover = tp['union_cover'] as String?;
          }
        }
        if (cover != null) {
          cover = cover.replaceAll('{size}', '480');
          if (cover.startsWith('//')) cover = 'https:$cover';
        }
        return Song(
          id: json['audio_id'] as int? ?? 0,
          name: json['audio_name'] as String? ?? '',
          artists: [(json['author_name'] as String? ?? '')],
          albumName: json['album_name'] as String?,
          albumCoverUrl: cover,
          albumId: (json['album_id'] as int?) ?? 0,
          artistId: (json['author_id'] as int?),
          duration: ((json['timelength'] as int?) ?? 0) ~/ 1000,
          hash: json['hash'] as String?,
        );
      }).toList();
    }
    return [];
  }

  /// 获取歌手专辑列表
  /// API: GET /artist/albums?id=xxx&sort=hot&page=1&pagesize=50
  Future<List<Album>> getArtistAlbums(int artistId,
      {int page = 1, int pageSize = 50, String sort = 'hot'}) async {
    final res = await get('/artist/albums', params: {
      'id': artistId,
      'page': page,
      'pagesize': pageSize,
      'sort': sort,
    });
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Album.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // MV:
  // MV: /// 获取歌手 MV 列表
  // MV: /// API: GET /artist/videos?id=xxx&page=1&pagesize=20
  // MV: Future<List<Map<String, dynamic>>> getArtistVideos(int artistId,
  // MV:     {int page = 1, int pageSize = 20}) async {
  // MV:   final res = await get('/artist/videos', params: {
  // MV:     'id': artistId,
  // MV:     'page': page,
  // MV:     'pagesize': pageSize,
  // MV:   });
  // MV:   final raw = res['data'];
  // MV:   if (raw is List) return raw.cast<Map<String, dynamic>>();
  // MV:   return [];
  // MV: }

  Future<void> followArtist(int artistId) async {
    await get('/artist/follow', params: {'id': artistId});
  }

  Future<void> unfollowArtist(int artistId) async {
    await get('/artist/unfollow', params: {'id': artistId});
  }
}
