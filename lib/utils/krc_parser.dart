import 'dart:convert';
import 'dart:io';

/// KRC 富解析: 在保留逐字时间的基础上, 额外提取词级注音 (phonetic)
/// 与元数据 (标题/歌手/专辑/offset), 供 AMLL TTML 无损转换使用。
/// 与 ym_lyric 的解析器互不干扰 (该解析器丢弃了注音字段)。
class KrcRichWord {
  final String word;
  final String phonetic;
  final int startTime;
  final int duration;

  const KrcRichWord({
    required this.word,
    required this.phonetic,
    required this.startTime,
    required this.duration,
  });
}

class KrcRichLine {
  final int startTime;
  final int duration;
  final List<KrcRichWord> words;

  const KrcRichLine({
    required this.startTime,
    required this.duration,
    required this.words,
  });
}

class KrcRichMeta {
  final String? title;
  final String? artist;
  final String? album;
  final int offsetMs;

  const KrcRichMeta({
    this.title,
    this.artist,
    this.album,
    this.offsetMs = 0,
  });
}

class KrcRichData {
  final List<KrcRichLine> lines;
  final KrcRichMeta meta;

  const KrcRichData({required this.lines, required this.meta});
}

class KrcParser {
  static const List<int> _key = [
    64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105,
  ];

  static const List<int> _krcMagic = [0x6b, 0x72, 0x63, 0x31]; // 'krc1'

  static bool isKrc(List<int> data) {
    if (data.length < 4) return false;
    for (int i = 0; i < 4; i++) {
      if (data[i] != _krcMagic[i]) return false;
    }
    return true;
  }

  /// 解密 KRC 字节流, 返回 UTF-8 明文 (与酷狗官方算法一致: XOR + zlib)。
  static String decrypt(List<int> byteArray) {
    try {
      if (!isKrc(byteArray)) return '';
      final data = byteArray.sublist(4);
      for (int i = 0; i < data.length; i++) {
        data[i] = data[i] ^ _key[i % 16];
      }
      final output = ZLibDecoder().convert(data);
      return utf8.decode(output);
    } catch (_) {
      return '';
    }
  }

  /// 解析 KRC 明文为富数据结构。
  static KrcRichData? parse(List<int> byteArray) {
    final krc = decrypt(byteArray);
    if (krc.isEmpty) return null;
    return parseText(krc);
  }

  /// 直接解析 KRC 明文文本 (便于测试)。
  static KrcRichData? parseText(String krc) {
    if (krc.isEmpty) return null;

    String? title, artist, album;
    var offset = 0, manualoffset = 0;

    for (final match in RegExp(r'\[(\w+):(.+)\]').allMatches(krc)) {
      final value = match.group(2)!.trim();
      switch (match.group(1)) {
        case 'ti':
          title = value;
          break;
        case 'ar':
          artist = value;
          break;
        case 'al':
          album = value;
          break;
        case 'offset':
          offset = int.tryParse(value) ?? 0;
          break;
        case 'manualoffset':
          manualoffset = int.tryParse(value) ?? 0;
          break;
      }
    }

    final lines = <KrcRichLine>[];
    final lineRegExp = RegExp(r'\[(\d+),(\d+)\](.+)');
    // 词文本匹配到下一个 '<' 为止 (KRC 中的 <br/> 等标记自然被排除)
    final wordRegExp = RegExp(r'<(\d+),(\d+),(\d+)>([^<]*)');

    for (final match in lineRegExp.allMatches(krc)) {
      final lineStart = int.parse(match.group(1)!);
      final lineDuration = int.parse(match.group(2)!);
      final words = <KrcRichWord>[];

      for (final wordMatch in wordRegExp.allMatches(match.group(3)!)) {
        final wStart = int.parse(wordMatch.group(1)!);
        final wDuration = int.parse(wordMatch.group(2)!);
        final phonetic = wordMatch.group(3)!;
        final word = wordMatch.group(4)!;
        if (word.isEmpty && phonetic.isEmpty) continue;
        words.add(KrcRichWord(
          word: word,
          phonetic: phonetic,
          startTime: wStart,
          duration: wDuration,
        ));
      }

      lines.add(KrcRichLine(
        startTime: lineStart,
        duration: lineDuration,
        words: words,
      ));
    }

    if (lines.isEmpty) return null;

    return KrcRichData(
      lines: lines,
      meta: KrcRichMeta(
        title: title,
        artist: artist,
        album: album,
        offsetMs: offset + manualoffset,
      ),
    );
  }
}
