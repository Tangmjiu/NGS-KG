import 'song.dart';

class CardSection {
  final String recDesc;
  final List<Song> songs;

  const CardSection({required this.recDesc, required this.songs});

  factory CardSection.fromJson(Map<String, dynamic> json) {
    final songList = json['song_list'] as List? ?? [];
    return CardSection(
      recDesc: json['rec_desc'] as String? ?? '',
      songs: songList.map((e) {
        final j = e as Map<String, dynamic>;
        var cover = j['sizable_cover'] as String?;
        if (cover != null) cover = cover.replaceAll('{size}', '240');
        return Song(
          id: j['songid'] as int? ?? 0,
          name: j['songname'] as String? ?? '',
          artists: [(j['author_name'] as String? ?? '')],
          albumName: j['album_name'] as String?,
          albumCoverUrl: cover,
          albumId: (j['album_id'] as int?) ?? 0,
          duration: ((j['time_length'] as num?)?.toInt() ?? 0) ~/ 1000,
          hash: j['hash'] as String?,
        );
      }).toList(),
    );
  }
}
