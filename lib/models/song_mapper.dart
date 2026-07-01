import '../utils/logger.dart';
import 'song.dart';

class SongMapper {
  /// Kugou-style search results: OriSongName, SingerName, FileHash, Audioid
  static Song? fromKugouJson(Map<String, dynamic> json) {
    try {
      var cover = json['Image'] as String?;
      if (cover != null) {
        cover = cover.replaceAll('{size}', '480');
        if (cover.startsWith('//')) cover = 'https:$cover';
      }
      final fileHash = json['FileHash'] as String?;
      return Song(
        id: _tryInt(json['Audioid'] ?? json['id']),
        name: (json['OriSongName'] ?? json['SongName'] ?? json['name'] ?? '') as String,
        artists: [(json['SingerName'] ?? '') as String],
        albumName: json['AlbumName'] as String?,
        albumCoverUrl: cover,
        albumId: _tryInt(json['AlbumID']),
        artistId: _tryInt(json['SingerID']),
        duration: (json['Duration'] as int?) ?? 0,
        hash: fileHash,
        qualities: fileHash != null && fileHash.isNotEmpty
            ? {'128': fileHash}
            : null,
      );
    } catch (e, s) {
      Log.e('song_mapper', 'error', e, s);
      return null;
    }
  }

  /// Track detail results: audio_info hash_128/320/flac/high, relate_goods
  ///
  /// 同时兼容两种响应格式：
  /// - 扁平格式（playlist/track/all）：{ name, hash, cover, audio_id, timelen, ... }
  /// - 嵌套格式（album/songs）：{ base: { audio_name, author_name, audio_id },
  ///     audio_info: { hash, duration_128 }, album_info: { cover }, trans_param: { union_cover } }
  static Song? fromTrackJson(Map<String, dynamic> json) {
    try {
      // ── 扁平名称（兼容 playlist） ──
      String? rawName = json['name'] as String?;

      // ── 嵌套格式（album/songs）：从 base 中提取名称和歌手 ──
      final base = json['base'] as Map<String, dynamic>?;
      final nestedName = base?['audio_name'] as String?;
      final nestedArtist = base?['author_name'] as String?;
      if (rawName == null || rawName.isEmpty) {
        if (nestedName != null && nestedName.isNotEmpty) {
          rawName = nestedArtist != null && nestedArtist.isNotEmpty
              ? '$nestedArtist - $nestedName'
              : nestedName;
        }
      }
      rawName ??= '';
      final parts = rawName!.split(' - ');

      // ── 封面：优先扁平字段，回退到 album_info / trans_param ──
      var cover = json['cover'] as String? ??
          json['album_cover'] as String? ??
          json['imgUrl'] as String? ??
          json['album_logo'] as String?;
      if (cover == null || cover.isEmpty) {
        final albumInfo = json['album_info'] as Map<String, dynamic>?;
        cover = albumInfo?['cover'] as String?;
      }
      if (cover == null || cover.isEmpty) {
        final transParam = json['trans_param'] as Map<String, dynamic>?;
        cover = transParam?['union_cover'] as String?;
      }
      if (cover != null) {
        cover = cover.replaceAll('{size}', '480');
        if (cover.startsWith('//')) cover = 'https:$cover';
      }

      // ── hash ──
      final q = <String, String>{};
      String? hash = json['hash'] as String?;
      // 扁平 hash 不存在时从 audio_info 取
      if (hash == null || hash.isEmpty) {
        final audioInfo = json['audio_info'] as Map<String, dynamic>?;
        hash = audioInfo?['hash'] as String? ?? audioInfo?['hash_128'] as String?;
      }
      if (hash != null && hash.isNotEmpty) q['128'] = hash;

      // ── 音质哈希（audio_info） ──
      final audioInfo = json['audio_info'];
      if (audioInfo is Map) {
        final fields = {
          '128': 'hash_128',
          '320': 'hash_320',
          'high': 'hash_high',
          'flac': 'hash_flac',
        };
        for (final entry in fields.entries) {
          final v = audioInfo[entry.value] as String?;
          if (v != null && v.isNotEmpty) q[entry.key] = v;
        }
        if (q.containsKey('flac') && !q.containsKey('high')) {
          q['high'] = q['flac']!;
        }
      }
      if (!q.containsKey('320')) {
        final relateGoods = json['relate_goods'];
        if (relateGoods is List) {
          for (final g in relateGoods) {
            if (g is Map) {
              final level = g['level'];
              final gh = g['hash'] as String?;
              if (gh != null && gh.isNotEmpty) {
                if (level == 4) { q['320'] = gh; }
                else if (level == 5) { q['flac'] = gh; }
                else if (!q.containsKey('128')) { q['128'] = gh; }
              }
            }
          }
        }
      }

      // ── 歌手 ──
      String artist;
      if (parts.length > 1) {
        artist = parts[0];
      } else {
        artist = json['singername'] as String?
            ?? json['artist'] as String?
            ?? json['author'] as String?
            ?? json['singer'] as String?
            ?? nestedArtist
            ?? '';
      }

      // ── 时长：优先扁平 timelen，回退到 audio_info.duration_128 ──
      int? timelen = json['timelen'] as int?;
      if (timelen == null || timelen <= 0) {
        final ai = json['audio_info'] as Map<String, dynamic>?;
        timelen = ai?['duration_128'] as int?;
      }
      timelen ??= 0;

      // ── album_id 回退到 base ──
      int? albumId = _tryInt(json['album_id']);
      if (albumId == 0 && base != null) {
        albumId = _tryInt(base['album_id']);
      }
      int? artistId = _tryInt(json['author_id']);
      if ((artistId == null || artistId == 0) && base != null) {
        artistId = _tryInt(base['author_id']);
      }

      return Song(
        id: _tryInt(json['audio_id'] ?? base?['audio_id'] ?? json['id']),
        name: parts.length > 1 ? parts.sublist(1).join(' - ') : rawName,
        artists: [artist],
        albumCoverUrl: cover,
        albumId: albumId,
        artistId: artistId,
        duration: timelen ~/ 1000,
        hash: hash,
        qualities: q.isNotEmpty ? q : null,
        fileId: _tryInt(json['fileid']),
      );
    } catch (e, s) {
      Log.e('song_mapper', 'error', e, s);
      return null;
    }
  }

  /// Ranking list entries: audio_info hash_128/320/flac/high, trans_param union_cover
  static Song? fromRankJson(Map<String, dynamic> json) {
    try {
      var cover = json['trans_param'] is Map
          ? (json['trans_param'] as Map)['union_cover'] as String?
          : null;
      if (cover != null) {
        cover = cover.replaceAll('{size}', '480');
        if (cover.startsWith('//')) cover = 'https:$cover';
      }
      final rawName = json['songname'] as String? ?? '';
      final parts = rawName.split(' - ');
      String? hash;
      final q = <String, String>{};
      final audioInfo = json['audio_info'];
      if (audioInfo is Map) {
        final v128 = audioInfo['hash_128'] as String?;
        if (v128 != null && v128.isNotEmpty) { q['128'] = v128; hash = v128; }
        final v320 = audioInfo['hash_320'] as String?;
        if (v320 != null && v320.isNotEmpty) q['320'] = v320;
        final vFlac = audioInfo['hash_flac'] as String?;
        if (vFlac != null && vFlac.isNotEmpty) q['flac'] = vFlac;
        final vHigh = audioInfo['hash_high'] as String?;
        if (vHigh != null && vHigh.isNotEmpty) q['high'] = vHigh;
      }
      if (hash == null || hash.isEmpty) {
        final deprecated = json['deprecated'];
        if (deprecated is Map) hash = deprecated['hash'] as String?;
      }
      return Song(
        id: _tryInt(json['audio_id'] ?? json['album_audio_id'] ?? 0),
        name: parts.length > 1 ? parts.sublist(1).join(' - ') : rawName,
        artists: [json['author_name'] as String? ?? ''],
        albumCoverUrl: cover,
        albumId: _tryInt(json['album_id']),
        artistId: _tryInt(json['author_id']),
        duration: _durationFromAudioInfo(json['audio_info']),
        hash: hash,
        qualities: q.isNotEmpty ? q : null,
      );
    } catch (e, s) {
      Log.e('song_mapper', 'error', e, s);
      return null;
    }
  }

  static int _tryInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }

  static int _durationFromAudioInfo(dynamic audioInfo) {
    if (audioInfo is Map) {
      final d = audioInfo['duration_128'];
      if (d is int) return d ~/ 1000;
      if (d is double) return (d / 1000).round();
    }
    return 0;
  }
}
