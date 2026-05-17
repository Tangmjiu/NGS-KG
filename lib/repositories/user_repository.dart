import '../services/api_client.dart';
import '../models/song.dart';
import '../models/user.dart';
import '../models/artist.dart';
import '../models/radio.dart';
import '../models/song_mapper.dart';
import '../models/latest_listen_info.dart';

class UserRepository {
  final ApiClient _client;

  UserRepository(this._client);

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, dynamic>? params, bool withAuth = true}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (withAuth) {
      p['cookie'] = await _client.getCookieString();
    }
    final res = await _client.get(path, params: p);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _cachedGet(String path,
      {Map<String, dynamic>? params, bool withAuth = true, Duration? ttl}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (withAuth) {
      p['cookie'] = await _client.getCookieString();
    }
    final res = await _client.getCached(path, params: p, ttl: ttl ?? const Duration(hours: 2));
    return res.data as Map<String, dynamic>;
  }

  Future<User?> getUserDetail() async {
    final res = await _get('/user/detail');
    final data = res['data'] as Map<String, dynamic>?;
    if (data != null) return User.fromJson(data);
    return null;
  }

  Future<Map<String, dynamic>> getVipInfo() async {
    return _get('/user/vip/detail');
  }

  Future<List<Map<String, dynamic>>> getUserHistory(
      {int page = 1, int pageSize = 200}) async {
    final res =
        await _get('/user/history', params: {'page': page, 'pagesize': pageSize});
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

  Future<LatestListenInfo?> getLatestListen() async {
    final res = await _get('/lastest/songs/listen', params: {'pagesize': 30});
    final raw = res['data'];
    if (raw is Map) {
      final songs = raw['songs'] as List?;
      if (songs != null && songs.isNotEmpty) {
        final first = songs[0];
        if (first is Map) {
          return LatestListenInfo(
            info: first['info'] as Map<String, dynamic>?,
            position: first['pos'] as int? ?? 0,
          );
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> getContinuePlayInfo() async {
    return _get('/lastest/songs/listen', params: {'pagesize': 1});
  }

  Future<List<Map<String, dynamic>>> getUserCloudDisk(
      {int page = 1, int pageSize = 200}) async {
    final res =
        await _get('/user/cloud', params: {'page': page, 'pagesize': pageSize});
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
    final res = await _get('/user/listen', params: {'type': 0});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getFavoriteVideos(
      {int page = 1, int pageSize = 200}) async {
    final res = await _get('/user/video/collect',
        params: {'page': page, 'pagesize': pageSize});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getLikedVideos(
      {int page = 1, int pageSize = 200}) async {
    final res =
        await _get('/user/video/love', params: {'page': page, 'pagesize': pageSize});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getFollowedArtistNews(
      {int page = 1, int pageSize = 200}) async {
    final res = await _get('/user/follow/message',
        params: {'page': page, 'pagesize': pageSize});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Comment>> getMusicComments(int songId,
      {int page = 1, int pageSize = 200}) async {
    final res = await _get('/comment/music',
        params: {'mixsongid': songId, 'page': page, 'pagesize': pageSize});
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

  Future<void> uploadPlayHistory(int songId, {int? duration}) async {
    final params = <String, dynamic>{'id': songId};
    if (duration != null) params['duration'] = duration;
    await _get('/playhistory/upload', params: params);
  }

  Future<DateTime?> getServerTime() async {
    final res = await _get('/server/now', withAuth: false);
    final data = res['data'];
    if (data is Map) {
      final ts = data['timestamp'];
      if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is String) {
        final parsed = int.tryParse(ts);
        if (parsed != null) return DateTime.fromMillisecondsSinceEpoch(parsed);
      }
    }
    return null;
  }

  Future<String> registerDevice() async {
    final res = await _get('/register/dev', withAuth: false);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    return data['dfid'] as String? ?? '';
  }

  Future<List<RadioStation>> getFmRecommend() async {
    final res =
        await _cachedGet('/fm/recommend', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => RadioStation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
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
          .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
          .whereType<Song>()
          .toList();
    }
    return [];
  }
}
