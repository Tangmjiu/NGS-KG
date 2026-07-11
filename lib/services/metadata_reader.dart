import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/local_song.dart';
import '../utils/logger.dart';
import 'metadata_windows.dart';

/// Reads audio file metadata using platform-specific APIs.
///
/// On Android, delegates to [MediaMetadataRetriever] via MethodChannel.
/// Falls back to filename-based extraction if the channel is unavailable.
/// On Windows, uses the pure-Dart [WindowsMetadataReader] instead.
///
/// [read] — one-shot read (used by legacy scan).
/// [readDeferred] — on-demand single-file read with disk cache (used after
/// scan, for full cover art + embedded lyrics).
class MetadataReader {
  static const _channel = MethodChannel('com.mjiutang.ngskg/metadata');

  // In-memory cache: filePath → AudioMetadata (survives single session)
  static final _cache = <String, AudioMetadata>{};

  /// Reads metadata from [file].  Returns null if reading fails.
  static Future<AudioMetadata?> read(File file) async {
    // Windows: use pure-Dart parser (no MethodChannel available)
    if (Platform.isWindows || Platform.isLinux) {
      return WindowsMetadataReader.read(file);
    }

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

  /// On-demand read for a single [LocalSong].
  ///
  /// Caches cover art to disk and lyrics to memory.  Returns the same
  /// [AudioMetadata] on subsequent calls (once per session).
  static Future<AudioMetadata?> readDeferred(LocalSong song) async {
    if (_cache.containsKey(song.filePath)) return _cache[song.filePath];

    final file = File(song.filePath);
    if (!await file.exists()) return null;

    final meta = await read(file);
    if (meta == null) return null;

    // Cache cover art to temp directory
    if (meta.albumArt != null && meta.albumArt!.isNotEmpty) {
      try {
        final cacheDir = await getTemporaryDirectory();
        final baseName = p.basenameWithoutExtension(song.filePath);
        final cacheFile = File('${cacheDir.path}/album_art_$baseName.jpg');
        if (!await cacheFile.exists()) {
          await cacheFile.writeAsBytes(meta.albumArt!);
        }
        // Return the updated metadata with the cache path
        _cache[song.filePath] = AudioMetadata(
          title: meta.title,
          artist: meta.artist,
          album: meta.album,
          durationMs: meta.durationMs,
          bitrate: meta.bitrate,
          albumArt: meta.albumArt,
          lyrics: meta.lyrics,
          albumCoverCachePath: cacheFile.path,
        );
        return _cache[song.filePath];
      } catch (e, s) {
        Log.e('metadata_reader', 'cover cache error', e, s);
      }
    }

    _cache[song.filePath] = meta;
    return meta;
  }

  /// Returns the cached cover path for [filePath], or null.
  static Future<String?> cachedCoverPath(String filePath) async {
    final entry = _cache[filePath];
    if (entry?.albumCoverCachePath != null) return entry!.albumCoverCachePath;
    // Check disk cache directly
    try {
      final cacheDir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(filePath);
      final cacheFile = File('${cacheDir.path}/album_art_$baseName.jpg');
      return cacheFile.existsSync() ? cacheFile.path : null;
    } catch (_) {
      return null;
    }
  }

  /// Clear in-memory cache (e.g. when locale changes or full re-scan).
  static void clearCache() => _cache.clear();
}

/// Parsed audio metadata.
class AudioMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final int durationMs;
  final int? bitrate;
  final Uint8List? albumArt;
  final String? lyrics; // embedded lyrics (USLT/SYLT text or FLAC LYRICS tag)
  final String? albumCoverCachePath; // disk-cached cover art path

  const AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.durationMs = 0,
    this.bitrate,
    this.albumArt,
    this.lyrics,
    this.albumCoverCachePath,
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
      lyrics: map['lyrics'] as String?,
    );
  }
}
