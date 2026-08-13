class LocalSong {
  final String title;
  final String? artist;
  final String? album;
  final String filePath;
  final int? mediaStoreId;  // Android MediaStore _ID from on_audio_query
  final int duration;
  final int size;
  final int? bitrate;    // kbps
  final int? sampleRate; // Hz
  final String? codec;   // e.g., mp3, flac, wav
  final String? lyrics;  // raw LRC text from companion .lrc or metadata
  final String? albumCoverPath; // extracted cover art cache path

  const LocalSong({
    required this.title,
    this.artist,
    this.album,
    required this.filePath,
    this.mediaStoreId,
    this.duration = 0,
    this.size = 0,
    this.bitrate,
    this.sampleRate,
    this.codec,
    this.lyrics,
    this.albumCoverPath,
  });

  String get displayName {
    final name = title;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    final ext = name.substring(dot + 1).toLowerCase();
    if (_audioExtensions.contains(ext)) {
      return name.substring(0, dot);
    }
    return name;
  }

  /// 已知音频扩展名（小写）
  static const _audioExtensions = {
    'mp3', 'flac', 'wav', 'aac', 'ogg', 'wma', 'm4a', 'opus',
    'ape', 'dsd', 'dff', 'aiff', 'alac', 'mka', 'tta', 'amr',
  };
}
