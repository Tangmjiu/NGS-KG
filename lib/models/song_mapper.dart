import 'song.dart';

class SongMapper {
  /// Kugou-style search results: OriSongName, SingerName, FileHash, Audioid
  static Song? fromKugouJson(Map<String, dynamic> json) {
    try {
      var cover = json['Image'] as String?;
      if (cover != null) cover = cover.replaceAll('{size}', '480');
      return Song(
        id: (json['Audioid'] ?? json['id']) as int,
        name: (json['OriSongName'] ?? json['SongName'] ?? json['name'] ?? '') as String,
        artists: [(json['SingerName'] ?? '') as String],
        albumName: json['AlbumName'] as String?,
        albumCoverUrl: cover,
        albumId: _tryInt(json['AlbumID']),
        duration: (json['Duration'] as int?) ?? 0,
        hash: json['FileHash'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Track detail results: audio_info hash_128/320/flac/high, relate_goods
  static Song? fromTrackJson(Map<String, dynamic> json) {
    try {
      final rawName = (json['name'] as String?) ?? '';
      final parts = rawName.split(' - ');
      var cover = json['cover'] as String?;
      if (cover != null) cover = cover.replaceAll('{size}', '480');
      final q = <String, String>{};
      final hash = json['hash'] as String?;
      if (hash != null && hash.isNotEmpty) q['128'] = hash;
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
                if (level == 4) q['320'] = gh;
                else if (level == 5) q['flac'] = gh;
                else if (!q.containsKey('128')) q['128'] = gh;
              }
            }
          }
        }
      }
      String artist;
      if (parts.length > 1) {
        artist = parts[0];
      } else {
        artist = json['singername'] as String?
            ?? json['artist'] as String?
            ?? json['author'] as String?
            ?? json['singer'] as String?
            ?? '';
      }
      return Song(
        id: (json['audio_id'] ?? json['id']) as int,
        name: parts.length > 1 ? parts.sublist(1).join(' - ') : rawName,
        artists: [artist],
        albumCoverUrl: cover,
        albumId: _tryInt(json['album_id']),
        duration: (json['timelen'] as int? ?? 0) ~/ 1000,
        hash: hash,
        qualities: q.isNotEmpty ? q : null,
        fileId: _tryInt(json['fileid']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Ranking list entries: audio_info hash_128/320/flac/high, trans_param union_cover
  static Song? fromRankJson(Map<String, dynamic> json) {
    try {
      var cover = json['trans_param'] is Map
          ? (json['trans_param'] as Map)['union_cover'] as String?
          : null;
      if (cover != null) cover = cover.replaceAll('{size}', '480');
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
        id: (json['audio_id'] ?? json['album_audio_id'] ?? 0) as int,
        name: parts.length > 1 ? parts.sublist(1).join(' - ') : rawName,
        artists: [json['author_name'] as String? ?? ''],
        albumCoverUrl: cover,
        albumId: _tryInt(json['album_id']),
        duration: _durationFromAudioInfo(json['audio_info']),
        hash: hash,
        qualities: q.isNotEmpty ? q : null,
      );
    } catch (_) {
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
