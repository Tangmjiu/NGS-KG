class Song {
  final int id;
  final String name;
  final List<String> artists;
  final String? albumName;
  final String? albumCoverUrl;
  final int duration;
  final String? lyricUrl;
  final String? filePath;
  final String? hash;
  final Map<String, String>? qualities;

  const Song({
    required this.id,
    required this.name,
    required this.artists,
    this.albumName,
    this.albumCoverUrl,
    this.duration = 0,
    this.lyricUrl,
    this.filePath,
    this.hash,
    this.qualities,
  });

  bool get isLocal => filePath != null;

  String get artistDisplay => artists.join(' / ');

  static const qualityLabels = ['128K', '320K', 'FLAC'];
  static const qualityKeys = ['128', '320', 'flac'];

  String get currentQualityLabel {
    if (qualities != null && qualities!.containsKey('128')) return '128K';
    if (qualities != null && qualities!.containsKey('320')) return '320K';
    if (qualities != null && qualities!.containsKey('flac')) return 'FLAC';
    return hash != null && hash!.length > 20 ? '320K' : '128K';
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      artists: (json['artists'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      albumName: json['album']?['name'] as String?,
      albumCoverUrl: json['album']?['picUrl'] as String?,
      duration: json['duration'] as int? ?? 0,
      lyricUrl: json['lyricUrl'] as String?,
    );
  }

  factory Song.fromKugouJson(Map<String, dynamic> json) {
    var cover = json['Image'] as String?;
    if (cover != null) cover = cover.replaceAll('{size}', '480');
    return Song(
      id: (json['Audioid'] ?? json['id']) as int,
      name: (json['OriSongName'] ?? json['SongName'] ?? json['name'] ?? '') as String,
      artists: [(json['SingerName'] ?? '') as String],
      albumName: json['AlbumName'] as String?,
      albumCoverUrl: cover,
      duration: (json['Duration'] as int?) ?? 0,
    );
  }

  factory Song.fromTrackJson(Map<String, dynamic> json) {
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
        'flac': 'hash_flac',
        'high': 'hash_high',
        'super': 'hash_super',
      };
      for (final entry in fields.entries) {
        final v = audioInfo[entry.value] as String?;
        if (v != null && v.isNotEmpty) q[entry.key] = v;
      }
    }
    return Song(
      id: (json['audio_id'] ?? json['id']) as int,
      name: parts.length > 1 ? parts.sublist(1).join(' - ') : rawName,
      artists: parts.length > 1 ? [parts[0]] : ['未知'],
      albumCoverUrl: cover,
      duration: (json['timelen'] as int? ?? 0) ~/ 1000,
      hash: hash,
      qualities: q.isNotEmpty ? q : null,
    );
  }

  factory Song.fromRankJson(Map<String, dynamic> json) {
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
    }
    if (hash == null || hash!.isEmpty) {
      final deprecated = json['deprecated'];
      if (deprecated is Map) hash = deprecated['hash'] as String?;
    }
    return Song(
      id: (json['audio_id'] ?? json['album_audio_id'] ?? 0) as int,
      name: parts.length > 1 ? parts.sublist(1).join(' - ') : rawName,
      artists: [json['author_name'] as String? ?? ''],
      albumCoverUrl: cover,
      duration: _durationFromAudioInfo(json['audio_info']),
      hash: hash,
      qualities: q.isNotEmpty ? q : null,
    );
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

class SongUrl {
  final int id;
  final String url;
  final String type;

  const SongUrl({required this.id, required this.url, this.type = 'mp3'});

  factory SongUrl.fromJson(Map<String, dynamic> json) {
    final urls = json['url'];
    final firstUrl = urls is List
        ? (urls.isNotEmpty ? urls[0].toString() : '')
        : (urls as String? ?? '');
    return SongUrl(
      id: json['hash']?.hashCode ?? 0,
      url: firstUrl,
      type: json['extName'] as String? ?? 'mp3',
    );
  }
}
