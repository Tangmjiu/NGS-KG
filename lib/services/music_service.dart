import 'cache_service.dart';
import 'api_client.dart';
import '../models/song.dart';
import '../models/playlist.dart';

class MusicService {
  final ApiClient _client = ApiClient.instance;

  String get _userId => ApiClient.userId ?? '0';

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, dynamic>? params, bool withAuth = true}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (withAuth) {
      p['cookie'] = await _client.getCookieString();
    }
    final res = await _client.get(path, params: p);
    return res.data as Map<String, dynamic>;
  }

  String _cacheKey(String path, Map<String, dynamic>? params) {
    final buf = StringBuffer(path);
    if (params != null) {
      final keys = params.keys.toList()..sort();
      for (final k in keys) {
        if (k != 'cookie') buf.write('|$k=${params[k]}');
      }
    }
    return buf.toString();
  }

  Future<Map<String, dynamic>> _cachedGet(String path,
      {Map<String, dynamic>? params, bool withAuth = true, Duration? ttl}) async {
    final key = _cacheKey(path, params);
    final cached = await CacheService.instance.getJson(key);
    if (cached != null) return cached as Map<String, dynamic>;
    final res = await _get(path, params: params, withAuth: withAuth);
    await CacheService.instance.putJson(key, res, ttl: ttl ?? const Duration(hours: 2));
    return res;
  }

  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0, String type = 'song'}) async {
    final res = await _get('/search', params: {
      'keywords': keyword,
      'limit': limit,
      'offset': offset,
      'type': type,
    });
    final data = res['data'];
    final list =
        data['songs'] as List<dynamic>? ?? data['lists'] as List<dynamic>? ?? [];
    return list
        .map((e) => Song.fromKugouJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchPlaylists(String keyword,
      {int limit = 30, int offset = 0}) async {
    final res = await _get('/search', params: {
      'keywords': keyword,
      'limit': limit,
      'offset': offset,
      'type': 'special',
    });
    final data = res['data'];
    return (data['lists'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchAlbums(String keyword,
      {int limit = 30, int offset = 0}) async {
    final res = await _get('/search', params: {
      'keywords': keyword,
      'limit': limit,
      'offset': offset,
      'type': 'album',
    });
    final data = res['data'];
    return (data['lists'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchArtists(String keyword,
      {int limit = 30, int offset = 0}) async {
    final res = await _get('/search', params: {
      'keywords': keyword,
      'limit': limit,
      'offset': offset,
      'type': 'author',
    });
    final data = res['data'];
    return (data['lists'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchMvs(String keyword,
      {int limit = 30, int offset = 0}) async {
    final res = await _get('/search', params: {
      'keywords': keyword,
      'limit': limit,
      'offset': offset,
      'type': 'mv',
    });
    final data = res['data'];
    return (data['lists'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchLyrics(String keyword,
      {int limit = 30, int offset = 0}) async {
    final res = await _get('/search', params: {
      'keywords': keyword,
      'limit': limit,
      'offset': offset,
      'type': 'lyric',
    });
    final data = res['data'];
    return (data['lists'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<String>> getSearchSuggest(String keyword) async {
    final res = await _get('/search/suggest', params: {'keywords': keyword});
    final raw = res['data'];
    if (raw is List) {
      return raw.map((e) {
        if (e is String) return e;
        if (e is Map) {
          final records = e['RecordDatas'] as List<dynamic>?;
          if (records != null && records.isNotEmpty) {
            return records[0]['HintInfo'] as String? ?? e.toString();
          }
        }
        return e.toString();
      }).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getHotSearch() async {
    final res = await _cachedGet('/search/hot', ttl: const Duration(minutes: 30));
    final data = res['data'];
    if (data is Map) {
      final list = data['list'] as List<dynamic>?;
      if (list != null) {
        final keywords = <Map<String, dynamic>>[];
        for (final category in list) {
          final kwds = (category as Map)['keywords'] as List<dynamic>?;
          if (kwds != null) {
            for (final kw in kwds) {
              keywords.add(Map<String, dynamic>.from(kw as Map));
            }
          }
        }
        return keywords;
      }
    }
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<SongUrl> getSongUrl(int songId, {String? hash, String? quality}) async {
    final params = <String, dynamic>{};
    if (hash != null) {
      params['hash'] = hash;
    } else {
      params['id'] = songId;
    }
    if (quality != null) {
      params['quality'] = quality;
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
      {int page = 1, int pageSize = 1000}) async {
    final res = await _get('/playlist/track/all',
        params: {'id': gcId, 'page': page, 'pagesize': pageSize});
    final songs =
        ((res['data'] as Map<String, dynamic>)['songs'] as List<dynamic>);
    return songs
        .map((e) => Song.fromTrackJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPlaylistTracksById(int listid,
      {int page = 1, int pageSize = 1000}) async {
    final res = await _get('/playlist/track/all',
        params: {'id': 'collection_3_${_userId}_${listid}_0', 'page': page, 'pagesize': pageSize});
    final data = res['data'];
    if (data is Map) {
      final songs = data['songs'] as List<dynamic>?;
      if (songs != null) return songs.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Playlist>> getUserPlaylist({int? userId}) async {
    final params = <String, dynamic>{};
    if (userId != null) params['userId'] = userId;
    final res = await _get('/user/playlist', params: params);
    final data = res['data'];
    if (data is Map) {
      final info = data['info'] as List<dynamic>?;
      if (info != null) {
        return info
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .where((p) => p.id != 0 && p.name.isNotEmpty)
            .toList();
      }
    }
    if (data is List) {
      return data
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Playlist>> getTopPlaylists(
      {int limit = 200, int offset = 0, int categoryId = 0}) async {
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

  Future<List<Song>> getAlbumSongs(int albumId) async {
    final res = await _get('/album/songs', params: {'id': albumId});
    final data = res['data'];
    if (data is Map) {
      final list = data['songs'] as List<dynamic>?;
      if (list != null) {
        return list
            .map((e) => Song.fromKugouJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<String?> getMvUrl(String hash) async {
    final res = await _get('/mv/url', params: {'hash': hash});
    final data = res['data'];
    if (data is Map) {
      return data['url'] as String?;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getRankList() async {
    final res = await _cachedGet('/rank/list', ttl: const Duration(minutes: 30));
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

  Future<Map<String, dynamic>> getCardSongs(int cardId) async {
    final res = await _get('/top/card', params: {'card_id': cardId});
    final raw = res['data'];
    if (raw is Map) {
      final songList = raw['song_list'] as List? ?? [];
      return {
        'rec_desc': raw['rec_desc'] as String? ?? '',
        'songs': songList
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList(),
      };
    }
    return {'rec_desc': '', 'songs': <Song>[]};
  }

  Future<List<Map<String, dynamic>>> getArtistList(
      {int limit = 100, int offset = 0}) async {
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
      {int limit = 100, int offset = 0}) async {
    final res = await _get('/comment/music',
        params: {'id': songId, 'limit': limit, 'offset': offset});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    final list = (raw as Map<String, dynamic>)['comments'] as List<dynamic>?;
    if (list != null) return list.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getSheetList({int limit = 100}) async {
    final res = await _get('/sheet/list', params: {'limit': limit});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getFmRecommend() async {
    final res = await _cachedGet('/fm/recommend', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getPlaylistTags() async {
    final res = await _cachedGet('/playlist/tags', ttl: const Duration(hours: 24));
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<String> registerDevice() async {
    final res = await _get('/register/dev', withAuth: false);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final dfid = data['dfid'] as String? ?? '';
    return dfid;
  }

  Future<List<Song>> getFmSongs(int fmId) async {
    final res = await _get('/fm/songs', params: {'fmid': fmId});
    final raw = res['data'];
    List<dynamic>? songs;
    if (raw is List && raw.isNotEmpty) {
      final first = raw[0];
      if (first is Map) {
        songs = first['songs'] as List<dynamic>?;
      }
    }
    if (songs != null) {
      return songs
          .map((e) => Song.fromTrackJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
    return [];
  }

  Future<List<Map<String, dynamic>>> getUserHistory({int limit = 200}) async {
    final res = await _get('/user/history');
    final raw = res['data'];
    if (raw is Map) {
      final songs = raw['songs'] as List?;
      if (songs != null) {
        return songs
            .whereType<Map>()
            .map((e) => e['info'] as Map<String, dynamic>?)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> getLatestListen() async {
    final res = await _get('/lastest/songs/listen');
    final raw = res['data'];
    if (raw is Map) {
      final songs = raw['songs'] as List?;
      if (songs != null && songs.isNotEmpty) {
        final first = songs[0];
        if (first is Map) {
          return {
            'info': first['info'] as Map<String, dynamic>?,
            'position': first['pos'] as int? ?? 0,
          };
        }
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getPlaylistComments(int playlistId,
      {int limit = 100, int offset = 0}) async {
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

  // ─── 用户/VIP/云盘 ───

  Future<Map<String, dynamic>> getUserDetail() async {
    return _get('/user/detail');
  }

  Future<Map<String, dynamic>> getVipInfo() async {
    return _get('/vip/info');
  }

  Future<List<Map<String, dynamic>>> getUserCloudDisk() async {
    final res = await _get('/user/cloud');
    final data = res['data'];
    if (data is Map) {
      final list = data['list'] as List<dynamic>?;
      if (list != null) return list.cast<Map<String, dynamic>>();
    }
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<String> getCloudSongUrl(String hash) async {
    final res = await _get('/user/cloud/url', params: {'hash': hash});
    final data = res['data'];
    if (data is Map) return data['url'] as String? ?? '';
    return '';
  }

  Future<List<Map<String, dynamic>>> getUserHistoryRank() async {
    final res = await _get('/user/history/rank');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getContinuePlayInfo() async {
    return _get('/continue/play');
  }

  // ─── 歌手 ───

  Future<Map<String, dynamic>> followArtist(int artistId) async {
    return _get('/artist/follow', params: {'id': artistId});
  }

  Future<Map<String, dynamic>> unfollowArtist(int artistId) async {
    return _get('/artist/unfollow', params: {'id': artistId});
  }

  Future<List<Map<String, dynamic>>> getArtistNewSongs(int artistId) async {
    final res = await _get('/artist/songs/new', params: {'id': artistId});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── 曲谱合集 ───

  Future<List<Map<String, dynamic>>> getSheetCollections() async {
    final res = await _get('/sheet/collection/list');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getSheetCollectionDetail(int id) async {
    return _get('/sheet/collection/detail', params: {'id': id});
  }

  // ─── 提交听歌历史 ───

  Future<void> uploadPlayHistory(int songId, {int? duration}) async {
    final params = <String, dynamic>{'id': songId};
    if (duration != null) params['duration'] = duration;
    await _get('/playhistory/upload', params: params);
  }

  // ─── 服务器时间 ───

  Future<Map<String, dynamic>> getServerTime() async {
    return _get('/server/now', withAuth: false);
  }

  // ─── 乐库 ───

  Future<List<Map<String, dynamic>>> getYuekuBanner() async {
    final res = await _get('/yueku/banner');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getYuekuRadio() async {
    final res = await _get('/yueku/radio');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── 电台 ───

  Future<List<Map<String, dynamic>>> getRadioImages() async {
    final res = await _get('/radio/image');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── 歌单管理 ───

  Future<Map<String, dynamic>> createPlaylist(String name,
      {int type = 0, int isPri = 0, int? listCreateListid}) async {
    final params = <String, dynamic>{
      'name': name,
      'list_create_userid': _userId,
      'type': type,
      'is_pri': isPri,
    };
    if (listCreateListid != null) params['list_create_listid'] = listCreateListid;
    return _get('/playlist/add', params: params);
  }

  Future<Map<String, dynamic>> deletePlaylist(int listid) async {
    return _get('/playlist/del', params: {'listid': listid});
  }

  Future<Map<String, dynamic>> addTracksToPlaylist(
      int listid, String data) async {
    return _get('/playlist/tracks/add',
        params: {'listid': listid, 'data': data});
  }

  Future<Map<String, dynamic>> removeTracksFromPlaylist(
      int listid, String fileids) async {
    return _get('/playlist/tracks/del',
        params: {'listid': listid, 'fileids': fileids});
  }

  // ─── 收藏视频 ───

  Future<List<Map<String, dynamic>>> getFavoriteVideos() async {
    final res = await _get('/user/favorite/video');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getLikedVideos() async {
    final res = await _get('/user/liked/video');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── 关注歌手消息 ───

  Future<List<Map<String, dynamic>>> getFollowedArtistNews() async {
    final res = await _get('/artist/followed/news');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }
}
