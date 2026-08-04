import 'song.dart';
import 'song_mapper.dart';

class Playlist {
  final int id;
  final String name;
  final String? coverUrl;
  final String? description;
  final int trackCount;
  final List<Song>? songs;
  final String? globalCollectionId;
  final int? createUserId;

  const Playlist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.description,
    this.trackCount = 0,
    this.songs,
    this.globalCollectionId,
    this.createUserId,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: _toInt(json['specialid'] ?? json['id'] ?? json['listid'] ?? 0),
      name: (json['specialname'] ?? json['name'] ?? '') as String? ?? '',
      coverUrl: _fixCover(json['imgurl'] as String? ??
          json['coverImgUrl'] as String? ??
          json['pic'] as String?),
      description: json['intro'] as String? ?? json['description'] as String?,
      trackCount:
          _toInt(json['songcount'] ?? json['trackCount'] ?? json['count'] ?? 0),
      globalCollectionId: json['global_collection_id'] as String? ??
          json['parent_global_collection_id'] as String?,
      createUserId: _toInt(json['list_create_userid'] ??
                  json['create_userid'] ??
                  json['suid'] ??
                  0) !=
              0
          ? _toInt(json['list_create_userid'] ??
              json['create_userid'] ??
              json['suid'] ??
              0)
          : null,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static String? _fixCover(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.contains('{size}')) {
      return url.replaceAll(RegExp(r'\{size\}'), '480');
    }
    if (!url.startsWith('http')) {
      return 'https:$url';
    }
    return url;
  }
}

class PlaylistDetail {
  final Playlist playlist;
  final List<Song> songs;

  const PlaylistDetail({required this.playlist, required this.songs});

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) {
    final pl = Playlist.fromJson(json);
    List<Song> songList = [];
    final songsData = json['songs'] ?? json['info'] ?? json['list'];
    if (songsData is List) {
      songList = songsData
          .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
          .whereType<Song>()
          .toList();
    }
    return PlaylistDetail(playlist: pl, songs: songList);
  }

  factory PlaylistDetail.fromKugouJson(Map<String, dynamic> json) {
    final pl = Playlist.fromJson(json);
    List<Song> songList = [];
    final songsData = json['lists'] ??
        json['songs'] ??
        json['info'] ??
        json['list'] ??
        json['plist'];
    if (songsData is List) {
      songList = songsData
          .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
          .whereType<Song>()
          .toList();
    }
    return PlaylistDetail(playlist: pl, songs: songList);
  }
}
