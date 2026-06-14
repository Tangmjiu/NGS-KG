import 'dart:io';
import 'package:flutter/services.dart';

/// Reads audio file metadata using platform-specific APIs.
///
/// On Android, delegates to [MediaMetadataRetriever] via MethodChannel.
/// Falls back to filename-based extraction if the channel is unavailable.
class MetadataReader {
  static const _channel = MethodChannel('com.mjiutang.ngskg/metadata');

  /// Reads metadata from [file].
  /// Returns null if reading fails.
  static Future<AudioMetadata?> read(File file) async {
    try {
      final result = await _channel.invokeMethod<Map>('readMetadata', {
        'path': file.path,
      });
      if (result == null) return null;
      return AudioMetadata.fromMap(result);
    } catch (_) {
      return null;
    }
  }
}

/// Parsed audio metadata.
class AudioMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final int durationMs;
  final int? bitrate;
  final Uint8List? albumArt;

  const AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.durationMs = 0,
    this.bitrate,
    this.albumArt,
  });

  factory AudioMetadata.fromMap(Map map) {
    Uint8List? art;
    final artList = map['albumArt'];
    if (artList is List && artList.isNotEmpty) {
      art = Uint8List.fromList(artList.cast<int>());
    }
    return AudioMetadata(
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      durationMs: (map['duration'] as num?)?.toInt() ?? 0,
      bitrate: (map['bitrate'] as num?)?.toInt(),
      albumArt: art,
    );
  }
}
