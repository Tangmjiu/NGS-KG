/// Data classes for Subsonic API artist, album, and song responses.
///
/// These models parse the inner JSON object (artist/album/song dict),
/// not the full subsonic-response wrapper.
///
/// Null handling accounts for Subsonic quirks:
/// - The literal string `"<null>"` in place of JSON null
/// - Numeric fields occasionally returned as strings

/// Converts dynamic to int (Subsonic sometimes returns numbers as strings).
int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) {
    if (value == '<null>' || value.isEmpty) return null;
    return int.tryParse(value);
  }
  return null;
}

/// Subsonic sometimes returns the string `"<null>"` instead of a JSON null.
String? _nullIfPlaceholder(String? value) {
  if (value == null || value == '<null>' || value.isEmpty) return null;
  return value;
}

/// Subsonic artist as returned by the artists list and artist detail endpoints.
class SubsonicArtist {
  final String id;
  final String name;
  final String? coverArt;
  final int albumCount;
  final int songCount;

  const SubsonicArtist({
    required this.id,
    required this.name,
    this.coverArt,
    this.albumCount = 0,
    this.songCount = 0,
  });

  factory SubsonicArtist.fromJson(Map<String, dynamic> json) {
    return SubsonicArtist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      coverArt: _nullIfPlaceholder(json['coverArt'] as String?),
      albumCount: _toInt(json['albumCount']) ?? 0,
      songCount: _toInt(json['songCount']) ?? 0,
    );
  }
}

/// Subsonic album as returned by artist detail and album list endpoints.
class SubsonicAlbum {
  final String id;
  final String name;
  final String? artistId;
  final String? artist;
  final String? coverArt;
  final int songCount;
  final int duration;
  final int year;
  final String? genre;
  final int playCount;
  final int created;

  const SubsonicAlbum({
    required this.id,
    required this.name,
    this.artistId,
    this.artist,
    this.coverArt,
    this.songCount = 0,
    this.duration = 0,
    this.year = 0,
    this.genre,
    this.playCount = 0,
    this.created = 0,
  });

  factory SubsonicAlbum.fromJson(Map<String, dynamic> json) {
    return SubsonicAlbum(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? '',
      artistId: _nullIfPlaceholder(json['artistId'] as String?),
      artist: _nullIfPlaceholder(json['artist'] as String?),
      coverArt: _nullIfPlaceholder(json['coverArt'] as String?),
      songCount: _toInt(json['songCount']) ?? 0,
      duration: _toInt(json['duration']) ?? 0,
      year: _toInt(json['year']) ?? 0,
      genre: _nullIfPlaceholder(json['genre'] as String?),
      playCount: _toInt(json['playCount']) ?? 0,
      created: _toInt(json['created']) ?? 0,
    );
  }
}

/// Subsonic song (child/entry) as returned by album detail and playlist endpoints.
class SubsonicSong {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? coverArt;
  final String? albumId;
  final String? artistId;
  final String? suffix;
  final String? path;
  final String? contentType;
  final String? genre;
  final int duration;
  final int track;
  final int bitRate;
  final int size;
  final int year;

  const SubsonicSong({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.coverArt,
    this.albumId,
    this.artistId,
    this.suffix,
    this.path,
    this.contentType,
    this.genre,
    this.duration = 0,
    this.track = 0,
    this.bitRate = 0,
    this.size = 0,
    this.year = 0,
  });

  factory SubsonicSong.fromJson(Map<String, dynamic> json) {
    return SubsonicSong(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: _nullIfPlaceholder(json['artist'] as String?),
      album: _nullIfPlaceholder(json['album'] as String?),
      coverArt: _nullIfPlaceholder(json['coverArt'] as String?),
      albumId: _nullIfPlaceholder(json['albumId'] as String?),
      artistId: _nullIfPlaceholder(json['artistId'] as String?),
      suffix: _nullIfPlaceholder(json['suffix'] as String?),
      path: _nullIfPlaceholder(json['path'] as String?),
      contentType: _nullIfPlaceholder(json['contentType'] as String?),
      genre: _nullIfPlaceholder(json['genre'] as String?),
      duration: _toInt(json['duration']) ?? 0,
      track: _toInt(json['track']) ?? 0,
      bitRate: _toInt(json['bitRate']) ?? 0,
      size: _toInt(json['size']) ?? 0,
      year: _toInt(json['year']) ?? 0,
    );
  }
}
