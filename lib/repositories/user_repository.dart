import '../services/api_client.dart';
import 'base_repository.dart';
import '../models/song.dart';
import '../models/user.dart';
import '../models/artist.dart';
import '../models/radio.dart';
import '../models/song_mapper.dart';
import '../models/latest_listen_info.dart';
import '../models/vip_info.dart';

class UserRepository extends BaseRepository {
  UserRepository(super.client);

  String get _userId => ApiClient.userId ?? '0';

  Future<User?> getUserDetail() async {
    final res = await get('/user/detail');
    final data = res['data'] as Map<String, dynamic>?;
    if (data != null) return User.fromJson(data);
    return null;
  }

  Future<VipInfo?> getVipInfo() async {
    final res = await get('/user/vip/detail');
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return VipInfo.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getUserHistory({String? bp, int pageSize = 300}) async {
    final params = <String, dynamic>{'pagesize': pageSize};
    if (bp != null) params['bp'] = bp;
    final res = await get('/user/history', params: params);
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
    final res = await get('/lastest/songs/listen', params: {'pagesize': 1});
    final raw = res['data'];
    if (raw is Map) {
      final devInfo = raw['dev_info'] as Map<String, dynamic>?;
      final currSong = raw['curr_song'] as Map?;
      if (currSong is Map) {
        return LatestListenInfo(
          info: currSong['info'] as Map<String, dynamic>?,
          position: currSong['pos'] as int? ?? 0,
          devInfo: devInfo,
        );
      }
      // fallback: use songs array
      final songs = raw['songs'] as List?;
      if (songs != null && songs.isNotEmpty) {
        final first = songs[0];
        if (first is Map) {
          return LatestListenInfo(
            info: first['info'] as Map<String, dynamic>?,
            position: first['pos'] as int? ?? 0,
            devInfo: devInfo,
          );
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> getContinuePlayInfo() async {
    return get('/lastest/songs/listen', params: {'pagesize': 1});
  }

  Future<List<Map<String, dynamic>>> getUserCloudDisk(
      {int page = 1, int pageSize = 200}) async {
    final res =
        await get('/user/cloud', params: {'page': page, 'pagesize': pageSize});
    final data = res['data'];
    if (data is Map) {
      final list = data['list'] as List<dynamic>?
          ?? data['songs'] as List<dynamic>?
          ?? data['data'] as List<dynamic>?
          ?? data['items'] as List<dynamic>?;
      if (list != null) return list.cast<Map<String, dynamic>>();
    }
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<String> getCloudSongUrl(String hash,
      {int? albumId, String? name, int? albumAudioId}) async {
    final params = <String, dynamic>{'hash': hash};
    if (albumId != null) params['album_id'] = albumId;
    if (name != null && name.isNotEmpty) params['name'] = name;
    if (albumAudioId != null) params['album_audio_id'] = albumAudioId;
    final res = await get('/user/cloud/url', params: params);
    final data = res['data'];
    if (data is Map) return data['url'] as String? ?? '';
    return '';
  }

  Future<List<Map<String, dynamic>>> getUserHistoryRank() async {
    final res = await get('/user/listen', params: {'type': 0, 'pagesize': 300});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  // MV:
  // MV: Future<List<Map<String, dynamic>>> getFavoriteVideos(
  // MV:     {int page = 1, int pageSize = 200}) async {
  // MV:   final res = await get('/user/video/collect',
  // MV:       params: {'page': page, 'pagesize': pageSize});
  // MV:   final raw = res['data'];
  // MV:   if (raw is List) return raw.cast<Map<String, dynamic>>();
  // MV:   return [];
  // MV: }
  // MV:
  // MV: Future<List<Map<String, dynamic>>> getLikedVideos(
  // MV:     {int page = 1, int pageSize = 200}) async {
  // MV:   final res =
  // MV:       await get('/user/video/love', params: {'page': page, 'pagesize': pageSize});
  // MV:   final raw = res['data'];
  // MV:   if (raw is List) return raw.cast<Map<String, dynamic>>();
  // MV:   return [];
  // MV: }

  Future<List<Map<String, dynamic>>> getFollowedArtistNews(
      {int page = 1, int pageSize = 200}) async {
    final res = await get('/user/follow/message',
        params: {'id': _userId, 'page': page, 'pagesize': pageSize});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Comment>> getMusicComments(int songId,
      {int page = 1, int pageSize = 200}) async {
    final res = await get('/comment/music',
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
    // API 文档: mxid=专辑音乐id(MixSongID), ot=秒级时间戳, pc=播放次数
    final params = <String, dynamic>{'mxid': songId};
    if (duration != null && duration > 0) {
      params['ot'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      params['pc'] = 1;
    }
    await get('/playhistory/upload', params: params);
  }

  Future<DateTime?> getServerTime() async {
    final res = await get('/server/now', withAuth: false);
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
    final res = await get('/register/dev', withAuth: false);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    return data['dfid'] as String? ?? '';
  }

  Future<List<RadioStation>> getFmRecommend() async {
    final res =
        await cachedGet('/fm/recommend', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => RadioStation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Song>> getFmSongs(int fmId) async {
    final res = await get('/fm/songs', params: {'fmid': fmId});
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
