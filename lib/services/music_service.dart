import 'api_client.dart';
import '../models/song.dart';
import '../models/playlist.dart';

class MusicService {
  final ApiClient _client = ApiClient.instance;

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, dynamic>? params, bool withAuth = true}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (withAuth) {
      p['cookie'] = await _client.getCookieString();
    }
    final res = await _client.get(path, params: p);
    return res.data as Map<String, dynamic>;
  }

  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0}) async {
    final res = await _get('/search', params: {
      'keyword': keyword,
      'limit': limit,
      'offset': offset,
    });
    final data = res['data'];
    final list =
        data['songs'] as List<dynamic>? ?? data['lists'] as List<dynamic>? ?? [];
    return list
        .map((e) => Song.fromKugouJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getSearchSuggest(String keyword) async {
    final res = await _get('/search/suggest', params: {'keywords': keyword});
    final list = res['data'] as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }

  Future<List<Map<String, dynamic>>> getHotSearch() async {
    final res = await _get('/search/hot');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<SongUrl> getSongUrl(int songId, {String? hash}) async {
    final params = <String, dynamic>{};
    if (hash != null) {
      params['hash'] = hash;
    } else {
      params['id'] = songId;
    }
    final res = await _get('/song/url', params: params);
    return SongUrl.fromJson(res);
  }

  Future<Map<String, dynamic>> getLyric(int songId) async {
    return _get('/lyric', params: {'id': songId});
  }

  Future<Map<String, dynamic>> searchLyricByHash(String hash) async {
    return _get('/search/lyric', params: {'hash': hash});
  }

  Future<String> fetchLyricContent(int lyricId, String accessKey) async {
    final res = await _get('/lyric', params: {
      'id': lyricId,
      'accesskey': accessKey,
      'fmt': 'lrc',
      'decode': 'true',
    });
    return res['content'] as String? ?? '';
  }

  Future<PlaylistDetail> getPlaylistDetail(int playlistId) async {
    final res =
        await _get('/playlist/detail', params: {'id': playlistId});
    return PlaylistDetail.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<PlaylistDetail> getPlaylistDetailByGcId(String gcId) async {
    final res = await _get('/playlist/detail', params: {'ids': gcId});
    final list = res['data'];
    if (list is List && list.isNotEmpty) {
      return PlaylistDetail.fromKugouJson(list[0] as Map<String, dynamic>);
    }
    throw Exception('Playlist not found');
  }

  Future<List<Song>> getPlaylistTracks(String gcId,
      {int page = 1, int pageSize = 30}) async {
    final res = await _get('/playlist/track/all',
        params: {'id': gcId, 'page': page, 'pagesize': pageSize});
    final songs =
        ((res['data'] as Map<String, dynamic>)['songs'] as List<dynamic>);
    return songs
        .map((e) => Song.fromTrackJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Playlist>> getUserPlaylist({int? userId}) async {
    final params = <String, dynamic>{};
    if (userId != null) params['userId'] = userId;
    final res = await _get('/user/playlist', params: params);
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Playlist>> getTopPlaylists(
      {int limit = 30, int offset = 0, int categoryId = 0}) async {
    final res = await _get('/top/playlist', params: {
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

  Future<Map<String, dynamic>> getAlbumDetail(int albumId) async {
    final res = await _get('/album/detail', params: {'id': albumId});
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getRankList() async {
    final res = await _get('/rank/list');
    final raw = res['data'];
    if (raw is Map) {
      final info = raw['info'] as List<dynamic>?;
      if (info != null) return info.cast<Map<String, dynamic>>();
    }
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Song>> getRankAudios(int rankId) async {
    final res =
        await _get('/rank/audio', params: {'rankid': rankId});
    final raw = res['data'];
    if (raw is Map) {
      final songlist = raw['songlist'] as List<dynamic>?;
      if (songlist != null) {
        return songlist
            .map((e) => Song.fromRankJson(e as Map<String, dynamic>))
            .toList();
      }
      final songs = raw['songs'] as List<dynamic>?;
      if (songs != null) {
        return songs
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<List<Song>> getTopSongs() async {
    final res = await _get('/top/song');
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getArtistList(
      {int limit = 30, int offset = 0}) async {
    final res =
        await _get('/artist/list', params: {'limit': limit, 'offset': offset});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getArtistDetail(int artistId) async {
    return _get('/artist/detail', params: {'id': artistId});
  }

  Future<List<Song>> getArtistAudios(int artistId) async {
    final res = await _get('/artist/audios', params: {'id': artistId});
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMusicComments(int songId,
      {int limit = 20, int offset = 0}) async {
    final res = await _get('/comment/music',
        params: {'id': songId, 'limit': limit, 'offset': offset});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    final list = (raw as Map<String, dynamic>)['comments'] as List<dynamic>?;
    if (list != null) return list.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getSheetList({int limit = 30}) async {
    final res = await _get('/sheet/list', params: {'limit': limit});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getFmRecommend() async {
    final res = await _get('/fm/recommend');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Song>> getFmSongs(int fmId) async {
    final res = await _get('/fm/songs', params: {'fmid': fmId});
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Song.fromTrackJson(e as Map<String, dynamic>))
          .toList();
    }
    if (raw is Map) {
      final songs = raw['songs'] as List<dynamic>?;
      if (songs != null) {
        return songs
            .map((e) => Song.fromTrackJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getUserHistory() async {
    final res = await _get('/user/history');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getPlaylistComments(int playlistId,
      {int limit = 20, int offset = 0}) async {
    final res = await _get('/comment/playlist',
        params: {'id': playlistId, 'limit': limit, 'offset': offset});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    final list = (raw as Map<String, dynamic>)['comments'] as List<dynamic>?;
    if (list != null) return list.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getSheetDetail(int sheetId) async {
    return _get('/sheet/detail', params: {'id': sheetId});
  }

  Future<List<Map<String, dynamic>>> getHotSheets() async {
    final res = await _get('/sheet/hot');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }
}
