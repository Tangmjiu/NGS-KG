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
import '../models/user.dart' as models;
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

  Future<List<Map<String, dynamic>>> searchMvs(String keyword,
          {int limit = 30, int offset = 0}) =>
      _searchRaw(keyword, 'mv', limit: limit, offset: offset);

  Future<List<Map<String, dynamic>>> searchLyrics(String keyword,
          {int limit = 30, int offset = 0}) =>
      _searchRaw(keyword, 'lyric', limit: limit, offset: offset);

  Future<List<String>> getSearchSuggest(String keyword) =>
      song.getSearchSuggest(keyword);

  Future<List<Map<String, dynamic>>> getHotSearch() => song.getHotSearch();

  Future<SongUrl> getSongUrl(int songId, {String? hash, String? quality}) =>
      song.getSongUrl(songId, hash: hash, quality: quality);

  Future<Map<String, dynamic>> getLyric(int songId) => song.getLyric(songId);

  Future<Map<String, dynamic>> searchLyricByHash(String hash, {String? keywords}) =>
      song.searchLyricByHash(hash, keywords: keywords);

  Future<String> fetchLyricContent(int lyricId, String accessKey) =>
      song.fetchLyricContent(lyricId, accessKey);

  Future<List<Song>> getTopSongs() => song.getTopSongs();

  Future<CardSection> getCardSongs(int cardId) => song.getCardSongs(cardId);

  Future<List<Song>> getDailyRecommend() => song.getDailyRecommend();

  Future<Map<String, dynamic>> searchComplex(String keyword) =>
      song.searchComplex(keyword);

  // ─── Playlist ───

  Future<PlaylistDetail> getPlaylistDetail(String gcId) =>
      playlist.getPlaylistDetail(gcId);

  Future<List<Song>> getPlaylistTracks(String gcId,
          {int page = 1, int pageSize = 1000}) =>
      playlist.getPlaylistTracks(gcId, page: page, pageSize: pageSize);

  Future<List<Song>> getPlaylistTracksById(int listid,
          {int page = 1, int pageSize = 1000}) =>
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

  Future<Map<String, dynamic>> createPlaylist(String name,
          {int type = 0, int isPri = 0, int? listCreateListid}) {
    final f = playlist.createPlaylist(name,
        type: type, isPri: isPri, listCreateListid: listCreateListid);
    return f.then((_) => <String, dynamic>{});
  }

  Future<Map<String, dynamic>> deletePlaylist(int listid) {
    return playlist.deletePlaylist(listid).then((_) => <String, dynamic>{});
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

  Future<List<Song>> getAlbumSongs(int albumId,
          {int page = 1, int pageSize = 200}) =>
      album.getAlbumSongs(albumId, page: page, pageSize: pageSize);

  Future<List<RankEntry>> getRankList() => album.getRankList();

  Future<List<Song>> getRankAudios(int rankId,
          {int page = 1, int pageSize = 200, int? rankCid}) =>
      album.getRankAudios(rankId,
          page: page, pageSize: pageSize, rankCid: rankCid);

  Future<List<Album>> getTopAlbums({int? type, int page = 1, int pageSize = 30}) =>
      album.getTopAlbums(type: type, page: page, pageSize: pageSize);

  Future<List<SceneCategory>> getSceneLists() => album.getSceneLists();

  Future<List<Map<String, dynamic>>> getTopIp() => album.getTopIp();

  Future<List<Map<String, dynamic>>> getStyleTags() async {
    final res = await _oneShotGet('/everyday/style/recommend');
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
          {int page = 1, int pageSize = 200, String sort = 'hot'}) =>
      artist.getArtistAudios(artistId,
          page: page, pageSize: pageSize, sort: sort);

  Future<void> followArtist(int artistId) => artist.followArtist(artistId);

  Future<void> unfollowArtist(int artistId) =>
      artist.unfollowArtist(artistId);

  // ─── User ───

  Future<models.User?> getUserDetail() => user.getUserDetail();

  Future<Map<String, dynamic>> getVipInfo() => user.getVipInfo();

  Future<List<Map<String, dynamic>>> getUserHistory(
          {int page = 1, int pageSize = 200}) =>
      user.getUserHistory(page: page, pageSize: pageSize);

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

  Future<List<Map<String, dynamic>>> getFavoriteVideos(
          {int page = 1, int pageSize = 200}) =>
      user.getFavoriteVideos(page: page, pageSize: pageSize);

  Future<List<Map<String, dynamic>>> getLikedVideos(
          {int page = 1, int pageSize = 200}) =>
      user.getLikedVideos(page: page, pageSize: pageSize);

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

  Future<String?> getMvUrl(String hash) {
    return _getMvUrlFromVideoEndpoint(hash).then((url) {
      if (url != null) return url;
      // Fallback: try constructing URL directly (some proxies support this)
      return _oneShotGet('/video/url', params: {
        'hash': hash,
        'ext': 'mp4',
      }).then((res) {
        // Unwrap nested response structures
        String? extractUrl(dynamic d) {
          if (d is! Map) return null;
          return (d['url'] ?? d['play_url'] ?? d['mv_url']
              ?? d['hd_url'] ?? d['h264'] ?? d['mp4_url']
              ?? d['video_url'] ?? d['downurl'] ?? d['down_url']
          ) as String?;
        }
        final data = res['data'];
        if (data is Map) {
          final direct = extractUrl(data);
          if (direct != null) return direct;
          // Try nesting: data -> info -> first item -> url
          final info = data['info'] as List<dynamic>?;
          if (info != null && info.isNotEmpty) {
            return extractUrl(info[0] as Map?);
          }
          final list = data['list'] as List<dynamic>?;
          if (list != null && list.isNotEmpty) {
            return extractUrl(list[0] as Map?);
          }
          final result = data['result'] as List<dynamic>?;
          if (result != null && result.isNotEmpty) {
            return extractUrl(result[0] as Map?);
          }
        }
        return null;
      });
    });
  }

  Future<String?> _getMvUrlFromVideoEndpoint(String hash) async {
    try {
      final res = await _oneShotGet('/video/url', params: {'hash': hash});
      final data = res['data'];
      if (data is Map) {
        final url = (data['url'] ?? data['play_url'] ?? data['mv_url']
            ?? data['hd_url'] ?? data['h264'] ?? data['mp4_url']
            ?? data['video_url'] ?? data['downurl'] ?? data['down_url']
        ) as String?;
        if (url != null && url.isNotEmpty) return url;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Sheet / 曲谱（遗留，待删除） ───

  Future<List<Map<String, dynamic>>> getSheetList({int limit = 100}) =>
      _oneShotGet('/sheet/list', params: {'limit': limit})
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  Future<Map<String, dynamic>> getSheetDetail(int sheetId) =>
      _oneShotGet('/sheet/detail', params: {'id': sheetId});

  Future<List<Map<String, dynamic>>> getHotSheets() =>
      _oneShotGet('/sheet/hot')
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  Future<List<Map<String, dynamic>>> getSheetCollections() =>
      _oneShotGet('/sheet/collection')
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  Future<Map<String, dynamic>> getSheetCollectionDetail(int id) =>
      _oneShotGet('/sheet/collection', params: {'collection_id': id});

  // ─── 乐库 / 电台（遗留，待删除） ───

  Future<List<Map<String, dynamic>>> getYuekuBanner() =>
      _oneShotGet('/yueku/banner', withAuth: false)
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  Future<List<Map<String, dynamic>>> getYuekuRadio() =>
      _oneShotGet('/yueku/fm')
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

  Future<List<Map<String, dynamic>>> getRadioImages() =>
      _oneShotGet('/fm/image')
          .then((res) => res['data'] is List ? (res['data'] as List).cast<Map<String, dynamic>>() : []);

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
      {Map<String, dynamic>? params, bool withAuth = true}) async {
    final client = ApiClient.instance;
    final options = withAuth ? null : Options(extra: {'noAuth': true});
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
