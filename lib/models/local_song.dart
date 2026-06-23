import 'dart:typed_data';

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
  final String? lyrics;  // raw LRC text from companion .lrc or metadata
  final String? albumCoverPath; // extracted cover art cache path
  final Uint8List? albumCoverData; // raw cover art bytes (fallback if cache missing)

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
    this.lyrics,
    this.albumCoverPath,
    this.albumCoverData,
  });

  String get displayName {
    final name = title;
    if (name.endsWith('.mp3')) return name.substring(0, name.length - 4);
    return name;
  }
}
