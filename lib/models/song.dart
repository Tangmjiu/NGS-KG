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
  });

  bool get isLocal => filePath != null;

  String get artistDisplay => artists.join(' / ');

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
    return Song(
      id: (json['audio_id'] ?? json['id']) as int,
      name: parts.length > 1 ? parts.sublist(1).join(' - ') : rawName,
      artists: parts.length > 1 ? [parts[0]] : ['未知'],
      albumCoverUrl: cover,
      duration: (json['timelen'] as int? ?? 0) ~/ 1000,
      hash: json['hash'] as String?,
    );
  }
}

class SongUrl {
  final int id;
  final String url;
  final String type;

  const SongUrl({required this.id, required this.url, this.type = 'mp3'});

  factory SongUrl.fromJson(Map<String, dynamic> json) {
    return SongUrl(
      id: json['id'] as int,
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? 'mp3',
    );
  }
}
