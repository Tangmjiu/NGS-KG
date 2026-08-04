import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../utils/logger.dart';

/// Reads audio file metadata using platform-specific APIs.
///
/// On Android, delegates to [MediaMetadataRetriever] via MethodChannel.
/// Falls back to direct file reading for embedded lyrics (ID3 USLT / FLAC VorbisComment)
/// since MediaMetadataRetriever does not expose lyrics.
///
/// [read] — one-shot read (used by legacy Windows scan).
/// [readDeferred] — on-demand single-file read with disk cache (used after
/// hybrid scan, for full cover art + embedded lyrics).
class MetadataReader {
  static const _channel = MethodChannel('com.mjiutang.ngskg/metadata');

  // In-memory cache: filePath → AudioMetadata (survives single session)
  static final _cache = <String, AudioMetadata>{};

  /// Reads metadata from [file].  Returns null if reading fails.
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

  /// 直接从音频文件读取内嵌歌词（ID3v2 USLT / FLAC VorbisComment）。
  /// MMR 不返回歌词，必须自行解析文件标签。
  static Future<String?> _extractEmbeddedLyrics(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(4);

        // ── MP3: ID3v2 标签 ──
        if (header.length >= 3 &&
            header[0] == 0x49 /*I*/ &&
            header[1] == 0x44 /*D*/ &&
            header[2] == 0x33 /*3*/) {
          // 跳过 header (10 bytes)
          await raf.setPosition(6);
          final sizeBytes = await raf.read(4);
          final tagSize = _synchsafeInt(sizeBytes);
          final tagEnd = 10 + tagSize;

          // 扫描 ID3v2 帧，查找 USLT
          var pos = 10;
          while (pos < tagEnd - 10) {
            await raf.setPosition(pos);
            final frameHeader = await raf.read(10);
            if (frameHeader.length < 10) break;

            final frameId = String.fromCharCodes(frameHeader.sublist(0, 4));
            final frameSize = _bytesToIntBE(frameHeader.sublist(4, 8));

            if (frameId == 'USLT' && frameSize > 4) {
              final frameData = await raf.read(frameSize);
              // USLT: encoding(1) + language(3) + descriptor(null-term) + lyrics
              final enc = frameData[0];
              int start = 4; // skip encoding + language
              // skip null-terminated content descriptor
              while (start < frameData.length && frameData[start] != 0) {
                start++;
              }
              start++; // skip null terminator
              if (start < frameData.length) {
                final lyricBytes = frameData.sublist(start);
                if (enc == 0x01) {
                  // UTF-16 with BOM
                  return utf8.decode(lyricBytes, allowMalformed: true);
                } else if (enc == 0x02) {
                  // UTF-16BE
                  return _decodeUtf16BE(lyricBytes);
                } else {
                  // ISO-8859-1 or UTF-8
                  return _decodeText(lyricBytes);
                }
              }
              break; // found USLT, no need to continue
            }

            pos += 10 + frameSize;
          }
          return null;
        }

        // ── FLAC: fLaC magic ──
        if (header.length >= 4 &&
            header[0] == 0x66 /*f*/ &&
            header[1] == 0x4C /*L*/ &&
            header[2] == 0x61 /*a*/ &&
            header[3] == 0x43 /*C*/) {
          // Parse metadata blocks until VORBIS_COMMENT
          await raf.setPosition(4);
          var lastBlock = false;
          while (!lastBlock) {
            final blockHeader = await raf.read(4);
            if (blockHeader.length < 4) break;
            lastBlock = (blockHeader[0] & 0x80) != 0;
            final blockType = blockHeader[0] & 0x7F;
            final blockSize = _bytesToIntBE(
                [0, blockHeader[1], blockHeader[2], blockHeader[3]]);

            if (blockType == 4) {
              // VORBIS_COMMENT
              final blockData = await raf.read(blockSize);
              // vendor length (4 bytes LE)
              final vendorLen = _bytesToIntLE(blockData.sublist(0, 4));
              var offset = 4 + vendorLen;
              // user comment list length (4 bytes LE)
              if (offset + 4 > blockData.length) break;
              final commentCount =
                  _bytesToIntLE(blockData.sublist(offset, offset + 4));
              offset += 4;

              for (var i = 0; i < commentCount; i++) {
                if (offset + 4 > blockData.length) break;
                final commentLen =
                    _bytesToIntLE(blockData.sublist(offset, offset + 4));
                offset += 4;
                if (offset + commentLen > blockData.length) break;
                final comment = utf8.decode(
                    blockData.sublist(offset, offset + commentLen),
                    allowMalformed: true);
                offset += commentLen;

                // 查找 LYRICS= 或 UNSYNCEDLYRICS=
                final eqIdx = comment.indexOf('=');
                if (eqIdx >= 0) {
                  final key = comment.substring(0, eqIdx).toUpperCase();
                  if (key == 'LYRICS' || key == 'UNSYNCEDLYRICS') {
                    return comment.substring(eqIdx + 1);
                  }
                }
              }
              break;
            }
            // skip non-VORBIS_COMMENT blocks
            await raf.setPosition(raf.positionSync() + blockSize);
          }
          return null;
        }
      } finally {
        await raf.close();
      }
    } catch (_) {
      // silently fail
    }
    return null;
  }

  ///
  /// Caches cover art to disk and lyrics to memory.  Returns the same
  /// [AudioMetadata] on subsequent calls (once per session).
  static Future<AudioMetadata?> readDeferred(Song song) async {
    final fp = song.filePath;
    if (fp == null) return null;
    if (_cache.containsKey(fp)) return _cache[fp];

    final file = File(fp);
    if (!await file.exists()) return null;

    final meta = await read(file);
    // MMR 不返回内嵌歌词 → 直接从文件字节解析
    String? embeddedLyrics;
    if (meta == null || meta.lyrics == null || meta.lyrics!.isEmpty) {
      embeddedLyrics = await _extractEmbeddedLyrics(file);
    }
    if (meta == null && embeddedLyrics == null) return null;

    // 合并 MMR 结果与内嵌歌词
    final effectiveMeta = meta != null
        ? AudioMetadata(
            title: meta.title,
            artist: meta.artist,
            album: meta.album,
            durationMs: meta.durationMs,
            bitrate: meta.bitrate,
            albumArt: meta.albumArt,
            lyrics: embeddedLyrics ?? meta.lyrics,
          )
        : AudioMetadata(lyrics: embeddedLyrics);

    // Cache cover art to temp directory
    if (effectiveMeta.albumArt != null && effectiveMeta.albumArt!.isNotEmpty) {
      try {
        final cacheDir = await getTemporaryDirectory();
        final baseName = p.basenameWithoutExtension(fp);
        final cacheFile = File('${cacheDir.path}/album_art_$baseName.jpg');
        if (!await cacheFile.exists()) {
          await cacheFile.writeAsBytes(effectiveMeta.albumArt!);
        }
        // Return the updated metadata with the cache path
        _cache[fp] = AudioMetadata(
          title: effectiveMeta.title,
          artist: effectiveMeta.artist,
          album: effectiveMeta.album,
          durationMs: effectiveMeta.durationMs,
          bitrate: effectiveMeta.bitrate,
          albumArt: effectiveMeta.albumArt,
          lyrics: effectiveMeta.lyrics,
          albumCoverCachePath: cacheFile.path,
        );
        return _cache[fp];
      } catch (e, s) {
        Log.e('metadata_reader', 'cover cache error', e, s);
      }
    }

    _cache[fp] = effectiveMeta;
    return effectiveMeta;
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

  // ── ID3 tag parsing helpers ──

  /// ID3v2 synchsafe integer → normal int (7 bits per byte).
  static int _synchsafeInt(List<int> bytes) {
    int result = 0;
    for (final b in bytes) {
      result = (result << 7) | (b & 0x7F);
    }
    return result;
  }

  static int _bytesToIntBE(List<int> bytes) {
    int result = 0;
    for (final b in bytes) {
      result = (result << 8) | b;
    }
    return result;
  }

  static int _bytesToIntLE(List<int> bytes) {
    int result = 0;
    for (var i = bytes.length - 1; i >= 0; i--) {
      result = (result << 8) | bytes[i];
    }
    return result;
  }

  static String _decodeUtf16BE(Uint8List bytes) {
    final sb = StringBuffer();
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final code = (bytes[i] << 8) | bytes[i + 1];
      sb.writeCharCode(code);
    }
    return sb.toString();
  }

  /// 优先 UTF-8，检测失败则回退 GBK。
  static String _decodeText(Uint8List bytes) {
    try {
      final s = utf8.decode(bytes, allowMalformed: true);
      final replacementCount = '\uFFFD'.allMatches(s).length;
      if (replacementCount > 0 && replacementCount > s.length * 0.05) {
        return _decodeGbk(bytes);
      }
      return s;
    } catch (_) {
      return _decodeGbk(bytes);
    }
  }

  static String _decodeGbk(Uint8List bytes) {
    final buf = StringBuffer();
    int i = 0;
    while (i < bytes.length) {
      final b1 = bytes[i];
      if (b1 < 0x80) {
        buf.writeCharCode(b1);
        i++;
      } else if (i + 1 < bytes.length) {
        final b2 = bytes[i + 1];
        final code = (b1 << 8) | b2;
        buf.writeCharCode(_gbkToUnicode(code));
        i += 2;
      } else {
        i++;
      }
    }
    return buf.toString();
  }

  static int _gbkToUnicode(int gbk) {
    final hi = (gbk >> 8) & 0xFF;
    final lo = gbk & 0xFF;
    if (hi >= 0xA1 && hi <= 0xA9 && lo >= 0xA1 && lo <= 0xFE) {
      return 0xFF00 + (hi - 0xA0) * 0x5E + (lo - 0xA1);
    }
    if (hi >= 0xB0 && hi <= 0xF7 && lo >= 0xA1 && lo <= 0xFE) {
      final offset = (hi - 0xB0) * 94 + (lo - 0xA1);
      if (hi >= 0xB0 && hi < 0xD8) {
        return 0x4E00 + offset;
      }
      return 0x4E00 + offset;
    }
    return 0xFFFD;
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
  final String? lyrics; // embedded lyrics (USLT text or FLAC LYRICS tag)
  final String? albumCoverCachePath; // path to cached cover on disk

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
