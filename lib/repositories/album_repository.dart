import 'base_repository.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/rank_entry.dart';
import '../models/scene_category.dart';
import '../models/song_mapper.dart';


class AlbumRepository extends BaseRepository {
  AlbumRepository(super.client);

  Future<Album?> getAlbumDetail(int albumId) async {
    final res = await get('/album/detail', params: {'id': albumId}, withAuth: false);
    final data = res['data'];
    if (data is Map) return Album.fromJson(Map<String, dynamic>.from(data));
    if (data is List && data.isNotEmpty) return Album.fromJson(Map<String, dynamic>.from(data[0] as Map));
    return null;
  }

  Future<List<Song>> getAlbumSongs(int albumId) async {
    // 尝试 1: 带 pagesize=1000（某些服务器支持分页，但部分返回 502/20010）
    // silent=true 使 502 不弹错误窗，静默降级到无 pagesize 重试
    try {
      final params1 = <String, dynamic>{'id': albumId, 'pagesize': 1000};
      final res1 = await get('/album/songs',
          params: params1, withCookie: true, silent: true);
      final songs1 = _parseSongList(res1['data']);
      if (songs1 != null) return songs1;
    } catch (_) {
      // 502/20010 → 静默降级
    }

    // 尝试 2: 不带 pagesize（兼容旧服务器）
    final res2 = await get('/album/songs',
        params: {'id': albumId}, withCookie: true);
    return _parseSongList(res2['data']) ?? [];
  }

  /// 从接口响应的 data 中提取歌曲列表，失败返回 null
  List<Song>? _parseSongList(dynamic data) {
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
    if (list == null) return null;
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
    // 该服务器不支持 page/pagesize 参数（返回 20010），仅传 type
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    final res = await get('/top/album', params: params, withAuth: false);
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
