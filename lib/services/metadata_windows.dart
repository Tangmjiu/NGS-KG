import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'metadata_reader.dart';

/// Pure-Dart audio metadata reader for Windows.
///
/// Parses ID3v2 tags from MP3 files and METADATA_BLOCK_* from FLAC files
/// using only [dart:io], [dart:typed_data], and [dart:convert].
/// No FFI, MethodChannel, or external packages are used.
class WindowsMetadataReader {
  /// Maximum bytes to read from the head of a file (10 MB).
  /// Avoids loading the entire file into memory when all metadata lives
  /// in the first few kilobytes.
  static const int _maxReadBytes = 10 * 1024 * 1024;

  // ── Public API ──────────────────────────────────────────────────────

  /// Reads [AudioMetadata] from [file].
  ///
  /// Returns `null` when the file is not a supported format (MP3/FLAC) or
  /// when parsing fails due to truncation or corruption.
  static Future<AudioMetadata?> read(File file) async {
    try {
      final length = await file.length();
      if (length == 0) return null;

      final bytes = await _readUpToAsync(file, _maxReadBytes);
      if (bytes == null || bytes.length < 4) return null;

      // MP3 — ID3v2 header starts with "ID3"
      if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
        final result = _parseId3v2(bytes);
        // If structured ID3v2 parsing didn't find cover art, try a
        // brute-force scan of raw bytes for JPEG/PNG magic headers.
        // Handles non-standard APIC frames, multiple covers, etc.
        if (result?.albumArt == null) {
          final art = _bruteForceScanForImage(bytes);
          if (art != null) {
            return AudioMetadata(
              title: result?.title,
              artist: result?.artist,
              album: result?.album,
              durationMs: result?.durationMs ?? 0,
              bitrate: result?.bitrate,
              lyrics: result?.lyrics,
              albumArt: art,
            );
          }
        }
        return result;
      }

      AudioMetadata? result;

      // FLAC — magic bytes "fLaC"
      if (bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43) {
        result = _parseFlac(bytes);
      } else if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
        result = _parseId3v2(bytes);
      }

      // 如果解析后仍然没有封面，暴力扫描整个文件缓冲区
      if (result?.albumArt == null) {
        final art = _bruteForceScanForImage(bytes);
        if (art != null) {
          result = AudioMetadata(
            title: result?.title,
            artist: result?.artist,
            album: result?.album,
            durationMs: result?.durationMs ?? 0,
            bitrate: result?.bitrate,
            lyrics: result?.lyrics,
            albumArt: art,
          );
        }
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  // ── File I/O ────────────────────────────────────────────────────────

  /// Reads up to [maxBytes] from [file], returning `null` on error.
  static Future<Uint8List?> _readUpToAsync(File file, int maxBytes) async {
    try {
      final length = await file.length();
      final count = length < maxBytes ? length : maxBytes;
      final raf = await file.open(mode: FileMode.read);
      try {
        return await raf.read(count);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  // ── ID3v2 (MP3) ────────────────────────────────────────────────────

  /// ID3v2 frame IDs we care about.
  static const _frameTitle = 'TIT2';
  static const _frameArtist = 'TPE1';
  static const _frameAlbum = 'TALB';
  static const _frameCover = 'APIC';
  static const _frameLyricsUnsync = 'USLT'; // Unsynchronised lyrics (plain text)
  static const _frameLyricsSync = 'SYLT';   // Synchronised lyrics (with timestamps)

  /// Parses an ID3v2 tag starting at position 0 in [data].
  static AudioMetadata? _parseId3v2(Uint8List data) {
    if (data.length < 10) return null;

    final header = data;
    final majorVer = header[3];
    final flags = header[5];
    final tagSize = _readSynchsafeInt(header, 6);

    // Validate minimum tag size
    if (tagSize < 0 || data.length < 10 + tagSize) return null;

    int offset = 10; // past the 10-byte header

    // ── Handle extended header ────────────────────────────────
    if ((flags & 0x40) != 0) {
      if (offset + 4 > data.length) return null;
      int extSize;
      if (majorVer >= 4) {
        // ID3v2.4: extended header size is synchsafe
        extSize = _readSynchsafeInt(data, offset);
      } else {
        // ID3v2.3: extended header size is a regular 4-byte int
        extSize = _readInt32(data, offset);
      }
      offset += 4;
      // Skip the extended header body (extSize bytes)
      // For ID3v2.3 the size includes the 4-byte size field itself,
      // so we need to skip (extSize - 4) additional bytes.
      // For ID3v2.4 the size only covers the extended header data,
      // so we skip extSize bytes.
      final skipBytes = (majorVer >= 4) ? extSize : (extSize - 4);
      if (skipBytes < 0) return null;
      offset += skipBytes;
    }

    // ── Read frame data (apply unsynchronization if needed) ──
    Uint8List frameData;
    if ((flags & 0x80) != 0) {
      frameData = _deunsync(data.sublist(10, 10 + tagSize));
      offset = 0; // restart since we extracted the raw frame area
    } else {
      frameData = data.sublist(10, 10 + tagSize);
      offset = 0;
    }

    String? title;
    String? artist;
    String? album;
    Uint8List? coverArt;
    String? lyrics;

    while (offset + 8 <= frameData.length) {
      // Frame ID (4 bytes) — might be padding (zeros) or garbage
      final frameId = String.fromCharCodes(frameData, offset, offset + 4);
      offset += 4;

      // Padding: frames of all zeros terminate the frame section
      if (frameId == '\x00\x00\x00\x00') break;

      int frameSize;
      if (majorVer >= 4) {
        // ID3v2.4: frame size is synchsafe
        frameSize = _readSynchsafeInt(frameData, offset);
      } else {
        // ID3v2.3: frame size is regular int
        frameSize = _readInt32(frameData, offset);
      }
      offset += 4;

      // Skip frame flags (2 bytes)
      offset += 2;

      if (frameSize < 0 || offset + frameSize > frameData.length) break;

      switch (frameId) {
        case _frameTitle:
          title = _parseId3v2TextFrame(frameData, offset, frameSize);
          break;
        case _frameArtist:
          artist = _parseId3v2TextFrame(frameData, offset, frameSize);
          break;
        case _frameAlbum:
          album = _parseId3v2TextFrame(frameData, offset, frameSize);
          break;
        case _frameCover:
          coverArt ??= _parseApicFrame(frameData, offset, frameSize);
          break;
        case _frameLyricsUnsync:
          lyrics ??= _parseUsltFrame(frameData, offset, frameSize);
          break;
        case _frameLyricsSync:
          lyrics ??= _parseSyltFrame(frameData, offset, frameSize);
          break;
      }

      offset += frameSize;
    }

    return AudioMetadata(
      title: title,
      artist: artist,
      album: album,
      durationMs: 0, // Not available from ID3v2 tags
      bitrate: null, // Not reliably available from ID3v2 tags
      albumArt: coverArt,
      lyrics: lyrics,
    );
  }

  /// Parses a text frame body (TIT2, TPE1, TALB, etc.).
  ///
  /// The first byte is the encoding byte; the rest is text.
  static String? _parseId3v2TextFrame(
      Uint8List data, int offset, int size) {
    if (size < 2) return null;
    final encoding = data[offset];
    final textData = data.sublist(offset + 1, offset + size);
    return _decodeId3v2String(textData, encoding);
  }

  /// Decodes a byte sequence according to the ID3v2 encoding byte.
  ///
  /// Encoding values:
  ///   $00 → ISO-8859-1 (Latin-1)
  ///   $01 → UTF-16 with BOM
  ///   $02 → UTF-16BE
  ///   $03 → UTF-8
  ///
  /// Note: `dart:convert` has no built-in UTF-16 decoder, so we
  /// implement it manually via [String.fromCharCodes].
  static String? _decodeId3v2String(Uint8List bytes, int encoding) {
    try {
      switch (encoding) {
        case 0x00: // ISO-8859-1
          return latin1.decode(bytes);
        case 0x01: // UTF-16 with BOM
          return _decodeUtf16WithBom(bytes);
        case 0x02: // UTF-16BE
          return _decodeUtf16(bytes, Endian.big);
        case 0x03: // UTF-8
          return utf8.decode(bytes);
        default:
          return latin1.decode(bytes);
      }
    } catch (_) {
      return null;
    }
  }

  /// Decodes UTF-16 text that may or may not start with a BOM.
  static String? _decodeUtf16WithBom(Uint8List bytes) {
    if (bytes.length < 2) return null;
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // Big-endian BOM — strip it then decode as UTF-16BE
      return _decodeUtf16(bytes.sublist(2), Endian.big);
    } else if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // Little-endian BOM — strip it then decode as UTF-16LE
      return _decodeUtf16(bytes.sublist(2), Endian.little);
    } else {
      // No BOM — assume big-endian per spec
      return _decodeUtf16(bytes, Endian.big);
    }
  }

  /// Manual UTF-16 decoder supporting both endiannesses.
  ///
  /// Handles surrogate pairs to produce correct Unicode code points.
  /// Replacement character (U+FFFD) is used for lone surrogates.
  static String _decodeUtf16(Uint8List bytes, Endian endian) {
    final codePoints = <int>[];
    int i = 0;
    while (i < bytes.length - 1) {
      final high = endian == Endian.big
          ? (bytes[i] << 8) | bytes[i + 1]
          : bytes[i] | (bytes[i + 1] << 8);
      i += 2;

      if (high >= 0xD800 && high <= 0xDBFF) {
        // High surrogate — expect a low surrogate next
        if (i < bytes.length - 1) {
          final low = endian == Endian.big
              ? (bytes[i] << 8) | bytes[i + 1]
              : bytes[i] | (bytes[i + 1] << 8);
          i += 2;
          if (low >= 0xDC00 && low <= 0xDFFF) {
            codePoints
                .add(0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00));
          } else {
            // Stray high surrogate — emit replacement
            codePoints.add(0xFFFD);
          }
        } else {
          // Truncated — emit replacement
          codePoints.add(0xFFFD);
        }
      } else if (high >= 0xDC00 && high <= 0xDFFF) {
        // Lone low surrogate
        codePoints.add(0xFFFD);
      } else {
        codePoints.add(high);
      }
    }
    // Handle trailing byte (odd length)
    if (i < bytes.length) codePoints.add(0xFFFD);
    return String.fromCharCodes(codePoints);
  }

  /// Parses an APIC (attached picture) frame.
  ///
  /// Layout: encoding[1] + mimeType[null-terminated] + pictureType[1] +
  ///         description[null-terminated, encoding-specific] + imageData[rest]
  static Uint8List? _parseApicFrame(
      Uint8List data, int offset, int size) {
    if (size < 5) return null;

    final encoding = data[offset];
    int pos = offset + 1;

    // MIME type: null-terminated, always ISO-8859-1
    while (pos < offset + size && data[pos] != 0) {
      pos++;
    }
    if (pos >= offset + size) return null;
    pos++; // skip null terminator

    // Picture type (1 byte) — skip it, we take any
    if (pos >= offset + size) return null;
    pos++;

    // Description: null-terminated, encoding-dependent
    if (encoding == 0x01 || encoding == 0x02) {
      // UTF-16: null terminator is 2 bytes (0x00 0x00)
      while (pos + 1 < offset + size &&
          !(data[pos] == 0 && data[pos + 1] == 0)) {
        pos++;
      }
      if (pos + 1 >= offset + size) return null;
      pos += 2; // skip 2-byte null terminator
    } else {
      // ISO-8859-1 or UTF-8: null terminator is 1 byte
      while (pos < offset + size && data[pos] != 0) {
        pos++;
      }
      if (pos >= offset + size) return null;
      pos++; // skip null terminator
    }

    // Remaining bytes = image data
    final imageSize = offset + size - pos;
    if (imageSize <= 0) return null;

    return Uint8List.fromList(data.sublist(pos, offset + size));
  }

  /// Parses a USLT (unsynchronised lyrics) frame.
  ///
  /// Layout: encoding[1] + language[3] + contentDescriptor[null-terminated] +
  ///         lyricsText[rest]
  /// Returns the raw lyrics text (no timestamps).
  static String? _parseUsltFrame(
      Uint8List data, int offset, int size) {
    if (size < 5) return null;
    final encoding = data[offset];
    int pos = offset + 1;

    // Language code (3 bytes) — skip
    pos += 3;
    if (pos >= offset + size) return null;

    // Content descriptor: null-terminated, encoding-dependent
    pos = _skipNullTerminated(data, pos, offset + size, encoding);
    if (pos >= offset + size) return null;

    // Remaining bytes = lyrics text
    final textData = data.sublist(pos, offset + size);
    return _decodeId3v2String(textData, encoding);
  }

  /// Parses a SYLT (synchronised lyrics) frame.
  ///
  /// Layout: encoding[1] + language[3] + format[1] + contentType[1] +
  ///         contentDescriptor[null-terminated] + syncEntries[rest]
  /// Returns lyrics text as "HH:MM.SS text\\n" lines (stripped timestamps
  /// for now, returning just the text).
  static String? _parseSyltFrame(
      Uint8List data, int offset, int size) {
    if (size < 6) return null;
    final encoding = data[offset];
    int pos = offset + 1;

    // Language code (3 bytes) — skip
    pos += 3;
    if (pos >= offset + size) return null;

    // Sync format (1 byte) + content type (1 byte) — skip
    pos += 2;
    if (pos >= offset + size) return null;

    // Content descriptor: null-terminated
    pos = _skipNullTerminated(data, pos, offset + size, encoding);
    if (pos >= offset + size) return null;

    // Parse sync entries: each entry = text[null-terminated] + timestamp[4 bytes]
    final lines = <String>[];
    while (pos + 5 <= offset + size) {
      // Text: null-terminated, same encoding as header
      final textStart = pos;
      pos = _skipNullTerminated(data, pos, offset + size, encoding);
      if (pos < textStart) break;
      final textData = data.sublist(textStart, pos);
      if (pos >= offset + size) break;
      pos++; // skip null terminator

      final text = _decodeId3v2String(textData, encoding);
      if (text != null && text.trim().isNotEmpty) {
        lines.add(text.trim());
      }

      // Timestamp (4 bytes, big-endian milliseconds) — skip it
      pos += 4;
      if (pos > offset + size) break;
    }

    if (lines.isEmpty) return null;
    return lines.join('\n');
  }

  /// Skips a null-terminated string starting at [pos] with the given
  /// [encoding]. Returns the position after the null terminator.
  static int _skipNullTerminated(
      Uint8List data, int pos, int end, int encoding) {
    if (pos >= end) return end;
    if (encoding == 0x01 || encoding == 0x02) {
      // UTF-16: null terminator is 2 bytes (0x00 0x00)
      while (pos + 1 < end && !(data[pos] == 0 && data[pos + 1] == 0)) {
        pos++;
      }
      if (pos + 1 < end) pos += 2; // skip 2-byte null
    } else {
      // ISO-8859-1 or UTF-8: null terminator is 1 byte
      while (pos < end && data[pos] != 0) {
        pos++;
      }
      if (pos < end) pos++; // skip 1-byte null
    }
    return pos;
  }

  // ── FLAC ────────────────────────────────────────────────────────────

  /// Parses a FLAC file starting at position 0 in [data].
  static AudioMetadata? _parseFlac(Uint8List data) {
    if (data.length < 42) return null; // need at least STREAMINFO header

    int offset = 4; // skip "fLaC" magic

    String? title;
    String? artist;
    String? album;
    Uint8List? coverArt;
    String? lyrics;
    int? bitrate;
    int totalSamples = 0;
    int sampleRate = 0;

    // Iterate over metadata blocks
    while (offset + 4 <= data.length) {
      final blockHeader = ByteData.sublistView(data, offset, offset + 4);
      final isLast = (blockHeader.getUint8(0) & 0x80) != 0;
      final blockType = blockHeader.getUint8(0) & 0x7F;
      final blockSize = _readUint24(data, offset + 1);

      offset += 4;

      if (blockSize < 0 || offset + blockSize > data.length) break;

      switch (blockType) {
        case 0: // STREAMINFO
          if (blockSize >= 34) {
            _parseFlacStreamInfo(data, offset, (s, r) {
              totalSamples = s;
              sampleRate = r;
            });
          }
          break;

          case 4: // VORBIS_COMMENT
            _parseVorbisComment(data, offset, blockSize, (k, v) {
              switch (k.toUpperCase()) {
                case 'TITLE':
                  title ??= v;
                  break;
                case 'ARTIST':
                  artist ??= v;
                  break;
                case 'ALBUM':
                  album ??= v;
                  break;
                case 'LYRICS':
                  lyrics ??= v;
                  break;
              }
            });
            break;

        case 6: // PICTURE
          coverArt ??= _parseFlacPicture(data, offset, blockSize);
          break;
      }

      offset += blockSize;
      if (isLast) break;
    }

    final int durationMs;
    if (sampleRate > 0 && totalSamples > 0) {
      durationMs = (totalSamples / sampleRate * 1000).round();
    } else {
      durationMs = 0;
    }

    return AudioMetadata(
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      bitrate: bitrate,
      albumArt: coverArt,
      lyrics: lyrics,
    );
  }

  /// Parses a STREAMINFO block at [offset] in [data].
  ///
  /// Calls [onResult] with (totalSamples, sampleRate).
  static void _parseFlacStreamInfo(
    Uint8List data,
    int offset,
    void Function(int totalSamples, int sampleRate) onResult,
  ) {
    if (offset + 18 > data.length) return;

    // Bytes 10-17 (8 bytes) contain the bit-packed fields:
    //   sampleRate (20 bits) | channels-1 (3 bits) |
    //   bitsPerSample-1 (5 bits) | totalSamples (36 bits)
    final packed = ByteData.sublistView(data, offset + 10, offset + 18);
    // ByteData.getUint64 reads big-endian (network byte order) — correct for FLAC.
    final bits = packed.getUint64(0);

    // Bits 0-19 (MSB) = sample rate (20 bits)
    final parsedSampleRate = (bits >> 44) & 0xFFFFF;

    // Bits 28-63 = total samples (36 bits)
    final parsedTotalSamples = bits & 0xFFFFFFFFF;

    onResult(parsedTotalSamples, parsedSampleRate);
  }

  /// Parses a VORBIS_COMMENT block.
  ///
  /// Calls [onField] for each key=value pair found.
  static void _parseVorbisComment(
    Uint8List data,
    int offset,
    int blockSize,
    void Function(String key, String value) onField,
  ) {
    if (blockSize < 8) return;

    final view = ByteData.sublistView(data, offset, offset + blockSize);
    int pos = 0;

    // Vorbis comments use little-endian length fields.
    // Vendor string length (4 bytes, LE)
    final vendorLen = view.getUint32(pos, Endian.little);
    pos += 4;
    if (pos + vendorLen > blockSize) return;
    // Skip vendor string
    pos += vendorLen;

    // Number of comments (4 bytes, LE)
    if (pos + 4 > blockSize) return;
    final commentCount = view.getUint32(pos, Endian.little);
    pos += 4;

    for (int i = 0; i < commentCount; i++) {
      if (pos + 4 > blockSize) return;
      final commentLen = view.getUint32(pos, Endian.little);
      pos += 4;
      if (pos + commentLen > blockSize) return;

      // Comment is "KEY=VALUE" in UTF-8
      try {
        final comment = utf8.decode(data.sublist(offset + pos, offset + pos + commentLen));
        pos += commentLen;

        final eqIdx = comment.indexOf('=');
        if (eqIdx > 0) {
          onField(comment.substring(0, eqIdx), comment.substring(eqIdx + 1));
        }
      } catch (_) {
        pos += commentLen;
      }
    }
  }

  /// Parses a PICTURE metadata block (type 6).
  ///
  /// Layout:
  ///   pictureType[4] + mimeLen[4] + mime + descLen[4] + desc +
  ///   width[4] + height[4] + depth[4] + colors[4] + imageData[rest]
  static Uint8List? _parseFlacPicture(
      Uint8List data, int offset, int blockSize) {
    if (blockSize < 32) return null;

    // 方法 1：标准 FLAC PICTURE block 解析
    try {
      final view = ByteData.sublistView(data, offset, offset + blockSize);
      int pos = 0;

      // picture type (4 bytes, big-endian)
      pos += 4;

      // MIME type length + data
      final mimeLen = view.getUint32(pos);
      pos += 4;
      if (pos + mimeLen > blockSize) return _scanBlockForImage(data, offset, blockSize);
      pos += mimeLen;

      // Description length + data
      final descLen = view.getUint32(pos);
      pos += 4;
      if (pos + descLen > blockSize) return _scanBlockForImage(data, offset, blockSize);
      pos += descLen;

      // width (4), height (4), depth (4), colors (4)
      pos += 16;

      if (pos >= blockSize) return null;
      final imageSize = blockSize - pos;
      if (imageSize < 50) return null;
      return Uint8List.fromList(data.sublist(offset + pos, offset + pos + imageSize));
    } catch (_) {
      // 标准解析失败，尝试盲搜图片
      return _scanBlockForImage(data, offset, blockSize);
    }
  }

  /// Fallback: scan bytes for JPEG/PNG magic headers when standard parsing fails.
  static Uint8List? _scanBlockForImage(
      Uint8List data, int offset, int blockSize) {
    final end = offset + blockSize;
    if (end > data.length) return null;
    final chunk = data.sublist(offset, end);

    // JPEG: FF D8 FF
    var idx = _indexOf(chunk, [0xFF, 0xD8, 0xFF]);
    if (idx >= 0) {
      // Find JPEG end marker FFD9
      final endIdx = _lastIndexOf(chunk, [0xFF, 0xD9]);
      if (endIdx > idx && endIdx - idx > 50) {
        return Uint8List.fromList(chunk.sublist(idx, endIdx + 2));
      }
    }

    // PNG: 89 50 4E 47
    idx = _indexOf(chunk, [0x89, 0x50, 0x4E, 0x47]);
    if (idx >= 0) {
      // Find IEND chunk
      final endIdx = _lastIndexOf(chunk, [0x49, 0x45, 0x4E, 0x44]);
      if (endIdx > idx && endIdx - idx > 50) {
        return Uint8List.fromList(chunk.sublist(idx, endIdx + 8));
      }
    }

    return null;
  }

  /// Scans the full data buffer for JPEG/PNG images (no format assumptions).
  static Uint8List? _bruteForceScanForImage(Uint8List data) {
    // JPEG
    int start = _indexOf(data, [0xFF, 0xD8, 0xFF]);
    if (start >= 0) {
      int end = _lastIndexOf(data, [0xFF, 0xD9]);
      if (end > start && end - start > 100) {
        return Uint8List.fromList(data.sublist(start, end + 2));
      }
    }
    // PNG
    start = _indexOf(data, [0x89, 0x50, 0x4E, 0x47]);
    if (start >= 0) {
      int end = _lastIndexOf(data, [0x49, 0x45, 0x4E, 0x44]);
      if (end > start && end - start > 100) {
        return Uint8List.fromList(data.sublist(start, end + 8));
      }
    }
    return null;
  }

  static int _indexOf(Uint8List haystack, List<int> needle) {
    for (int i = 0; i <= haystack.length - needle.length; i++) {
      bool match = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) { match = false; break; }
      }
      if (match) return i;
    }
    return -1;
  }

  static int _lastIndexOf(Uint8List haystack, List<int> needle) {
    for (int i = haystack.length - needle.length; i >= 0; i--) {
      bool match = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) { match = false; break; }
      }
      if (match) return i;
    }
    return -1;
  }

  // ── Binary helpers ──────────────────────────────────────────────────

  /// Reads a 4-byte synchsafe integer from [data] at [offset].
  ///
  /// Synchsafe integers use only the lower 7 bits of each byte
  /// (bit 7 is always 0). This is used in ID3v2 headers and
  /// ID3v2.4 frame sizes.
  static int _readSynchsafeInt(Uint8List data, int offset) {
    if (offset + 3 >= data.length) return -1;
    return ((data[offset] & 0x7F) << 21) |
        ((data[offset + 1] & 0x7F) << 14) |
        ((data[offset + 2] & 0x7F) << 7) |
        (data[offset + 3] & 0x7F);
  }

  /// Reads a regular big-endian 32-bit integer from [data] at [offset].
  static int _readInt32(Uint8List data, int offset) {
    if (offset + 3 >= data.length) return -1;
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  /// Reads a 3-byte big-endian unsigned integer from [data] at [offset].
  static int _readUint24(Uint8List data, int offset) {
    if (offset + 2 >= data.length) return -1;
    return (data[offset] << 16) |
        (data[offset + 1] << 8) |
        data[offset + 2];
  }

  /// Reverses ID3v2 unsynchronization: replaces `0xFF 0x00` with `0xFF`.
  static Uint8List _deunsync(Uint8List data) {
    // Count occurrences to pre-allocate exact size
    int count = 0;
    for (int i = 0; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0x00) {
        count++;
      }
    }
    if (count == 0) return data;

    final result = Uint8List(data.length - count);
    int ri = 0;
    for (int i = 0; i < data.length; i++) {
      result[ri++] = data[i];
      if (i + 1 < data.length && data[i] == 0xFF && data[i + 1] == 0x00) {
        i++; // skip the 0x00
      }
    }
    return result;
  }
}
