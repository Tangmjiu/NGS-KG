import '../services/api_exception.dart';
import 'song_mapper.dart';

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
  final Map<String, String>? qualities;
  final int albumId;
  final int? fileId;

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
    this.qualities,
    this.albumId = 0,
    this.fileId,
  });

  bool get isLocal => filePath != null;

  String get artistDisplay => artists.join(' / ');

  static const qualityLabels = ['标准', 'HQ', '无损'];
  static const qualityKeys = ['128', '320', 'high'];

  String get currentQualityLabel {
    if (qualities != null && qualities!.containsKey('128')) return '标准';
    if (qualities != null && qualities!.containsKey('320')) return 'HQ';
    if (qualities != null && (qualities!.containsKey('high') || qualities!.containsKey('flac'))) return '无损';
    return hash != null && hash!.length > 20 ? 'HQ' : '标准';
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    final album = json['album'] as Map<String, dynamic>?;
    return Song(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      artists: (json['artists'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      albumName: album?['name'] as String?,
      albumCoverUrl: album?['picUrl'] as String?,
      albumId: album?['id'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      lyricUrl: json['lyricUrl'] as String?,
    );
  }

  @Deprecated('Use SongMapper.fromKugouJson instead')
  factory Song.fromKugouJson(Map<String, dynamic> json) =>
      SongMapper.fromKugouJson(json)!;

  @Deprecated('Use SongMapper.fromTrackJson instead')
  factory Song.fromTrackJson(Map<String, dynamic> json) =>
      SongMapper.fromTrackJson(json)!;

  @Deprecated('Use SongMapper.fromRankJson instead')
  factory Song.fromRankJson(Map<String, dynamic> json) =>
      SongMapper.fromRankJson(json)!;
}

class SongUrl {
  final int id;
  final String url;
  final String type;

  const SongUrl({required this.id, required this.url, this.type = 'mp3'});

  factory SongUrl.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    if (status == 3 || status == '3') {
      throw const NoCopyrightException();
    }
    final urls = json['url'];
    final firstUrl = urls is List
        ? (urls.isNotEmpty ? urls[0].toString() : '')
        : (urls as String? ?? '');
    return SongUrl(
      id: json['hash']?.hashCode ?? 0,
      url: firstUrl,
      type: json['extName'] as String? ?? 'mp3',
    );
  }
}
