import 'song.dart';

class Playlist {
  final int id;
  final String name;
  final String? coverUrl;
  final String? description;
  final int trackCount;
  final List<Song>? songs;

  const Playlist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.description,
    this.trackCount = 0,
    this.songs,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      coverUrl: json['coverImgUrl'] as String?,
      description: json['description'] as String?,
      trackCount: json['trackCount'] as int? ?? 0,
    );
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
}
