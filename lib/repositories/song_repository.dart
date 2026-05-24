import 'base_repository.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../models/card_section.dart';

class SongRepository extends BaseRepository {
  SongRepository(super.client);

  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0, String type = 'song'}) async {
    final res = await get('/search', params: {
      'keywords': keyword,
      'page': (offset ~/ limit) + 1,
      'pagesize': limit,
      'type': type,
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
      params['id'] = songId;
    }
    if (quality != null) {
      params['quality'] = quality;
    }
    final res = await get('/song/url', params: params);
    return SongUrl.fromJson(res);
  }

  Future<Map<String, dynamic>> getLyric(int songId) async {
    return get('/lyric', params: {'id': songId});
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
}
