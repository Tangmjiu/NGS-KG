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
    final list = res.data['data']['songs'] as List<dynamic>;
    return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<String>> getSearchSuggest(String keyword) async {
    final res =
        await _client.get('/search/suggest', params: {'keywords': keyword});
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }

  Future<List<String>> getHotSearch() async {
    final res = await _client.get('/search/hot');
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => e['text'] as String).toList();
  }

  Future<SongUrl> getSongUrl(int songId) async {
    final res = await _client.get('/song/url', params: {'id': songId});
    return SongUrl.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getLyric(int songId) async {
    final res = await _client.get('/lyric', params: {'id': songId});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<PlaylistDetail> getPlaylistDetail(int playlistId) async {
    final res =
        await _client.get('/playlist/detail', params: {'id': playlistId});
    return PlaylistDetail.fromJson(res.data['data'] as Map<String, dynamic>);
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
      {int limit = 30, int offset = 0}) async {
    final res = await _client.get('/top/playlist',
        params: {'limit': limit, 'offset': offset});
    final raw = res.data['data'];
    if (raw is List) {
      return raw
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final list = (raw as Map<String, dynamic>)['playlists'] as List<dynamic>?;
    if (list != null) {
      return list
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
    final res = await _client.get('/rank/list');
    final raw = res.data['data'];
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Song>> getRankAudios(int rankId) async {
    final res = await _client.get('/rank/audio', params: {'id': rankId});
    final raw = res.data['data'];
    if (raw is Map && raw['songs'] is List) {
      return (raw['songs'] as List)
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
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
}
