import 'base_repository.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/rank_entry.dart';
import '../models/scene_category.dart';
import '../models/song_mapper.dart';


class AlbumRepository extends BaseRepository {
  AlbumRepository(super.client);

  /// 追加 cookie 查询参数（KuGouMusicApi 代理要求）
  Future<void> _appendCookie(Map<String, dynamic> params) async {
    try {
      final cookie = await client.getCookieString();
      if (cookie.isNotEmpty) params['cookie'] = cookie;
    } catch (_) {}
  }

  Future<Album?> getAlbumDetail(int albumId) async {
    final params = <String, dynamic>{'id': albumId};
    await _appendCookie(params);
    final res = await get('/album/detail', params: params);
    final data = res['data'];
    if (data is Map) return Album.fromJson(Map<String, dynamic>.from(data));
    if (data is List && data.isNotEmpty) return Album.fromJson(Map<String, dynamic>.from(data[0] as Map));
    return null;
  }

  Future<List<Song>> getAlbumSongs(int albumId,
      {int page = 1, int pageSize = 200}) async {
    final params = <String, dynamic>{
      'id': albumId,
      'page': page,
      'pagesize': pageSize,
    };
    await _appendCookie(params);
    final res = await get('/album/songs', params: params);
    final data = res['data'];
    List<dynamic>? list;
    if (data is Map) {
      list = data['lists'] as List<dynamic>?
          ?? data['songs'] as List<dynamic>?
          ?? data['info'] as List<dynamic>?
          ?? data['list'] as List<dynamic>?
          ?? data['audios'] as List<dynamic>?
          ?? data['songlist'] as List<dynamic>?
          ?? data['items'] as List<dynamic>?
          ?? data['audio_list'] as List<dynamic>?;
    } else if (data is List) {
      list = data;
    }
    if (list == null) return [];
    return list
        .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
        .whereType<Song>()
        .toList();
  }

  Future<List<RankEntry>> getRankList() async {
    final res = await cachedGet('/rank/list', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is Map) {
      final info = raw['info'] as List<dynamic>?;
      if (info != null) {
        return info
            .map((e) => RankEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    if (raw is List) {
      return raw
          .map((e) => RankEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Album>> getTopAlbums({int? type, int page = 1, int pageSize = 30}) async {
    final params = <String, dynamic>{'page': page, 'pagesize': pageSize};
    if (type != null) params['type'] = type;
    await _appendCookie(params);
    final res = await get('/top/album', params: params);
    final body = res;
    final raw = body['data'];
    if (raw is List) {
      return raw
          .map((e) => Album.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // 某些代理返回按地区分组 Map
    if (raw is Map) {
      final albums = <Album>[];
      for (final region in ['chn', 'eur', 'jpn', 'kor']) {
        final list = raw[region];
        if (list is List) {
          albums.addAll(list
              .whereType<Map<String, dynamic>>()
              .map((e) => Album.fromJson(e)));
        }
      }
      return albums;
    }
    return [];
  }

  Future<List<SceneCategory>> getSceneLists() async {
    final res =
        await cachedGet('/scene/lists', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => SceneCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopIp() async {
    final res =
        await cachedGet('/top/ip', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Song>> getRankAudios(int rankId,
      {int page = 1, int pageSize = 200, int? rankCid}) async {
    final params = <String, dynamic>{
      'rankid': rankId,
      'page': page,
      'pagesize': pageSize,
    };
    if (rankCid != null) params['rank_cid'] = rankCid;
    final res = await get('/rank/audio', params: params);
    final raw = res['data'];
    if (raw is Map) {
      final songlist = raw['songlist'] as List<dynamic>?;
      if (songlist != null) {
        return songlist
            .map((e) => SongMapper.fromRankJson(e as Map<String, dynamic>))
            .whereType<Song>()
            .toList();
      }
      final songs = raw['songs'] as List<dynamic>?;
      if (songs != null) {
        return songs.map((e) {
          final json = e as Map<String, dynamic>;
          return Song(
            id: json['audio_id'] as int? ?? json['songid'] as int? ?? 0,
            name: json['songname'] as String? ?? json['audio_name'] as String? ?? '',
            artists: [(json['author_name'] as String? ?? '')],
            albumName: json['album_name'] as String?,
            albumId: (json['album_id'] as int?) ?? 0,
            duration: ((json['timelength'] as int?) ?? 0) ~/ 1000,
            hash: json['hash'] as String?,
          );
        }).toList();
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getIpZone() async {
    final res = await cachedGet('/ip/zone', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getIpZoneHome(int id) async {
    final res = await get('/ip/zone/home', params: {'id': id});
    return res;
  }

}
