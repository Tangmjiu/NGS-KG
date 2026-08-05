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

  // 服务端时间偏移缓存（秒），避免每次上传前都请求 /server/now
  int? _serverTimeOffsetSec;
  DateTime? _serverTimeFetchedAt;
  static const _serverTimeCacheTtl = Duration(minutes: 5);

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

  Future<List<Map<String, dynamic>>> getUserHistory(
      {String? bp, int pageSize = 300}) async {
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
      final list = data['list'] as List<dynamic>? ??
          data['songs'] as List<dynamic>? ??
          data['song_list'] as List<dynamic>? ??
          data['lists'] as List<dynamic>? ??
          data['info'] as List<dynamic>? ??
          data['data'] as List<dynamic>? ??
          data['items'] as List<dynamic>?;
      if (list != null) {
        return list.map((e) {
          final raw = (e is Map && e['info'] is Map)
              ? Map<String, dynamic>.from(e['info'] as Map)
              : Map<String, dynamic>.from(e as Map);
          return _normalizeCloudSong(raw);
        }).toList();
      }
    }
    if (data is List) {
      return data
          .map((e) => _normalizeCloudSong(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// 归一化云盘歌曲字段（参照 EchoMusic mapCloudSong）：
  /// 酷狗 /user/cloud 返回的每项常含 audio_info / album_info / trans_param
  /// 嵌套结构，且顶层字段为 songname/singername/timelen/albumid 等，
  /// 与在线歌曲的 name/author_name/timelength 命名不同。
  /// 统一输出: hash/name/artist/albumName/cover/albumId/duration(秒)/
  ///           mixSongId/albumAudioId/kvId
  Map<String, dynamic> _normalizeCloudSong(Map<String, dynamic> raw) {
    final audioInfo =
        raw['audio_info'] is Map ? raw['audio_info'] as Map : null;
    final albumInfo =
        raw['album_info'] is Map ? raw['album_info'] as Map : null;
    final transParam =
        raw['trans_param'] is Map ? raw['trans_param'] as Map : null;

    String str(dynamic v) => v?.toString().trim() ?? '';
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(str(v)) ?? 0;
    }

    // 名称：顶层 filename 常为 "歌手 - 歌名.mp3"
    var name = str(raw['songname'] ?? raw['filename'] ?? raw['name']);
    if (name.isEmpty) name = str(audioInfo?['songname']);
    name = name.replaceAll(
        RegExp(r'\.(mp3|flac|wav|m4a|ape|ogg)$', caseSensitive: false), '');
    var artist = str(raw['singername'] ?? raw['author_name']);
    if (artist.isEmpty) artist = str(audioInfo?['author_name']);
    if (artist.isEmpty && name.contains(' - ')) {
      final parts = name.split(' - ');
      artist = parts.first.trim();
      name = parts.sublist(1).join(' - ').trim();
    }

    // 封面：{size} 占位符替换为 480
    var cover = str(raw['cover'] ?? raw['pic']);
    if (cover.isEmpty) cover = str(albumInfo?['sizable_cover']);
    if (cover.isEmpty) cover = str(transParam?['union_cover']);
    if (cover.contains('{size}')) cover = cover.replaceAll('{size}', '480');
    if (cover.startsWith('//')) cover = 'https:$cover';

    // 时长：timelen 为毫秒（>1000 判定），其余为秒
    var duration = toInt(raw['duration'] ?? raw['timelen'] ?? 0);
    if (duration <= 0) duration = toInt(audioInfo?['duration']);
    if (duration > 1000) duration = duration ~/ 1000;

    final hash = str(raw['hash']);
    final effectiveHash = hash.isNotEmpty ? hash : str(audioInfo?['hash']);
    final albumAudioId =
        toInt(raw['album_audio_id'] ?? audioInfo?['album_audio_id']);
    final kvId = toInt(raw['kv_id'] ?? raw['fileid']);

    return {
      'hash': effectiveHash,
      'name': name,
      'artist': artist,
      'albumName': str(
          raw['albumname'] ?? raw['album_name'] ?? albumInfo?['album_name']),
      'cover': cover.isNotEmpty ? cover : null,
      'albumId': toInt(raw['albumid'] ??
          raw['album_id'] ??
          albumInfo?['id'] ??
          albumInfo?['album_id']),
      'duration': duration,
      'mixSongId':
          toInt(raw['mixsongid'] ?? raw['audio_id'] ?? audioInfo?['audio_id']),
      'albumAudioId': albumAudioId,
      'kvId': kvId,
    };
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

  /// 获取用户关注的歌手/用户列表（/user/follow，需要登录）
  Future<List<Map<String, dynamic>>> getFollowedArtists() async {
    final res = await get('/user/follow');
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map) {
      final list = raw['list'] as List<dynamic>? ??
          raw['lists'] as List<dynamic>? ??
          raw['info'] as List<dynamic>?;
      if (list != null) return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取关注歌手消息（/user/follow/message，需要登录）
  /// 文档参数：id（歌手/用户 userid）、pagesize；不支持 page 分页参数。
  Future<List<Map<String, dynamic>>> getFollowedArtistNews(
      {int page = 1, int pageSize = 200}) async {
    final res = await get('/user/follow/message',
        params: {'id': _userId, 'pagesize': pageSize});
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  /// 删除用户云盘音乐（/user/cloud/del，需要登录）
  ///
  /// [hash] 音乐 hash，多个以逗号分隔；若已知云盘文件 ID，优先使用
  /// [fileids]（列表接口返回的 kv_id）和 [albumAudioIds]。
  Future<void> deleteCloudSongs(
      {String? hash, String? fileids, String? albumAudioIds}) async {
    final params = <String, dynamic>{};
    if (hash != null && hash.isNotEmpty) params['hash'] = hash;
    if (fileids != null && fileids.isNotEmpty) params['fileid'] = fileids;
    if (albumAudioIds != null && albumAudioIds.isNotEmpty) {
      params['album_audio_id'] = albumAudioIds;
    }
    await get('/user/cloud/del', params: params);
  }

  Future<List<Comment>> getMusicComments(int songId,
      {int page = 1, int pageSize = 200}) async {
    final res = await get('/comment/music', params: {
      'mixsongid': songId,
      'page': page,
      'pagesize': pageSize,
      'show_classify': 0,
      'show_hotword_list': 0,
      'sort': 2,
    });
    return _parseComments(res['data']);
  }

  /// 专辑评论（/comment/album，不需要登录）
  Future<List<Comment>> getAlbumComments(String albumId,
      {int page = 1, int pageSize = 30}) async {
    final res = await get('/comment/album',
        params: {'id': albumId, 'page': page, 'pagesize': pageSize});
    return _parseComments(res['data']);
  }

  /// 歌曲评论-根据分类返回（/comment/music/classify，不需要登录）
  ///
  /// [typeId] 分类 id（由 /comment/music 带 show_classify=1 返回）。
  /// [sort] 1 正序，2 倒序。
  Future<List<Comment>> getMusicCommentsByClassify(int mixsongid, int typeId,
      {int page = 1, int pageSize = 30, int? sort}) async {
    final params = <String, dynamic>{
      'mixsongid': mixsongid,
      'type_id': typeId,
      'page': page,
      'pagesize': pageSize,
    };
    if (sort != null) params['sort'] = sort;
    final res = await get('/comment/music/classify', params: params);
    return _parseComments(res['data']);
  }

  /// 歌曲评论-根据热词返回（/comment/music/hotword，不需要登录）
  Future<List<Comment>> getMusicCommentsByHotword(int mixsongid, String hotWord,
      {int page = 1, int pageSize = 30}) async {
    final res = await get('/comment/music/hotword', params: {
      'mixsongid': mixsongid,
      'hot_word': hotWord,
      'page': page,
      'pagesize': pageSize,
    });
    return _parseComments(res['data']);
  }

  /// 楼层评论（/comment/floor）
  ///
  /// [specialId] 评论下的 special_child_id 字段；[tid] 评论 id。
  Future<List<Comment>> getFloorComments(
      {required int specialId,
      required int mixsongid,
      required int tid,
      int page = 1,
      int pageSize = 30}) async {
    final res = await get('/comment/floor', params: {
      'special_id': specialId,
      'mixsongid': mixsongid,
      'tid': tid,
      'page': page,
      'pagesize': pageSize,
    });
    return _parseComments(res['data']);
  }

  /// 歌曲评论数（/comment/count，不需要登录）
  ///
  /// [hash] 音乐 hash；[specialId] 评论下的 special_child_id 字段。
  Future<int> getCommentCount({String? hash, int? specialId}) async {
    final params = <String, dynamic>{};
    if (hash != null && hash.isNotEmpty) params['hash'] = hash;
    if (specialId != null) params['special_id'] = specialId;
    final res = await get('/comment/count', params: params);
    return _parseCount(res['data']);
  }

  /// 歌曲收藏数（/favorite/count，不需要登录）
  ///
  /// [mixsongids] 音乐 mixsongid，多个以逗号分隔。
  /// 返回 mixsongid → 收藏数 的映射。
  Future<Map<int, int>> getFavoriteCount(String mixsongids) async {
    final res = await get('/favorite/count',
        params: {'mixsongids': mixsongids}, withAuth: false);
    final raw = res['data'];
    final result = <int, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id != null) result[id] = _parseCount(value);
      });
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final id =
              int.tryParse((item['mixsongid'] ?? item['id'] ?? '').toString());
          if (id != null) {
            result[id] = _parseCount(item['count'] ?? item['total']);
          }
        }
      }
    }
    return result;
  }

  /// 统一解析评论列表（兼容 data 为 List 或 Map 含 comments/list 的情况）
  List<Comment> _parseComments(dynamic raw) {
    List<dynamic>? list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      list = raw['comments'] as List<dynamic>? ??
          raw['list'] as List<dynamic>? ??
          raw['lists'] as List<dynamic>?;
    }
    if (list == null) return [];
    return list
        .whereType<Map>()
        .map((e) => Comment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 统一解析数字字段（兼容 int/字符串/Map 包装）
  int _parseCount(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    if (raw is Map) {
      final v = raw['count'] ?? raw['total'] ?? raw['num'];
      return _parseCount(v);
    }
    return 0;
  }

  Future<void> uploadPlayHistory(int songId, {int? duration}) async {
    // API 文档: mxid=专辑音乐id(MixSongID), ot=秒级时间戳, pc=播放次数
    final params = <String, dynamic>{'mxid': songId};
    if (duration != null && duration > 0) {
      params['ot'] = await _getServerTimestampSec();
      params['pc'] = 1;
    }
    await get('/playhistory/upload', params: params);
  }

  /// 获取服务端秒级时间戳，优先使用缓存（5 分钟 TTL），避免频繁请求
  Future<int> _getServerTimestampSec() async {
    final now = DateTime.now();
    // 缓存有效时直接用偏移量计算
    if (_serverTimeFetchedAt != null &&
        _serverTimeOffsetSec != null &&
        now.difference(_serverTimeFetchedAt!) < _serverTimeCacheTtl) {
      return now.millisecondsSinceEpoch ~/ 1000 + _serverTimeOffsetSec!;
    }
    try {
      final server = await getServerTime();
      if (server != null) {
        _serverTimeOffsetSec = server.millisecondsSinceEpoch ~/ 1000 -
            now.millisecondsSinceEpoch ~/ 1000;
        _serverTimeFetchedAt = now;
        return server.millisecondsSinceEpoch ~/ 1000;
      }
    } catch (_) {
      // 服务端时间获取失败，降级到本地时间
    }
    return now.millisecondsSinceEpoch ~/ 1000;
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
