class Song {
  final int id;
  final String name;
  final List<String> artists;
  final String? albumName;
  final String? albumCoverUrl;
  final int duration;
  final String? lyricUrl;
  final String? filePath;

  const Song({
    required this.id,
    required this.name,
    required this.artists,
    this.albumName,
    this.albumCoverUrl,
    this.duration = 0,
    this.lyricUrl,
    this.filePath,
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
