import 'song.dart';

class Playlist {
  final int id;
  final String name;
  final String? coverUrl;
  final String? description;
  final int trackCount;
  final List<Song>? songs;
  final String? globalCollectionId;

  const Playlist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.description,
    this.trackCount = 0,
    this.songs,
    this.globalCollectionId,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: (json['specialid'] ?? json['id']) as int,
      name: (json['specialname'] ?? json['name']) as String? ?? '',
      coverUrl: _fixCover(json['imgurl'] as String? ?? json['coverImgUrl'] as String?),
      description: json['intro'] as String? ?? json['description'] as String?,
      trackCount: json['songcount'] as int? ?? json['trackCount'] as int? ?? 0,
      globalCollectionId: json['global_collection_id'] as String?,
    );
  }

  static String? _fixCover(String? url) {
    if (url == null) return null;
    return url.replaceAll(RegExp(r'\{size\}'), '480');
  }
}

class PlaylistDetail {
  final Playlist playlist;
  final List<Song> songs;

  const PlaylistDetail({required this.playlist, required this.songs});

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) {
    final pl = Playlist.fromJson(json['playlist'] as Map<String, dynamic>);
    final songList = (json['songs'] as List<dynamic>?)
            ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PlaylistDetail(playlist: pl, songs: songList);
  }

  factory PlaylistDetail.fromKugouJson(Map<String, dynamic> json) {
    final pl = Playlist.fromJson(json);
    final songList = (json['songs'] as List<dynamic>?)
            ?.map((e) => Song.fromTrackJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PlaylistDetail(playlist: pl, songs: songList);
  }
}
