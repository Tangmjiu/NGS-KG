import 'dart:convert';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
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
    if (Platform.isAndroid) {
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
    // 桌面端：Android MethodChannel 不可用，委托给纯 Dart 的
    // audio_metadata_reader 库（同步解析，无原生依赖）。
    return DesktopMetadataParser.read(file);
  }

  /// 直接从音频文件读取内嵌歌词（ID3v2 USLT / FLAC VorbisComment）。
  /// MMR 不返回歌词，必须自行解析文件标签。
  static Future<String?> _extractEmbeddedLyrics(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      try {
        final header = raf.readSync(4);

        // ── MP3: ID3v2 标签 ──
        if (header.length >= 3 &&
            header[0] == 0x49 /*I*/ &&
            header[1] == 0x44 /*D*/ &&
            header[2] == 0x33 /*3*/) {
          // 跳过 header (10 bytes)
          raf.setPositionSync(6);
          final sizeBytes = raf.readSync(4);
          final tagSize = _synchsafeInt(sizeBytes);
          final tagEnd = 10 + tagSize;

          // 扫描 ID3v2 帧，查找 USLT
          var pos = 10;
          while (pos < tagEnd - 10) {
            raf.setPositionSync(pos);
            final frameHeader = raf.readSync(10);
            if (frameHeader.length < 10) break;

            final frameId = String.fromCharCodes(frameHeader.sublist(0, 4));
            final frameSize = _bytesToIntBE(frameHeader.sublist(4, 8));

            if (frameId == 'USLT' && frameSize > 4) {
              final frameData = raf.readSync(frameSize);
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
          raf.setPositionSync(4);
          var lastBlock = false;
          while (!lastBlock) {
            final blockHeader = raf.readSync(4);
            if (blockHeader.length < 4) break;
            lastBlock = (blockHeader[0] & 0x80) != 0;
            final blockType = blockHeader[0] & 0x7F;
            final blockSize = _bytesToIntBE(
                [0, blockHeader[1], blockHeader[2], blockHeader[3]]);

            if (blockType == 4) {
              // VORBIS_COMMENT
              final blockData = raf.readSync(blockSize);
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
            raf.setPositionSync(raf.positionSync() + blockSize);
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
    // 库/MMR 未返回内嵌歌词时，直接从文件字节解析
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
      return 0x4E00 + offset;
    }
    return 0xFFFD;
  }
}

/// 桌面端（Windows/Linux/macOS）音频元数据解析。
///
/// 使用纯 Dart 的 `audio_metadata_reader` 库解析标签/封面/歌词，
/// 并补充库不支持的部分：MP3 时长估算（MPEG 帧头 / Xing 帧数）。
class DesktopMetadataParser {
  static Future<AudioMetadata?> read(File file) async {
    try {
      final md = readMetadata(file, getImage: true);

      Uint8List? art;
      if (md.pictures.isNotEmpty) {
        final pic = md.pictures.firstWhere(
          (p) => p.bytes.length >= 32,
          orElse: () => md.pictures.first,
        );
        if (pic.bytes.length >= 32) art = pic.bytes;
      }

      var durationMs = md.duration?.inMilliseconds ?? 0;
      // MP3 的 ID3 标签不含时长，库无法给出 → 用 MPEG 帧头估算
      if (durationMs <= 0 && file.path.toLowerCase().endsWith('.mp3')) {
        durationMs = _estimateMp3Duration(file);
      }

      int? bitrate = md.bitrate;
      if (bitrate == null && durationMs > 0) {
        bitrate = (file.lengthSync() * 8 / durationMs * 1000 / 1000).round();
      }

      if (md.title == null &&
          md.artist == null &&
          md.album == null &&
          art == null &&
          md.lyrics == null &&
          durationMs == 0) {
        return null;
      }

      return AudioMetadata(
        title: md.title,
        artist: md.artist,
        album: md.album,
        durationMs: durationMs,
        bitrate: bitrate,
        albumArt: art,
        lyrics: md.lyrics,
      );
    } catch (_) {
      // 解析失败（格式不支持/损坏）返回 null，由调用方回退文件名标题
      return null;
    }
  }

  /// 估算 MP3 时长：解析第一个 MPEG 帧头（支持 Xing/Info VBR 帧数）。
  static int _estimateMp3Duration(File file) {
    try {
      final raf = file.openSync(mode: FileMode.read);
      try {
        final length = raf.lengthSync();
        if (length < 4) return 0;

        // 跳过 ID3v2 标签区
        raf.setPositionSync(0);
        final head = raf.readSync(10);
        int start = 0;
        if (head.length >= 10 &&
            head[0] == 0x49 &&
            head[1] == 0x44 &&
            head[2] == 0x33) {
          start = 10 +
              ((head[6] << 21) | (head[7] << 14) | (head[8] << 7) | head[9]);
        }
        if (start >= length) return 0;

        // 前 64KB 内找帧同步
        final window = length - start > 65536 ? 65536 : length - start;
        raf.setPositionSync(start);
        final buf = raf.readSync(window);
        final fh = _findMpegFrameHeader(buf);
        if (fh == null) return 0;

        final bitrate = fh['bitrate'] as int;
        final sampleRate = fh['sampleRate'] as int;
        final samplesPerFrame = fh['samplesPerFrame'] as int;
        final fhOffset = fh['offset'] as int;

        // Xing / Info VBR 头（帧头 4 字节后的 4 字节）
        if (buf.length >= fhOffset + 8 &&
            buf[fhOffset + 4] == 0x58 && // 'X'
            buf[fhOffset + 5] == 0x69 && // 'i'
            buf[fhOffset + 6] == 0x6E && // 'n'
            buf[fhOffset + 7] == 0x67) {
          final flags = _bytesToIntBE(buf.sublist(fhOffset + 8, fhOffset + 12));
          if ((flags & 1) != 0 && buf.length >= fhOffset + 16) {
            final frames =
                _bytesToIntBE(buf.sublist(fhOffset + 12, fhOffset + 16));
            if (frames > 0) {
              return (frames * samplesPerFrame * 1000 / sampleRate).round();
            }
          }
        } else if (buf.length >= fhOffset + 8 &&
            buf[fhOffset + 4] == 0x49 && // 'I' (Info 头，CBR)
            buf[fhOffset + 5] == 0x6E &&
            buf[fhOffset + 6] == 0x66 &&
            buf[fhOffset + 7] == 0x6F) {
          final flags = _bytesToIntBE(buf.sublist(fhOffset + 8, fhOffset + 12));
          if ((flags & 1) != 0 && buf.length >= fhOffset + 16) {
            final frames =
                _bytesToIntBE(buf.sublist(fhOffset + 12, fhOffset + 16));
            if (frames > 0) {
              return (frames * samplesPerFrame * 1000 / sampleRate).round();
            }
          }
        }

        // CBR：文件大小 / 位率
        if (bitrate <= 0) return 0;
        return ((length - start) * 8 * 1000 / bitrate).round();
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return 0;
    }
  }

  /// 在缓冲区中寻找第一个 MPEG 音频帧头。
  static Map<String, int>? _findMpegFrameHeader(List<int> buf) {
    for (var i = 0; i + 3 < buf.length; i++) {
      if (buf[i] != 0xFF || (buf[i + 1] & 0xE0) != 0xE0) continue;
      final ver = (buf[i + 1] >> 3) & 0x03; // 0=2.5 2=2 3=1
      final layer = (buf[i + 1] >> 1) & 0x03; // 1=L3 2=L2 3=L1
      if (ver == 1 || layer == 0) continue; // reserved
      final bitrateIdx = (buf[i + 2] >> 4) & 0x0F;
      final sampleIdx = (buf[i + 2] >> 2) & 0x03;
      if (bitrateIdx == 0 || bitrateIdx == 15) continue;
      if (sampleIdx == 3) continue;

      const l1 = [
        0,
        32,
        64,
        96,
        128,
        160,
        192,
        224,
        256,
        288,
        320,
        352,
        384,
        416,
        448,
        0
      ];
      const l2 = [
        0,
        32,
        48,
        56,
        64,
        80,
        96,
        112,
        128,
        160,
        192,
        224,
        256,
        320,
        384,
        0
      ];
      const l3 = [
        0,
        32,
        40,
        48,
        56,
        64,
        80,
        96,
        112,
        128,
        160,
        192,
        224,
        256,
        320,
        0
      ];
      const l1b = [
        0,
        32,
        48,
        56,
        64,
        80,
        96,
        112,
        128,
        144,
        160,
        176,
        192,
        224,
        256,
        0
      ];
      const l2b = [
        0,
        8,
        16,
        24,
        32,
        40,
        48,
        56,
        64,
        80,
        96,
        112,
        128,
        144,
        160,
        0
      ];

      int? bitrate;
      int? sampleRate;
      int samplesPerFrame;
      if (ver == 3) {
        // MPEG1
        sampleRate = [44100, 48000, 32000, 0][sampleIdx];
        if (layer == 3) bitrate = l1[bitrateIdx];
        if (layer == 2) bitrate = l2[bitrateIdx];
        if (layer == 1) bitrate = l3[bitrateIdx];
        samplesPerFrame = layer == 3 ? 384 : 1152;
      } else {
        // MPEG2 / 2.5
        sampleRate = ver == 2
            ? [22050, 24000, 16000, 0][sampleIdx]
            : [11025, 12000, 8000, 0][sampleIdx];
        if (layer == 3) bitrate = l1b[bitrateIdx];
        if (layer == 2 || layer == 1) bitrate = l2b[bitrateIdx];
        samplesPerFrame = layer == 3 ? 384 : 576;
      }
      if (bitrate == null || bitrate == 0) continue;
      return {
        'offset': i,
        'bitrate': bitrate * 1000,
        'sampleRate': sampleRate,
        'samplesPerFrame': samplesPerFrame,
      };
    }
    return null;
  }

  static int _bytesToIntBE(List<int> bytes) {
    int result = 0;
    for (final b in bytes) {
      result = (result << 8) | b;
    }
    return result;
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
