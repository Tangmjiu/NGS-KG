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
    String? parseCover(dynamic url) {
      if (url == null) return null;
      final s = url.toString();
      if (s.isEmpty) return null;
      if (s.contains('{size}')) return s.replaceAll(RegExp(r'\{size\}'), '500');
      if (!s.startsWith('http')) return 'https:$s';
      return s;
    }
    return Album(
      id: _toInt(json['album_id'] ?? json['albumid'] ?? json['id'] ?? 0),
      name: (json['album_name'] ?? json['albumname'] ?? json['name'] ?? '') as String,
      coverUrl: parseCover(json['sizable_cover'] ?? json['imgurl'] ?? json['coverImgUrl'] ?? json['cover']),
      artistName: json['author_name'] ?? json['singername'] ?? json['artist'] as String?,
      artistId: _toInt(json['album_artist_id'] ?? json['artist_id']),
      songCount: _toInt(json['song_count'] ?? json['songcount']),
      description: json['intro'] as String?,
    );
  }

  factory Album.fromSearchJson(Map<String, dynamic> json) {
    String? parseCover(dynamic url) {
      if (url == null) return null;
      final s = url.toString();
      if (s.isEmpty) return null;
      if (s.contains('{size}')) return s.replaceAll(RegExp(r'\{size\}'), '500');
      if (!s.startsWith('http')) return 'https:$s';
      return s;
    }
    return Album(
      id: _toInt(json['albumid'] ?? json['id'] ?? 0),
      name: (json['albumname'] ?? json['name'] ?? '') as String,
      coverUrl: parseCover(json['sizable_cover'] ?? json['imgurl'] ?? json['img'] ?? json['cover']),
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
