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
  final String? lyrics; // embedded LRC text (local files with companion .lrc)

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
    this.lyrics,
  });

  bool get isLocal => filePath != null;

  String get artistDisplay => artists.join(' / ');

  /// 播放音质列表（共 7 级，从低到高）
  static const qualityLabels = ['标准', 'HQ', 'SQ', 'Hi-Res', '全景声', '蝰蛇超清', '母带'];
  static const qualityKeys = ['128', '320', 'flac', 'high', 'viper_atmos', 'viper_clear', 'viper_tape'];
  static const Map<String, String> qualityLabelMap = {
    '128': '标准',
    '320': 'HQ',
    'flac': 'SQ',
    'high': 'Hi-Res',
    'viper_atmos': '全景声',
    'viper_clear': '蝰蛇超清',
    'viper_tape': '母带',
  };

  /// 根据 qualities 映射智能推断最高可用音质显示
  String get currentQualityLabel {
    for (final key in qualityKeys.reversed) {
      if (qualities != null && qualities!.containsKey(key)) {
        return qualityLabelMap[key] ?? key;
      }
    }
    return '标准';
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
  final String type; // 格式：mp3 / mp4 / flac
  final int? timeLength; // 时长（ms）
  final double? volume; // LUFS 响度值
  final double? volumeGain;
  final double? volumePeak;

  const SongUrl({
    required this.id,
    required this.url,
    this.type = 'mp3',
    this.timeLength,
    this.volume,
    this.volumeGain,
    this.volumePeak,
  });

  /// 是否为视频格式（Kugou 有时对 VIP 歌曲返回 mp4 而非音频）
  bool get isVideo => type == 'mp4';

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
      timeLength: json['timeLength'] as int?,
      volume: (json['volume'] as num?)?.toDouble(),
      volumeGain: (json['volume_gain'] as num?)?.toDouble(),
      volumePeak: (json['volume_peak'] as num?)?.toDouble(),
    );
  }
}
