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
        // 兼容标准版和概念版的不同字段名
        final rawName = (j['ori_audio_name'] ?? j['songname'] ?? j['name'] ?? '') as String;
        final rawArtist = (j['author_name'] ?? j['singer_name'] ?? j['singername'] ?? '') as String;
        var rawCover = (j['sizable_cover'] ?? j['cover'] ?? j['img'] ?? '') as String;
        if (rawCover.startsWith('//')) rawCover = 'https:$rawCover';
        final cover = rawCover.replaceAll('{size}', '240');
        final rawId = (j['mixsongid'] ?? j['audio_id'] ?? j['songid'] ?? j['id'] ?? 0);
        final rawAlbumId = (j['album_id'] ?? j['albumid'] ?? 0);
        final rawDuration = ((j['time_length'] ?? j['timelength'] ?? 0) as num).toInt();
        return Song(
          id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
          name: rawName,
          artists: [rawArtist],
          albumName: (j['album_name'] as String?) ?? (j['albumname'] as String?),
          albumCoverUrl: cover.isNotEmpty ? cover : null,
          albumId: rawAlbumId is int ? rawAlbumId : 0,
          duration: rawDuration > 1000 ? rawDuration ~/ 1000 : rawDuration,
          hash: (j['hash'] as String?) ?? (j['Hash'] as String?),
        );
      }).toList(),
    );
  }
}
