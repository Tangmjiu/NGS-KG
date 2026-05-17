import '../services/api_client.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/rank_entry.dart';
import '../models/song_mapper.dart';

class AlbumRepository {
  final ApiClient _client;

  AlbumRepository(this._client);

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

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<Album?> getAlbumDetail(int albumId) async {
    final res = await _get('/album/detail', params: {'id': albumId});
    final data = res['data'] as Map<String, dynamic>?;
    if (data != null) return Album.fromJson(data);
    return null;
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
            id: _toInt(base['audio_id']),
            name: base['audio_name'] as String? ?? '',
            artists: [(base['author_name'] as String? ?? '')],
            albumName: null,
            albumId: albumId,
            duration: (_toInt(audioInfo['duration']) ~/ 1000),
            hash: audioInfo['hash'] as String?,
            qualities: q.isNotEmpty ? q : null,
          );
        }).toList();
      }
    }
    return [];
  }

  Future<List<RankEntry>> getRankList() async {
    final res = await _cachedGet('/rank/list', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is Map) {
      final info = raw['info'] as List<dynamic>?;
      if (info != null) {
        return info
            .map((e) => RankEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    if (raw is List) {
      return raw
          .map((e) => RankEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
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
            .map((e) => SongMapper.fromRankJson(e as Map<String, dynamic>))
            .whereType<Song>()
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
            albumId: (json['album_id'] as int?) ?? 0,
            duration: ((json['timelength'] as int?) ?? 0) ~/ 1000,
            hash: json['hash'] as String?,
          );
        }).toList();
      }
    }
    return [];
  }
}
