class LocalSong {
  final String title;
  final String? artist;
  final String? album;
  final String filePath;
  final int duration;
  final int size;
  final int? bitrate;    // kbps
  final int? sampleRate; // Hz
  final String? codec;   // e.g., mp3, flac, wav

  const LocalSong({
    required this.title,
    this.artist,
    this.album,
    required this.filePath,
    this.duration = 0,
    this.size = 0,
    this.bitrate,
    this.sampleRate,
    this.codec,
  });

  String get displayName {
    final name = title;
    if (name.endsWith('.mp3')) return name.substring(0, name.length - 4);
    return name;
  }
}
