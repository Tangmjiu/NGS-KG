import 'base_repository.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/rank_entry.dart';
import '../models/scene_category.dart';
import '../models/song_mapper.dart';

class AlbumRepository extends BaseRepository {
  AlbumRepository(super.client);

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<Album?> getAlbumDetail(int albumId) async {
    final res = await get('/album/detail', params: {'id': albumId});
    final data = res['data'];
    if (data is Map) return Album.fromJson(Map<String, dynamic>.from(data));
    if (data is List && data.isNotEmpty) return Album.fromJson(Map<String, dynamic>.from(data[0] as Map));
    return null;
  }

  Future<List<Song>> getAlbumSongs(int albumId,
      {int page = 1, int pageSize = 200}) async {
    final res = await get('/album/songs', params: {
      'id': albumId,
      'page': page,
      'pagesize': pageSize,
    });
    final data = res['data'];
    List<dynamic>? list;
    if (data is Map) {
      list = data['songs'] as List<dynamic>? ?? data['info'] as List<dynamic>?;
    } else if (data is List) {
      list = data;
    }
    if (list == null) return [];
    return list.map((e) => _parseAlbumSong(e as Map<String, dynamic>, albumId)).toList();
  }

  Song _parseAlbumSong(Map<String, dynamic> json, int albumId) {
    final base = json['base'] as Map<String, dynamic>? ?? {};
    final audioInfo = json['audio_info'] as Map<String, dynamic>? ?? {};
    final q = <String, String>{};
    final h128 = audioInfo['hash_128'] as String?;
    final h320 = audioInfo['hash_320'] as String?;
    final hFlac = audioInfo['hash_flac'] as String?;
    final hHigh = audioInfo['hash_high'] as String?;
    if (h128 != null && h128.isNotEmpty) q['128'] = h128;
    if (h320 != null && h320.isNotEmpty) q['320'] = h320;
    if (hFlac != null && hFlac.isNotEmpty) q['flac'] = hFlac;
    if (hHigh != null && hHigh.isNotEmpty) q['high'] = hHigh;
    return Song(
      id: _toInt(base['audio_id'] ?? json['audio_id']),
      name: base['audio_name'] as String? ?? json['songname'] as String? ?? '',
      artists: [(base['author_name'] as String? ?? json['author_name'] as String? ?? '')],
      albumName: base['album_name'] as String? ?? json['album_name'] as String?,
      albumId: albumId,
      duration: (_toInt(audioInfo['duration'] ?? audioInfo['timelength']) ~/ 1000),
      hash: audioInfo['hash'] as String? ?? json['hash'] as String?,
      qualities: q.isNotEmpty ? q : null,
    );
  }

  Future<List<RankEntry>> getRankList() async {
    final res = await cachedGet('/rank/list', ttl: const Duration(minutes: 30));
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

  Future<List<Album>> getTopAlbums({int? type, int page = 1, int pageSize = 30}) async {
    final params = <String, dynamic>{'page': page, 'pagesize': pageSize};
    if (type != null) params['type'] = type;
    final res = await cachedGet('/top/album',
        params: params, ttl: const Duration(minutes: 15));
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => Album.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<SceneCategory>> getSceneLists() async {
    final res =
        await cachedGet('/scene/lists', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is List) {
      return raw
          .map((e) => SceneCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopIp() async {
    final res =
        await cachedGet('/top/ip', ttl: const Duration(minutes: 30));
    final raw = res['data'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
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
    final res = await get('/rank/audio', params: params);
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
