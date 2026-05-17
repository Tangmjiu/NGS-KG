class Album {
  final int id;
  final String name;
  final String? coverUrl;
  final String? artistName;
  final int? artistId;
  final int? songCount;
  final String? description;

  const Album({
    required this.id,
    required this.name,
    this.coverUrl,
    this.artistName,
    this.artistId,
    this.songCount,
    this.description,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: _toInt(json['albumid'] ?? json['id'] ?? 0),
      name: (json['albumname'] ?? json['name'] ?? '') as String,
      coverUrl: json['imgurl'] as String? ?? json['coverImgUrl'] as String?,
      artistName: json['singername'] as String? ?? json['artist'] as String?,
      artistId: _toInt(json['album_artist_id']),
      songCount: _toInt(json['song_count'] ?? json['songcount']),
      description: json['intro'] as String?,
    );
  }

  factory Album.fromSearchJson(Map<String, dynamic> json) {
    return Album(
      id: _toInt(json['albumid'] ?? json['id'] ?? 0),
      name: (json['albumname'] ?? json['name'] ?? '') as String,
      coverUrl: json['imgurl'] as String? ?? json['img'] as String?,
      artistName: json['singername'] as String? ?? json['artist'] as String?,
      artistId: _toInt(json['album_artist_id']),
      songCount: _toInt(json['song_count']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }
}
