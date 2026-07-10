import 'dart:convert';
import 'dart:typed_data';
import 'base_repository.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../models/card_section.dart';

class SongRepository extends BaseRepository {
  SongRepository(super.client);

  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0, String type = 'song'}) async {
    final params = <String, dynamic>{
      'keywords': keyword,
      'page': (offset ~/ limit) + 1,
      'pagesize': limit,
      'type': type,
    };
    // 搜索接口需要 cookie 作为查询参数
    final cookie = await _getCookieString();
    if (cookie != null) params['cookie'] = cookie;
    final res = await get('/search', params: params);
    final data = res['data'] as Map<String, dynamic>?;
    if (data == null) return [];
    final list = data['songs'] as List<dynamic>? ?? data['lists'] as List<dynamic>? ?? [];
    return list
        .map((e) => SongMapper.fromKugouJson(e as Map<String, dynamic>))
        .whereType<Song>()
        .toList();
  }

  Future<List<String>> getSearchSuggest(String keyword) async {
    final res = await get('/search/suggest', params: {'keywords': keyword});
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
    final res = await cachedGet('/search/hot', ttl: const Duration(minutes: 30));
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
      // hash 不可用时传入 id 作为保底（部分服务器接受此参数）
      params['id'] = songId;
    }
    if (quality != null) {
      params['quality'] = quality;
    }
    // /song/url 需要 cookie 查询参数（含 dfid/token/userid），否则返回 20028
    // ref: https://github.com/MakcRe/KuGouMusicApi/issues/142
    final cookie = await _getCookieString();
    if (cookie != null) params['cookie'] = cookie;
    final res = await get('/song/url', params: params);
    return SongUrl.fromJson(res);
  }

  /// 获取歌曲的音质特权信息（/privilege/lite）
  ///
  /// 返回该歌曲在 Kugou 服务器上实际可用的音质变体列表。
  /// 配合 [getSongUrl] 的 quality 参数使用，可实现智能降级。
  Future<Map<String, dynamic>> getPrivilegeLite(String hash) async {
    return get('/privilege/lite', params: {'hash': hash});
  }

  Future<Map<String, dynamic>> searchLyricByHash(String hash, {String? keywords}) async {
    final params = <String, dynamic>{'hash': hash};
    if (keywords != null && keywords.isNotEmpty) {
      params['keywords'] = keywords;
    }
    return get('/search/lyric', params: params);
  }

  Future<String> fetchLyricContent(int lyricId, String accessKey) async {
    final res = await get('/lyric', params: {
      'id': lyricId,
      'accesskey': accessKey,
      'fmt': 'lrc',
      'decode': 'true',
    });
    return res['content'] as String? ?? '';
  }

  /// 获取 KRC 格式歌词（包含翻译信息）
  ///
  /// 返回原始 KRC 加密二进制数据，需用 ym_lyric 的 KrcLyricUtil 解析。
  Future<Uint8List> fetchKrcContent(int lyricId, String accessKey) async {
    final res = await get('/lyric', params: {
      'id': lyricId,
      'accesskey': accessKey,
      'fmt': 'krc',
    });
    final content = res['content'] as String?;
    if (content == null || content.isEmpty) return Uint8List(0);
    try {
      return base64Decode(content);
    } catch (_) {
      return Uint8List(0);
    }
  }

  Future<List<Song>> getTopSongs() async {
    final res = await get('/top/song');
    final raw = res['data'];
    if (raw is List) {
      return raw.map((e) {
        final json = e as Map<String, dynamic>;
        var cover = json['album_sizable_cover'] as String?;
        if (cover != null) {
          cover = cover.replaceAll('{size}', '240');
          if (cover.startsWith('//')) cover = 'https:$cover';
        }
        return Song(
          id: json['audio_id'] as int? ?? 0,
          name: json['songname'] as String? ?? '',
          artists: [(json['author_name'] as String? ?? '')],
          albumName: json['album_name'] as String?,
          albumCoverUrl: cover,
          albumId: (json['album_id'] as int?) ?? 0,
          duration: ((json['timelength'] as num?)?.toInt() ?? 0) ~/ 1000,
          hash: json['hash'] as String?,
        );
      }).toList();
    }
    return [];
  }

  Future<CardSection> getCardSongs(int cardId) async {
    final res = await get('/top/card', params: {'card_id': cardId});
    final raw = res['data'];
    if (raw is Map) {
      return CardSection.fromJson(raw as Map<String, dynamic>);
    }
    return const CardSection(recDesc: '', songs: []);
  }

  /// 新版推荐卡片（青年版卡片）
  Future<CardSection> getCardSongsYouth(int cardId, {int? pagesize}) async {
    final params = <String, dynamic>{'card_id': cardId};
    if (pagesize != null) params['pagesize'] = pagesize;
    final res = await get('/top/card/youth', params: params);
    final raw = res['data'];
    if (raw is Map) {
      return CardSection.fromJson(raw as Map<String, dynamic>);
    }
    return const CardSection(recDesc: '', songs: []);
  }

  /// 每日推荐歌曲（对应 MoeKoeMusic /everyday/recommend）
  ///
  /// 返回 data.song_list，每项含 hash/ori_audio_name/sizable_cover/author_name/time_length
  Future<List<Song>> getDailyRecommend() async {
    final res = await get('/everyday/recommend', params: {'platform': 'android'});
    final data = res['data'] as Map<String, dynamic>?;
    if (data == null) return [];
    final list = data['song_list'] as List<dynamic>? ?? [];
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      var cover = json['sizable_cover'] as String?;
      if (cover != null) {
        cover = cover.replaceAll('{size}', '240');
        if (cover.startsWith('//')) cover = 'https:$cover';
      }
      final timelength = (json['time_length'] as num?)?.toInt() ?? 0;
      return Song(
        id: (json['mixsongid'] as int?) ?? (json['audio_id'] as int?) ?? (json['id'] as int?) ?? 0,
        mixSongId: (json['mixsongid'] as int?),
        name: json['ori_audio_name'] as String? ?? '',
        artists: [(json['author_name'] as String? ?? '')],
        albumCoverUrl: cover,
        duration: timelength > 1000 ? timelength ~/ 1000 : timelength,
        hash: json['hash'] as String?,
      );
    }).toList();
  }

  /// KRM 音频（知识/版权保护音频格式）
  Future<Map<String, dynamic>?> getKrmAudio(int albumAudioId) async {
    try {
      return await get('/krm/audio', params: {'album_audio_id': albumAudioId});
    } catch (_) {
      return null;
    }
  }

  /// 综合搜索（对应 MoeKoeMusic /search/complex）
  ///
  /// 一次请求返回多类型混合结果（歌曲/歌手/专辑/歌单/MV）
  /// 返回原始 data Map 供上层按需解析
  Future<Map<String, dynamic>> searchComplex(String keyword) async {
    final params = <String, dynamic>{'keywords': keyword};
    final cookie = await _getCookieString();
    if (cookie != null) params['cookie'] = cookie;
    final res = await get('/search/complex', params: params);
    final data = res['data'];
    if (data is Map<String, dynamic>) return data;
    final lists = res['lists'] as Map<String, dynamic>?;
    if (lists != null) return {'lists': lists};
    return <String, dynamic>{};
  }

  /// 获取 cookie 字符串用于搜索接口查询参数
  Future<String?> _getCookieString() async {
    try {
      return await client.getCookieString();
    } catch (_) {
      return null;
    }
  }

  /// 获取歌曲高潮开始时间（/song/climax）
  ///
  /// 返回毫秒级时间戳，若接口返回空或异常则返回 null。
  Future<int?> getSongClimax(String hash) async {
    try {
      final res = await get('/song/climax', params: {'hash': hash});
      final data = res['data'];
      if (data is Map) {
        final list = data['list'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final first = list.first as Map?;
          if (first != null) {
            final begin = first['begin'] as num?;
            if (begin != null) return (begin * 1000).toInt();
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
