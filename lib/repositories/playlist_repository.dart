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
    final res = await get('/playlist/detail', params: {'ids': gcId});
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
      {int page = 1, int pageSize = 1000}) async {
    final res = await get('/playlist/track/all',
        params: {'id': gcId, 'page': page, 'pagesize': pageSize});
    final data = res['data'];
    List<dynamic>? songs;
    if (data is Map) {
      songs = data['lists'] as List<dynamic>?
          ?? data['songs'] as List<dynamic>?
          ?? data['info'] as List<dynamic>?
          ?? data['list'] as List<dynamic>?;
    }
    if (songs != null) {
      return songs
          .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
          .whereType<Song>()
          .toList();
    }
    return [];
  }

  Future<List<Song>> getPlaylistTracksById(int listid,
      {int page = 1, int pageSize = 1000}) async {
    final res = await get('/playlist/track/all', params: {
      'id': 'collection_3_${_userId}_${listid}_0',
      'page': page,
      'pagesize': pageSize,
    });
    final data = res['data'];
    if (data is Map) {
      final songs = data['lists'] as List<dynamic>?
          ?? data['songs'] as List<dynamic>?
          ?? data['info'] as List<dynamic>?
          ?? data['list'] as List<dynamic>?;
      if (songs != null) {
        return songs
            .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
            .whereType<Song>()
            .toList();
      }
    }
    return [];
  }

  Future<List<Playlist>> getUserPlaylist(
      {int? userId, int page = 1, int pageSize = 200}) async {
    final params = <String, dynamic>{
      'page': page,
      'pagesize': pageSize,
    };
    if (userId != null) params['userid'] = userId;
    final res = await get('/user/playlist', params: params);
    final data = res['data'];
    if (data is Map) {
      final info = data['info'] as List<dynamic>?;
      if (info != null) {
        return info
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .where((p) => p.id != 0 && p.name.isNotEmpty)
            .toList();
      }
      final list = data['list'] as List<dynamic>?;
      if (list != null) {
        return list
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .where((p) => p.id != 0 && p.name.isNotEmpty)
            .toList();
      }
      final specialList = data['special_list'] as List<dynamic>?;
      if (specialList != null) {
        return specialList
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .where((p) => p.id != 0 && p.name.isNotEmpty)
            .toList();
      }
    }
    if (data is List) {
      return data
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .where((p) => p.id != 0 && p.name.isNotEmpty)
          .toList();
    }
    return [];
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

  Future<void> createPlaylist(String name,
      {int type = 0, int isPri = 0, int? listCreateListid}) async {
    final params = <String, dynamic>{
      'name': name,
      'list_create_userid': _userId,
      'type': type,
      'is_pri': isPri,
    };
    if (listCreateListid != null) params['list_create_listid'] = listCreateListid;
    await get('/playlist/add', params: params);
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
