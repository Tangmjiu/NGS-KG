import 'dart:typed_data';
import '../repositories/song_repository.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/album_repository.dart';
import '../repositories/artist_repository.dart';
import '../repositories/user_repository.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/album.dart';
import '../models/rank_entry.dart';
import '../models/artist.dart';
import '../models/radio.dart';
import '../models/playlist_tag.dart';
import '../models/card_section.dart';
import '../models/latest_listen_info.dart';
import '../models/scene_category.dart';
import '../models/song_mapper.dart';
import '../models/user.dart' as models;
import '../models/vip_info.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';

class MusicService {
  final SongRepository song;
  final PlaylistRepository playlist;
  final AlbumRepository album;
  final ArtistRepository artist;
  final UserRepository user;

  MusicService()
      : song = SongRepository(ApiClient.instance),
        playlist = PlaylistRepository(ApiClient.instance),
        album = AlbumRepository(ApiClient.instance),
        artist = ArtistRepository(ApiClient.instance),
        user = UserRepository(ApiClient.instance);

  // ─── Song ───

  Future<List<Song>> search(String keyword,
          {int limit = 30, int offset = 0, String type = 'song'}) =>
      song.search(keyword, limit: limit, offset: offset, type: type);

  Future<List<Map<String, dynamic>>> searchPlaylists(String keyword,
          {int limit = 30, int offset = 0}) =>
      _searchRaw(keyword, 'special', limit: limit, offset: offset);

  Future<List<Map<String, dynamic>>> searchAlbums(String keyword,
          {int limit = 30, int offset = 0}) =>
      _searchRaw(keyword, 'album', limit: limit, offset: offset);

  Future<List<Map<String, dynamic>>> searchArtists(String keyword,
          {int limit = 30, int offset = 0}) =>
      _searchRaw(keyword, 'author', limit: limit, offset: offset);

  // MV: Future<List<Map<String, dynamic>>> searchMvs(String keyword,
  // MV:         {int limit = 30, int offset = 0}) =>
  // MV:     _searchRaw(keyword, 'mv', limit: limit, offset: offset);

  Future<List<Map<String, dynamic>>> searchLyrics(String keyword,
          {int limit = 30, int offset = 0}) =>
      _searchRaw(keyword, 'lyric', limit: limit, offset: offset);

  Future<List<String>> getSearchSuggest(String keyword) =>
      song.getSearchSuggest(keyword);

  Future<List<Map<String, dynamic>>> getHotSearch() => song.getHotSearch();

  Future<SongUrl> getSongUrl(int songId, {String? hash, String? quality}) =>
      song.getSongUrl(songId, hash: hash, quality: quality);

  /// 获取歌曲可用音质列表（特权信息）
  Future<Map<String, dynamic>> getPrivilegeLite(String hash) =>
      song.getPrivilegeLite(hash);

  Future<int?> getSongClimax(String hash) => song.getSongClimax(hash);

  Future<bool> uploadMixPlayHistory(String mixSongId) async {
    try {
      final ot = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();
      await _oneShotGet('/playhistory/upload', params: {
        'mxid': mixSongId,
        'ot': ot,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Song>> getUserListenHistory({int type = 0}) async {
    try {
      final res = await _oneShotGet('/user/listen', params: {'type': type.toString()});
      final data = res;
      final songs = (data['data'] ?? data['list'] ?? []) as List<dynamic>;
      return songs
          .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
          .whereType<Song>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> searchLyricByHash(String hash, {String? keywords}) =>
      song.searchLyricByHash(hash, keywords: keywords);

  Future<String> fetchLyricContent(int lyricId, String accessKey) =>
      song.fetchLyricContent(lyricId, accessKey);

  Future<Uint8List> fetchKrcContent(int lyricId, String accessKey) =>
      song.fetchKrcContent(lyricId, accessKey);

  Future<List<Song>> getTopSongs() => song.getTopSongs();

  Future<CardSection> getCardSongs(int cardId) => song.getCardSongs(cardId);
  Future<CardSection> getCardSongsYouth(int cardId, {int? pagesize}) =>
      song.getCardSongsYouth(cardId, pagesize: pagesize);

  Future<List<Song>> getDailyRecommend() => song.getDailyRecommend();

  Future<Map<String, dynamic>> searchComplex(String keyword) =>
      song.searchComplex(keyword);

  Future<Map<String, dynamic>?> getKrmAudio(int albumAudioId) =>
      song.getKrmAudio(albumAudioId);

  // ─── Playlist ───

  Future<PlaylistDetail> getPlaylistDetail(String gcId) =>
      playlist.getPlaylistDetail(gcId);

  Future<List<Song>> getPlaylistTracks(String gcId,
          {int page = 1, int pageSize = 30}) =>
      playlist.getPlaylistTracks(gcId, page: page, pageSize: pageSize);

  Future<List<Song>> getPlaylistTracksById(int listid,
          {int page = 1, int pageSize = 30}) =>
      playlist.getPlaylistTracksById(listid, page: page, pageSize: pageSize);

  Future<List<Playlist>> getUserPlaylist(
          {int? userId, int page = 1, int pageSize = 200}) =>
      playlist.getUserPlaylist(userId: userId, page: page, pageSize: pageSize);

  Future<List<Playlist>> getTopPlaylists(
          {int limit = 200, int offset = 0, int categoryId = 0}) =>
      playlist.getTopPlaylists(
          limit: limit, offset: offset, categoryId: categoryId);

  Future<List<PlaylistTag>> getPlaylistTags() => playlist.getPlaylistTags();

  Future<List<Comment>> getPlaylistComments(int playlistId,
          {int page = 1, int pageSize = 200}) =>
      playlist.getPlaylistComments(playlistId, page: page, pageSize: pageSize);

  Future<List<Playlist>> getSimilarPlaylists(String ids) =>
      playlist.getSimilarPlaylists(ids);

  Future<List<Song>> getPlaylistTracksNew(int listid,
          {int page = 1, int pageSize = 30}) =>
      playlist.getPlaylistTracksNew(listid, page: page, pageSize: pageSize);

  Future<Map<String, dynamic>> createPlaylist(String name,
          {int type = 0, int isPri = 0, int? listCreateListid,
           int? listCreateUserid}) async {
    return playlist.createPlaylist(name,
        type: type, isPri: isPri, listCreateListid: listCreateListid,
        listCreateUserid: listCreateUserid);
  }

  Future<void> deletePlaylist(int listid) async {
    await playlist.deletePlaylist(listid);
  }

  Future<Map<String, dynamic>> addTracksToPlaylist(int listid, String data) {
    return playlist.addTracksToPlaylist(listid, data);
  }

  Future<Map<String, dynamic>> removeTracksFromPlaylist(
      int listid, String fileids) {
    return playlist
        .removeTracksFromPlaylist(listid, fileids)
        .then((_) => <String, dynamic>{});
  }

  // ─── Album ───

  Future<Album?> getAlbumDetail(int albumId) =>
      album.getAlbumDetail(albumId);

  Future<List<Song>> getAlbumSongs(int albumId) =>
      album.getAlbumSongs(albumId);

  Future<List<RankEntry>> getRankList() => album.getRankList();

  Future<List<Song>> getRankAudios(int rankId,
          {int page = 1, int pageSize = 200, int? rankCid}) =>
      album.getRankAudios(rankId,
          page: page, pageSize: pageSize, rankCid: rankCid);

  Future<List<Album>> getTopAlbums({int? type, int page = 1, int pageSize = 30}) =>
      album.getTopAlbums(type: type, page: page, pageSize: pageSize);

  Future<List<SceneCategory>> getSceneLists() => album.getSceneLists();

  Future<List<Map<String, dynamic>>> getTopIp() => album.getTopIp();

  Future<List<Map<String, dynamic>>> getIpZone() => album.getIpZone();

  Future<Map<String, dynamic>> getIpZoneHome(int id) =>
      album.getIpZoneHome(id);

  Future<List<Map<String, dynamic>>> getStyleTags() async {
    final res = await _oneShotGet('/everyday/style/recommend', params: {'platform': 'android'});
    final data = res['data'];
    if (data is Map) {
      final list = data['tag_list'] as List<dynamic>?;
      if (list != null) return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── Artist ───

  Future<List<Artist>> getArtistList({int limit = 100, int offset = 0}) =>
      artist.getArtistList(limit: limit, offset: offset);

  Future<Map<String, dynamic>> getArtistDetail(int artistId) =>
      artist.getArtistDetail(artistId);

  Future<List<Song>> getArtistAudios(int artistId,
          {int page = 1, int pageSize = 50, String sort = 'hot'}) =>
      artist.getArtistAudios(artistId,
          page: page, pageSize: pageSize, sort: sort);

  Future<List<Album>> getArtistAlbums(int artistId,
          {int page = 1, int pageSize = 50, String sort = 'hot'}) =>
      artist.getArtistAlbums(artistId,
          page: page, pageSize: pageSize, sort: sort);

  // MV: Future<List<Map<String, dynamic>>> getArtistVideos(int artistId,
  // MV:         {int page = 1, int pageSize = 20}) =>
  // MV:     artist.getArtistVideos(artistId, page: page, pageSize: pageSize);

  Future<void> followArtist(int artistId) => artist.followArtist(artistId);

  Future<void> unfollowArtist(int artistId) =>
      artist.unfollowArtist(artistId);

  // ─── User ───

  Future<models.User?> getUserDetail() => user.getUserDetail();

  Future<VipInfo?> getVipInfo() => user.getVipInfo();

  Future<List<Map<String, dynamic>>> getUserHistory({String? bp}) =>
      user.getUserHistory(bp: bp);

  Future<LatestListenInfo?> getLatestListen() => user.getLatestListen();

  Future<Map<String, dynamic>> getContinuePlayInfo() =>
      user.getContinuePlayInfo();

  Future<List<Map<String, dynamic>>> getUserCloudDisk(
          {int page = 1, int pageSize = 200}) =>
      user.getUserCloudDisk(page: page, pageSize: pageSize);

  Future<String> getCloudSongUrl(String hash,
          {int? albumId, String? name, int? albumAudioId}) =>
      user.getCloudSongUrl(hash,
          albumId: albumId, name: name, albumAudioId: albumAudioId);

  // MV: Future<List<Map<String, dynamic>>> getFavoriteVideos(
  // MV:         {int page = 1, int pageSize = 200}) =>
  // MV:     user.getFavoriteVideos(page: page, pageSize: pageSize);
  // MV:
  // MV: Future<List<Map<String, dynamic>>> getLikedVideos(
  // MV:         {int page = 1, int pageSize = 200}) =>
  // MV:     user.getLikedVideos(page: page, pageSize: pageSize);

  Future<List<Map<String, dynamic>>> getFollowedArtistNews(
          {int page = 1, int pageSize = 200}) =>
      user.getFollowedArtistNews(page: page, pageSize: pageSize);

  Future<List<Comment>> getMusicComments(int songId,
          {int page = 1, int pageSize = 200}) =>
      user.getMusicComments(songId, page: page, pageSize: pageSize);

  Future<void> uploadPlayHistory(int songId, {int? duration}) =>
      user.uploadPlayHistory(songId, duration: duration);

  Future<DateTime?> getServerTime() => user.getServerTime();

  Future<String> registerDevice() => user.registerDevice();

  Future<List<RadioStation>> getFmRecommend() => user.getFmRecommend();

  Future<List<Song>> getFmSongs(int fmId) => user.getFmSongs(fmId);

  // MV:
  // MV: Future<String?> getMvUrl(String hash) {
  // MV:   return _getMvUrlFromVideoEndpoint(hash).then((url) {
  // MV:     if (url != null) return url;
  // MV:     return _oneShotGet('/video/url', params: {
  // MV:       'hash': hash,
  // MV:       'ext': 'mp4',
  // MV:     }).then((res) {
  // MV:       final d = res['data'];
  // MV:       if (d is! Map) return null;
  // MV:       return (d['url'] ?? d['play_url'] ?? d['mv_url']
  // MV:           ?? d['hd_url'] ?? d['h264'] ?? d['mp4_url']
  // MV:           ?? d['video_url'] ?? d['downurl'] ?? d['down_url']
  // MV:       ) as String?;
  // MV:     });
  // MV:   });
  // MV: }
  // MV:
  // MV: Future<String?> _getMvUrlFromVideoEndpoint(String hash) async {
  // MV:   try {
  // MV:     final res = await _oneShotGet('/video/url', params: {'hash': hash});
  // MV:     final data = res['data'];
  // MV:     if (data is Map) {
  // MV:       final url = (data['url'] ?? data['play_url'] ?? data['mv_url']
  // MV:           ?? data['hd_url'] ?? data['h264'] ?? data['mp4_url']
  // MV:           ?? data['video_url'] ?? data['downurl'] ?? data['down_url']
  // MV:       ) as String?;
  // MV:       if (url != null && url.isNotEmpty) return url;
  // MV:     }
  // MV:     final data = res['data'];
  // MV:     if (data is Map) {
  // MV:       final direct = extractUrl(data);
  // MV:       if (direct != null) return direct;
  // MV:       final info = data['info'] as List<dynamic>?;
  // MV:       if (info != null && info.isNotEmpty) {
  // MV:         return extractUrl(info[0] as Map?);
  // MV:       }
  // MV:       final list = data['list'] as List<dynamic>?;
  // MV:       if (list != null && list.isNotEmpty) {
  // MV:         return extractUrl(list[0] as Map?);
  // MV:       }
  // MV:       final result = data['result'] as List<dynamic>?;
  // MV:       if (result != null && result.isNotEmpty) {
  // MV:         return extractUrl(result[0] as Map?);
  // MV:       }
  // MV:     }
  // MV:     return null;
  // MV:   });
  // MV:   });
  // MV: }
  // MV:
  // MV: Future<String?> _getMvUrlFromVideoEndpoint(String hash) async {
  // MV:   try {
  // MV:     final res = await _oneShotGet('/video/url', params: {'hash': hash});
  // MV:     final data = res['data'];
  // MV:     if (data is Map) {
  // MV:       final url = (data['url'] ?? data['play_url'] ?? data['mv_url']
  // MV:           ?? data['hd_url'] ?? data['h264'] ?? data['mp4_url']
  // MV:           ?? data['video_url'] ?? data['downurl'] ?? data['down_url']
  // MV:       ) as String?;
  // MV:       if (url != null && url.isNotEmpty) return url;
  // MV:     }
  // MV:     return null;
  // MV:   } catch (_) {
  // MV:     return null;
  // MV:   }
  // MV: }

  // ─── 曲谱（Sheet / 乐谱） ───
  // API 文档: /sheet/song 获取曲谱, /sheet/detail 曲谱详情, /sheet/rank 曲谱排行榜
  //          /sheet/explore 曲谱广场, /sheet/tags 曲谱标签

  Future<Map<String, dynamic>> getSheetDetail(int sheetId) =>
      _oneShotGet('/sheet/detail', params: {'id': sheetId});

  // ─── 乐库 / 电台 ───

  Future<List<Map<String, dynamic>>> getYuekuRadio() =>
      _oneShotGet('/yueku/fm')
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  Future<List<Map<String, dynamic>>> getYuekuAll() =>
      _oneShotGet('/yueku')
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  Future<List<Map<String, dynamic>>> getFmClass() =>
      _oneShotGet('/fm/class')
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  Future<List<Map<String, dynamic>>> getRadioImages(String fmid) =>
      _oneShotGet('/fm/image', params: {'fmid': fmid})
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  // ─── 推荐 ───

  /// 私人 FM（猜你喜欢）
  ///
  /// [mode] normal=红心 small=小众
  /// [songPoolId] 0=Alpha 1=Beta 2=Gamma
  Future<List<Map<String, dynamic>>> getPersonalFm({String mode = 'normal', int songPoolId = 0}) async {
    final params = <String, dynamic>{'mode': mode, 'song_pool_id': songPoolId};
    // 部分服务器需要 cookie 查询参数
    final cookieStr = await _getCookieString();
    if (cookieStr != null) params['cookie'] = cookieStr;
    final res = await _oneShotGet('/personal/fm', params: params, silent: true);
    if (res['data'] is List) return (res['data'] as List).cast<Map<String, dynamic>>();
    return [];
  }

  /// 历史推荐
  /// API 文档: GET /everyday/history
  /// mode=list 返回历史推荐列表, mode=song 需传 history_name 和 date
  Future<List<Map<String, dynamic>>> getHistoryRecommend() =>
      _oneShotGet('/everyday/history', params: {'mode': 'list', 'platform': 'android'})
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  /// AI 推荐
  Future<List<Map<String, dynamic>>> getAiRecommend() =>
      _oneShotGet('/ai/recommend')
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  // ─── 主题音乐 ───

  Future<List<Map<String, dynamic>>> getThemeMusic() =>
      _oneShotGet('/theme/music')
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  Future<Map<String, dynamic>> getThemeMusicDetail(int id) =>
      _oneShotGet('/theme/music/detail', params: {'id': id});

  // ─── 遗留方法（保留但已迁移到 repo） ───

  Future<List<Map<String, dynamic>>> getUserHistoryRank() =>
      user.getUserHistoryRank();

  Future<List<Map<String, dynamic>>> getArtistNewSongs(int artistId,
          {int page = 1, int pageSize = 200}) =>
      _oneShotGet('/artist/follow/newsongs',
              params: {'id': artistId, 'page': page, 'pagesize': pageSize})
          .then((res) =>
              res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  // ─── 内部辅助 ───

  /// 认证信息已由 ApiClient._AuthInterceptor 自动注入 Authorization 头
  Future<Map<String, dynamic>> _oneShotGet(String path,
      {Map<String, dynamic>? params, bool withAuth = true, bool silent = false}) async {
    final client = ApiClient.instance;
    final extra = <String, dynamic>{};
    if (!withAuth) extra['noAuth'] = true;
    if (silent) extra['silent'] = true;
    final options = extra.isNotEmpty ? Options(extra: extra) : null;
    final res = await client.get(path, params: params, options: options);
    return res.data as Map<String, dynamic>;
  }

  /// Raw search helper for endpoints that haven't been fully typed yet
  Future<List<Map<String, dynamic>>> _searchRaw(String keyword, String type,
      {int limit = 30, int offset = 0}) async {
    final params = <String, dynamic>{
      'keywords': keyword,
      'page': (offset ~/ limit) + 1,
      'pagesize': limit,
      'type': type,
    };
    // 搜索接口必须携带 cookie 查询参数
    final cookieStr = await _getCookieString();
    if (cookieStr != null) params['cookie'] = cookieStr;
    final res = await _oneShotGet('/search', params: params);
    final data = res['data'];
    if (data == null) return [];
    final lists = data['lists'] as List<dynamic>? ?? data['list'] as List<dynamic>? ?? [];
    return lists.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<String?> _getCookieString() async {
    try {
      return await ApiClient.instance.getCookieString();
    } catch (_) {
      return null;
    }
  }
}
