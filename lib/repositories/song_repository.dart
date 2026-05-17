import '../services/api_client.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../models/card_section.dart';

class SongRepository {
  final ApiClient _client;

  SongRepository(this._client);

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

  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0, String type = 'song'}) async {
    final res = await _get('/search', params: {
      'keywords': keyword,
      'limit': limit,
      'offset': offset,
    });
    final data = res['data'] as Map<String, dynamic>?;
    if (data == null) return [];
    final list = data['songs'] as List<dynamic>? ?? data['lists'] as List<dynamic>? ?? [];
    return list
        .map((e) => SongMapper.fromKugouJson(e as Map<String, dynamic>))
        .whereType<Song>()
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

  Future<Map<String, dynamic>> searchLyricByHash(String hash, {String? keywords}) async {
    final params = <String, dynamic>{'hash': hash};
    if (keywords != null && keywords.isNotEmpty) {
      params['keywords'] = keywords;
    }
    return _get('/search/lyric', params: params);
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
          albumId: (json['album_id'] as int?) ?? 0,
          duration: ((json['timelength'] as num?)?.toInt() ?? 0) ~/ 1000,
          hash: json['hash'] as String?,
        );
      }).toList();
    }
    return [];
  }

  Future<CardSection> getCardSongs(int cardId) async {
    final res = await _get('/top/card', params: {'card_id': cardId});
    final raw = res['data'];
    if (raw is Map) {
      return CardSection.fromJson(raw as Map<String, dynamic>);
    }
    return const CardSection(recDesc: '', songs: []);
  }
}
