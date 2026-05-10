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
    final page = (offset ~/ limit) + 1;
    final res = await _get('/search', params: {
      'keywords': keyword,
      'pagesize': limit,
      'page': page,
    });
    final data = res['data'] as Map<String, dynamic>?;
    if (data == null) return [];
    final list = data['songs'] as List<dynamic>? ?? data['lists'] as List<dynamic>? ?? [];
    return list
        .map((e) => Song.fromKugouJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchPlaylists(String keyword,
      {int limit = 30, int offset = 0}) async {
    final page = (offset ~/ limit) + 1;
    final res = await _get('/search', params: {
      'keywords': keyword,
      'pagesize': limit,
      'page': page,
      'type': 'special',
    });
    final data = res['data'];
    return (data['lists'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchAlbums(String keyword,
      {int limit = 30, int offset = 0}) async {
    final page = (offset ~/ limit) + 1;
    final res = await _get('/search', params: {
      'keywords': keyword,
      'pagesize': limit,
      'page': page,
      'type': 'album',
    });
    final data = res['data'];
    return (data['lists'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchArtists(String keyword,
      {int limit = 30, int offset = 0}) async {
    final page = (offset ~/ limit) + 1;
    final res = await _get('/search', params: {
      'keywords': keyword,
      'pagesize': limit,
      'page': page,
      'type': 'author',
    });
    final data = res['data'];
    return (data['lists'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchMvs(String keyword,
      {int limit = 30, int offset = 0}) async {
    final page = (offset ~/ limit) + 1;
    final res = await _get('/search', params: {
      'keywords': keyword,
      'pagesize': limit,
      'page': page,
      'type': 'mv',
    });
    final data = res['data'];
    return (data['lists'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchLyrics(String keyword,
      {int limit = 30, int offset = 0}) async {
    final page = (offset ~/ limit) + 1;
    final res = await _get('/search', params: {
      'keywords': keyword,
      'pagesize': limit,
      'page': page,
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

  Future<SongUrl> getSongUrl({required String hash, String? quality}) async {
    final params = <String, dynamic>{
      'hash': hash.toLowerCase(),
    };
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

  Future<List<Playlist>> getUserPlaylist({int? userId, int page = 1, int pageSize = 200}) async {
    final params = <String, dynamic>{
      'page': page,
      'pagesize': pageSize,
    };
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

  Future<List<Song>> getAlbumSongs(int albumId,
      {int page = 1, int pageSize = 200}) async {
    final res = await _get('/album/songs', params: {
      'id': albumId,
      'page': page,
      'pagesize': pageSize,
    });
    final data = res['data'];
    if (data is Map) {
      final list = data['songs'] as List<dynamic>?;
      if (list != null) {
        return list.map((e) {
          final json = e as Map<String, dynamic>;
          final base = json['base'] as Map<String, dynamic>? ?? {};
          final audioInfo = json['audio_info'] as Map<String, dynamic>? ?? {};
          final q = <String, String>{};
          final h128 = audioInfo['hash_128'] as String?;
          final h320 = audioInfo['hash_320'] as String?;
          final hFlac = audioInfo['hash_flac'] as String?;
          if (h128 != null && h128.isNotEmpty) q['128'] = h128;
          if (h320 != null && h320.isNotEmpty) q['320'] = h320;
          if (hFlac != null && hFlac.isNotEmpty) q['flac'] = hFlac;
          return Song(
            id: base['audio_id'] as int? ?? 0,
            name: base['audio_name'] as String? ?? '',
            artists: [(base['author_name'] as String? ?? '')],
            albumName: null,
            duration: ((audioInfo['duration'] as int?) ?? 0) ~/ 1000,
            hash: audioInfo['hash'] as String?,
            qualities: q.isNotEmpty ? q : null,
          );
        }).toList();
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

  Future<List<Song>> getRankAudios(int rankId,
      {int page = 1, int pageSize = 200, int? rankCid}) async {
    final params = <String, dynamic>{
      'rankid': rankId,
      'page': page,
      'pagesize': pageSize,
    };
    if (rankCid != null) params['rank_cid'] = rankCid;
    final res = await _get('/rank/audio', params: params);
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
        return songs.map((e) {
          final json = e as Map<String, dynamic>;
          return Song(
            id: json['audio_id'] as int? ?? json['songid'] as int? ?? 0,
            name: json['songname'] as String? ?? json['audio_name'] as String? ?? '',
            artists: [(json['author_name'] as String? ?? '')],
            albumName: json['album_name'] as String?,
            duration: ((json['timelength'] as int?) ?? 0) ~/ 1000,
            hash: json['hash'] as String?,
          );
        }).toList();
      }
    }
    return [];
  }

  Future<List<Song>> getTopSongs() async {
    final res = await _get('/top/song');
    final raw = res['data'];
    if (raw is List) {
      return raw.map((e) {
        final json = e as Map<String, dynamic>;
        var cover = json['album_sizable_cover'] as String?;
        if (cover != null) cover = cover.replaceAll('{size}', '240');
        return Song(
          id: json['audio_id'] as int? ?? 0,
          name: json['songname'] as String? ?? '',
          artists: [(json['author_name'] as String? ?? '')],
          albumName: json['album_name'] as String?,
          albumCoverUrl: cover,
          duration: (json['timelength'] as int?) ?? 0,
          hash: json['hash'] as String?,
        );
      }).toList();
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
        'songs': songList.map((e) {
          final json = e as Map<String, dynamic>;
          var cover = json['sizable_cover'] as String?;
          if (cover != null) cover = cover.replaceAll('{size}', '240');
          return Song(
            id: json['songid'] as int? ?? 0,
            name: json['songname'] as String? ?? '',
            artists: [(json['author_name'] as String? ?? '')],
            albumName: json['album_name'] as String?,
            albumCoverUrl: cover,
            duration: (json['time_length'] as int?) ?? 0,
            hash: json['hash'] as String?,
          );
        }).toList(),
      };
    }
    return {'rec_desc': '', 'songs': <Song>[]};
  }

  Future<List<Map<String, dynamic>>> getArtistList(
      {int limit = 100, int offset = 0}) async {
    final res =
        await _get('/artist/lists', params: {'limit': limit, 'offset': offset});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
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
          duration: ((json['timelength'] as int?) ?? 0) ~/ 1000,
          hash: json['hash'] as String?,
        );
      }).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMusicComments(int songId,
      {int page = 1, int pageSize = 200}) async {
    final res = await _get('/comment/music',
        params: {'id': songId, 'page': page, 'pagesize': pageSize});
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
    final res = await _cachedGet('/fm/class', ttl: const Duration(minutes: 30));
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

  Future<List<Song>> getFmSongs({String? hash, int? songid, String mode = 'normal'}) async {
    final params = <String, dynamic>{'mode': mode};
    if (hash != null) params['hash'] = hash;
    if (songid != null) params['songid'] = songid;
    final res = await _get('/personal/fm', params: params);
    final raw = res['data'];
    if (raw is Map) {
      final list = raw['songs'] as List<dynamic>?;
      if (list != null) {
        return list
            .map((e) => Song.fromTrackJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    if (raw is List) {
      return raw
          .map((e) => Song.fromTrackJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getUserHistory({String? bp}) async {
    final params = <String, dynamic>{};
    if (bp != null) params['bp'] = bp;
    final res = await _get('/user/history', params: params);
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
      {int page = 1, int pageSize = 200}) async {
    final res = await _get('/comment/playlist',
        params: {'id': playlistId, 'page': page, 'pagesize': pageSize});
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
    return _get('/user/vip/detail');
  }

  Future<List<Map<String, dynamic>>> getUserCloudDisk({int page = 1, int pageSize = 200}) async {
    final res = await _get('/user/cloud', params: {'page': page, 'pagesize': pageSize});
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

  Future<List<Map<String, dynamic>>> getUserHistoryRank({int type = 0}) async {
    final res = await _get('/user/listen', params: {'type': type});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getContinuePlayInfo({int pagesize = 30}) async {
    return _get('/lastest/songs/listen', params: {'pagesize': pagesize});
  }

  // ─── 歌手 ───

  Future<Map<String, dynamic>> followArtist(int artistId) async {
    return _get('/artist/follow', params: {'id': artistId});
  }

  Future<Map<String, dynamic>> unfollowArtist(int artistId) async {
    return _get('/artist/unfollow', params: {'id': artistId});
  }

  Future<List<Map<String, dynamic>>> getArtistNewSongs({int page = 1, int pageSize = 200}) async {
    final res = await _get('/artist/follow/newsongs', params: {'page': page, 'pagesize': pageSize});
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

  Future<List<Map<String, dynamic>>> getFavoriteVideos({int page = 1, int pageSize = 200}) async {
    final res = await _get('/user/video/collect', params: {'page': page, 'pagesize': pageSize});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getLikedVideos({int page = 1, int pageSize = 200}) async {
    final res = await _get('/user/video/love', params: {'page': page, 'pagesize': pageSize});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── 关注歌手消息 ───

  Future<List<Map<String, dynamic>>> getFollowedArtistNews({int page = 1, int pageSize = 200}) async {
    final res = await _get('/artist/follow/newsongs', params: {'page': page, 'pagesize': pageSize});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }
}
