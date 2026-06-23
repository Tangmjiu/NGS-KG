import '../services/api_client.dart';
import 'base_repository.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../models/playlist.dart';
import '../models/playlist_tag.dart';
import '../models/artist.dart';

class PlaylistRepository extends BaseRepository {
  PlaylistRepository(super.client);

  String get _userId => ApiClient.userId ?? '0';

  Future<PlaylistDetail> getPlaylistDetail(String gcId) async {
    final res = await get('/playlist/detail', params: {'ids': gcId}, withCookie: true);
    final data = res['data'];
    if (data is List && data.isNotEmpty) {
      return PlaylistDetail.fromKugouJson(Map<String, dynamic>.from(data[0] as Map));
    }
    if (data is Map) {
      final list = data['list'] as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        return PlaylistDetail.fromKugouJson(Map<String, dynamic>.from(list[0] as Map));
      }
      final info = data['info'] as List<dynamic>?;
      if (info != null && info.isNotEmpty) {
        return PlaylistDetail.fromKugouJson(Map<String, dynamic>.from(info[0] as Map));
      }
      return PlaylistDetail.fromKugouJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Playlist not found');
  }

  Future<List<Song>> getPlaylistTracks(String gcId,
      {int page = 1, int pageSize = 30}) async {
    // 尝试 1: 带 pagesize=1000（某些服务器支持，部分返回 502/20010）
    try {
      final params1 = <String, dynamic>{
        'id': gcId, 'page': page, 'pagesize': 1000,
      };
      final res1 = await get('/playlist/track/all',
          params: params1, withCookie: true, silent: true);
      final songs1 = _parseTrackList(res1['data']);
      if (songs1 != null) return songs1;
    } catch (_) {
      // 502/20010 → 静默降级
    }

    // 尝试 2: 用原始 pageSize（兼容旧服务器）
    final params2 = <String, dynamic>{
      'id': gcId, 'page': page, 'pagesize': pageSize,
    };
    final res2 = await get('/playlist/track/all',
        params: params2, withCookie: true);
    final data2 = res2['data'];
    if (data2 is List) {
      return data2
          .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
          .whereType<Song>()
          .toList();
    }
    if (data2 is Map) {
      final songs2 = data2['lists'] as List<dynamic>?
          ?? data2['songs'] as List<dynamic>?
          ?? data2['info'] as List<dynamic>?
          ?? data2['list'] as List<dynamic>?
          ?? data2['audios'] as List<dynamic>?
          ?? data2['songlist'] as List<dynamic>?;
      if (songs2 != null) {
        return songs2
            .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
            .whereType<Song>()
            .toList();
      }
    }
    return [];
  }

  Future<List<Song>> getPlaylistTracksById(int listid,
      {int page = 1, int pageSize = 30}) async {
    // 尝试 1: 带 pagesize=1000（静默）
    try {
      final params1 = <String, dynamic>{
        'id': 'collection_3_${_userId}_${listid}_0',
        'page': page,
        'pagesize': 1000,
      };
      final res1 = await get('/playlist/track/all',
          params: params1, withCookie: true, silent: true);
      final songs1 = _parseTrackList(res1['data']);
      if (songs1 != null) return songs1;
    } catch (_) {
      // 静默降级
    }

    // 尝试 2: 用原始 pageSize
    final res2 = await get('/playlist/track/all', params: {
      'id': 'collection_3_${_userId}_${listid}_0',
      'page': page,
      'pagesize': pageSize,
    }, withCookie: true);
    final data2 = res2['data'];
    if (data2 is Map) {
      final songs2 = data2['lists'] as List<dynamic>?
          ?? data2['songs'] as List<dynamic>?
          ?? data2['info'] as List<dynamic>?
          ?? data2['list'] as List<dynamic>?;
      if (songs2 != null) {
        return songs2
            .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
            .whereType<Song>()
            .toList();
      }
    }
    return [];
  }

  /// 统一解析 /playlist/track/all 返回的歌曲列表
  List<Song>? _parseTrackList(dynamic data) {
    List<dynamic>? songs;
    if (data is Map) {
      songs = data['lists'] as List<dynamic>?
          ?? data['songs'] as List<dynamic>?
          ?? data['info'] as List<dynamic>?
          ?? data['list'] as List<dynamic>?
          ?? data['audios'] as List<dynamic>?
          ?? data['songlist'] as List<dynamic>?;
    } else if (data is List) {
      songs = data;
    }
    if (songs == null) return null;
    return songs
        .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
        .whereType<Song>()
        .toList();
  }

  Future<List<Playlist>> getUserPlaylist(
      {int? userId, int page = 1, int pageSize = 1000}) async {
    // 尝试 1: 带 pagesize（静默）
    try {
      final params1 = <String, dynamic>{'page': page, 'pagesize': pageSize};
      if (userId != null) params1['userid'] = userId;
      final res1 = await get('/user/playlist',
          params: params1, silent: true);
      final list1 = _parsePlaylistList(res1['data']);
      if (list1 != null) return list1;
    } catch (_) {
      // 静默降级
    }

    // 尝试 2: 不带 pagesize
    final params2 = <String, dynamic>{'page': page};
    if (userId != null) params2['userid'] = userId;
    final res2 = await get('/user/playlist', params: params2);
    return _parsePlaylistList(res2['data']) ?? [];
  }

  /// 统一解析 /user/playlist 返回的歌单列表
  List<Playlist>? _parsePlaylistList(dynamic data) {
    List<Playlist> parseList(List<dynamic> items) => items
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .where((p) => p.id != 0 && p.name.isNotEmpty)
        .toList();

    if (data is Map) {
      final info = data['info'] as List<dynamic>?;
      if (info != null) return parseList(info);
      final list = data['list'] as List<dynamic>?;
      if (list != null) return parseList(list);
      final specialList = data['special_list'] as List<dynamic>?;
      if (specialList != null) return parseList(specialList);
    }
    if (data is List) return parseList(data);
    return null;
  }

  Future<List<Playlist>> getTopPlaylists(
      {int limit = 200, int offset = 0, int categoryId = 0}) async {
    final res = await get('/top/playlist', params: {
      'category_id': categoryId,
      'limit': limit,
      'offset': offset,
      'withsong': 1,
    });
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final specialList =
        (raw as Map<String, dynamic>)['special_list'] as List<dynamic>?;
    if (specialList != null) {
      return specialList
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<PlaylistTag>> getPlaylistTags() async {
    final res = await cachedGet('/playlist/tags', ttl: const Duration(hours: 24));
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => PlaylistTag.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Comment>> getPlaylistComments(int playlistId,
      {int page = 1, int pageSize = 200}) async {
    final res = await get('/comment/playlist',
        params: {'id': playlistId, 'page': page, 'pagesize': pageSize});
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final list = (raw as Map<String, dynamic>)['comments'] as List<dynamic>?;
    if (list != null) {
      return list
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Playlist>> getSimilarPlaylists(String ids) async {
    final res = await get('/playlist/similar', params: {'ids': ids});
    final data = res['data'];
    if (data is List) {
      return data
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map) {
      final list = data['playlists'] ?? data['list'];
      if (list is List) {
        return list
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  /// 新版歌单歌曲接口，仅支持用户创建及收藏的歌单（按 listid）。
  /// 某些 API 服务器下比旧版 /playlist/track/all 更稳定。
  Future<List<Song>> getPlaylistTracksNew(int listid,
      {int page = 1, int pageSize = 30}) async {
    try {
      final res = await get('/playlist/track/all/new',
          params: {'listid': listid, 'page': page, 'pagesize': pageSize},
          withCookie: true,
          silent: true);
      final songs = _parseTrackList(res['data']);
      if (songs != null) return songs;
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> createPlaylist(String name,
      {int type = 0, int isPri = 0, int? listCreateListid,
       int? listCreateUserid}) async {
    final params = <String, dynamic>{
      'name': name,
      'list_create_userid': listCreateUserid ?? _userId,
      'type': type,
      'is_pri': isPri,
    };
    if (listCreateListid != null) params['list_create_listid'] = listCreateListid;
    return await get('/playlist/add', params: params);
  }

  Future<void> deletePlaylist(int listid) async {
    await get('/playlist/del', params: {'listid': listid});
  }

  Future<Map<String, dynamic>> addTracksToPlaylist(int listid, String data) async {
    return get('/playlist/tracks/add',
        params: {'listid': listid, 'data': data});
  }

  Future<void> removeTracksFromPlaylist(int listid, String fileids) async {
    await get('/playlist/tracks/del',
        params: {'listid': listid, 'fileids': fileids});
  }

}
