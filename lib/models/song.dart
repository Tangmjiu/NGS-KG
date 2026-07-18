import 'dart:io';

import 'package:flutter/painting.dart';

import 'dart:typed_data';

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
  final int? climaxMs; // 歌曲高潮开始时间（毫秒），来自 /song/climax
  final int? mixSongId; // 酷狗 MixSongID，用于播放历史上传等场景
  final int? artistId;  // 歌手 ID，用于导航到歌手详情
  final Uint8List? coverData; // 内嵌封面原始数据（本地音乐用）
  // ─── 本地音乐扩展字段 ───
  final int? mediaStoreId; // Android MediaStore _ID
  final int size;          // 文件大小（字节）
  final int? bitrate;      // kbps
  final String? codec;     // MP3 / FLAC / WAV / AAC / OGG / WMA
  // ─── 私人 FM 扩展字段 ───
  final String? recDesc;        // FM 推荐理由（如"根据您喜欢的华语流行"）
  final String? language;       // 语言标签（CN/EN/JP/KR）
  final String? similarDesc;    // 相似推荐说明（如"和您收藏的XX相似"）
  final List<Map<String, dynamic>>? relateGoods; // 音质层级数据

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
    this.climaxMs,
    this.mixSongId,
    this.artistId,
    this.coverData,
    this.mediaStoreId,
    this.size = 0,
    this.bitrate,
    this.codec,
    this.recDesc,
    this.language,
    this.similarDesc,
    this.relateGoods,
  });

  bool get isLocal => filePath != null;

  String get artistDisplay => artists.join(' / ');

  ImageProvider get coverImageProvider {
    if (coverData != null && coverData!.isNotEmpty) {
      return MemoryImage(coverData!);
    }
    if (albumCoverUrl == null || albumCoverUrl!.isEmpty) {
      return const AssetImage('assets/images/icon.png');
    }
    final url = albumCoverUrl!;
    if (url.startsWith('file://') || _isRawFilePath(url)) {
      final path = url.startsWith('file://')
          ? Uri.parse(url).toFilePath()
          : url;
      return FileImage(File(path));
    }
    return NetworkImage(url);
  }

  /// 判断裸文件系统路径（无 scheme）。
  static bool _isRawFilePath(String path) {
    if (path.length >= 3 && RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path)) {
      return true;
    }
    if (path.startsWith('/')) return true;
    if (path.startsWith('./') || path.startsWith('.\\')) return true;
    return false;
  }

  /// 播放编码音质列表（4 级，从低到高）
  /// 音效（viper_atmos/viper_clear/viper_tape）已独立到 Quality.effects
  static const qualityLabels = ['标准', 'HQ', 'SQ', 'Hi-Res'];
  static const qualityKeys = ['128', '320', 'flac', 'high'];
  static const Map<String, String> qualityLabelMap = {
    '128': '标准',
    '320': 'HQ',
    'flac': 'SQ',
    'high': 'Hi-Res',
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

  /// 从本地音频文件创建 Song 对象。
  ///
  /// ID 使用负数空间（-(mediaStoreId ?? filePath.hashCode)），
  /// 避免与在线歌曲正数 ID 冲突。
  factory Song.fromLocal({
    required String title,
    String? artist,
    String? album,
    required String filePath,
    int? mediaStoreId,
    int duration = 0,
    int size = 0,
    int? bitrate,
    String? codec,
    String? lyrics,
    String? albumCoverPath,
  }) {
    final coverUrl = albumCoverPath != null
        ? Uri.file(albumCoverPath).toString()
        : null;
    // 根据 codec/bitrate 构建品质映射
    final qualities = <String, String>{};
    if (codec == 'FLAC' || codec == 'WAV') {
      qualities['flac'] = filePath;
    } else if (bitrate != null && bitrate >= 320) {
      qualities['320'] = filePath;
    } else {
      qualities['128'] = filePath;
    }
    return Song(
      id: -(mediaStoreId ?? filePath.hashCode),
      name: title.endsWith('.mp3') ? title.substring(0, title.length - 4) : title,
      artists: artist != null ? [artist] : ['本地音乐'],
      albumName: album,
      albumCoverUrl: coverUrl,
      filePath: filePath,
      duration: duration,
      mediaStoreId: mediaStoreId,
      size: size,
      bitrate: bitrate,
      codec: codec,
      lyrics: lyrics,
      qualities: qualities,
    );
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
      id: (json['mixsongid'] as int?) ?? (json['audio_id'] as int?) ?? (json['id'] as int?) ?? json['hash']?.hashCode ?? 0,
      url: firstUrl,
      type: json['extName'] as String? ?? 'mp3',
      timeLength: json['timeLength'] as int?,
      volume: (json['volume'] as num?)?.toDouble(),
      volumeGain: (json['volume_gain'] as num?)?.toDouble(),
      volumePeak: (json['volume_peak'] as num?)?.toDouble(),
    );
  }
}
