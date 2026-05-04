import 'api_client.dart';
import '../models/song.dart';
import '../models/playlist.dart';

class MusicService {
  final ApiClient _client = ApiClient.instance;

  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0}) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/search', params: {
      'keyword': keyword,
      'limit': limit,
      'offset': offset,
      'cookie': cookie,
    });
    final data = res.data['data'];
    final list = data['songs'] as List<dynamic>? ?? data['lists'] as List<dynamic>? ?? [];
    return list.map((e) => Song.fromKugouJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<String>> getSearchSuggest(String keyword) async {
    final res =
        await _client.get('/search/suggest', params: {'keywords': keyword});
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }

  Future<List<Map<String, dynamic>>> getHotSearch() async {
    final res = await _client.get('/search/hot');
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<SongUrl> getSongUrl(int songId, {String? hash}) async {
    final cookie = await _client.getCookieString();
    final params = <String, dynamic>{'cookie': cookie};
    if (hash != null) {
      params['hash'] = hash;
    } else {
      params['id'] = songId;
    }
    final res = await _client.get('/song/url', params: params);
    return SongUrl.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getLyric(int songId) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/lyric', params: {'id': songId, 'cookie': cookie});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> searchLyricByHash(String hash) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/search/lyric',
        params: {'hash': hash, 'cookie': cookie});
    return res.data as Map<String, dynamic>;
  }

  Future<String> fetchLyricContent(int lyricId, String accessKey) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/lyric',
        params: {
          'id': lyricId,
          'accesskey': accessKey,
          'fmt': 'lrc',
          'decode': 'true',
          'cookie': cookie,
        });
    return res.data['content'] as String? ?? '';
  }

  Future<PlaylistDetail> getPlaylistDetail(int playlistId) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/playlist/detail',
        params: {'id': playlistId, 'cookie': cookie});
    return PlaylistDetail.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<PlaylistDetail> getPlaylistDetailByGcId(String gcId) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/playlist/detail',
        params: {'ids': gcId, 'cookie': cookie});
    final list = res.data['data'];
    if (list is List && list.isNotEmpty) {
      return PlaylistDetail.fromKugouJson(list[0] as Map<String, dynamic>);
    }
    throw Exception('Playlist not found');
  }

  Future<List<Song>> getPlaylistTracks(String gcId,
      {int page = 1, int pageSize = 30}) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/playlist/track/all',
        params: {'id': gcId, 'page': page, 'pagesize': pageSize, 'cookie': cookie});
    final raw = res.data['data'];
    final songs = (raw as Map<String, dynamic>)['songs'] as List<dynamic>;
    return songs.map((e) => Song.fromTrackJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Playlist>> getUserPlaylist({int? userId}) async {
    final params = <String, dynamic>{};
    if (userId != null) params['userId'] = userId;
    final res = await _client.get('/user/playlist', params: params);
    final raw = res.data['data'];
    if (raw is List) {
      return raw
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Playlist>> getTopPlaylists(
      {int limit = 30, int offset = 0, int categoryId = 0}) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/top/playlist',
        params: {
          'category_id': categoryId,
          'limit': limit,
          'offset': offset,
          'withsong': 1,
          'cookie': cookie,
        });
    final raw = res.data['data'];
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
    final res = await _client.get('/album/detail', params: {'id': albumId});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getRankList() async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/rank/list',
        params: {'cookie': cookie});
    final raw = res.data['data'];
    if (raw is Map) {
      final info = raw['info'] as List<dynamic>?;
      if (info != null) return info.cast<Map<String, dynamic>>();
    }
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Song>> getRankAudios(int rankId) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/rank/audio',
        params: {'rankid': rankId, 'cookie': cookie});
    final raw = res.data['data'];
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
    final res = await _client.get('/top/song');
    final raw = res.data['data'];
    if (raw is List) {
      return raw
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getArtistList(
      {int limit = 30, int offset = 0}) async {
    final res = await _client.get('/artist/list',
        params: {'limit': limit, 'offset': offset});
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getArtistDetail(int artistId) async {
    final res = await _client.get('/artist/detail', params: {'id': artistId});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getArtistAlbums(int artistId) async {
    final res =
        await _client.get('/artist/albums', params: {'id': artistId});
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Song>> getArtistAudios(int artistId) async {
    final res =
        await _client.get('/artist/audios', params: {'id': artistId});
    final raw = res.data['data'];
    if (raw is List) {
      return raw
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMusicComments(int songId,
      {int limit = 20, int offset = 0}) async {
    final res = await _client.get('/comment/music',
        params: {'id': songId, 'limit': limit, 'offset': offset});
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    final list = (raw as Map<String, dynamic>)['comments'] as List<dynamic>?;
    if (list != null) return list.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getPlaylistComments(int playlistId,
      {int limit = 20, int offset = 0}) async {
    final res = await _client.get('/comment/playlist',
        params: {'id': playlistId, 'limit': limit, 'offset': offset});
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    final list = (raw as Map<String, dynamic>)['comments'] as List<dynamic>?;
    if (list != null) return list.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getSheetList({int limit = 30}) async {
    final res =
        await _client.get('/sheet/list', params: {'limit': limit});
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getSheetDetail(int sheetId) async {
    final res = await _client.get('/sheet/detail', params: {'id': sheetId});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getHotSheets() async {
    final res = await _client.get('/sheet/hot');
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getFmRecommend() async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/fm/recommend',
        params: {'cookie': cookie});
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Song>> getFmSongs(int fmId) async {
    final cookie = await _client.getCookieString();
    final res = await _client.get('/fm/songs',
        params: {'fmid': fmId, 'cookie': cookie});
    final raw = res.data['data'];
    // Songs might be in rcmdlist directly or in data.songs
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

  Future<List<Map<String, dynamic>>> getPlaylistTags() async {
    final res = await _client.get('/playlist/tags');
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getPersonalFm() async {
    final res = await _client.get('/personal/fm');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDailyRecommend() async {
    final res = await _client.get('/everyday/recommend');
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getYuekuBanner() async {
    final res = await _client.get('/yueku/banner');
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopIp() async {
    final res = await _client.get('/top/ip');
    final raw = res.data['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Playlist>> getIpPlaylist(String ipId) async {
    final res = await _client.get('/ip/playlist', params: {'id': ipId});
    final raw = res.data['data'];
    if (raw is List) {
      return raw
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
