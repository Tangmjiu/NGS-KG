import 'package:ym_lyric/model/krc_lyric_line_model.dart';

class TtmlGenerator {
  static String generate(List<KrcLyricLineModel> lines) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
    buffer.writeln('<tt xmlns="http://www.w3.org/ns/ttml" xmlns:itunes="http://music.apple.com/lyric-ttml-internal">');
    buffer.writeln('  <body>');
    buffer.writeln('    <div>');

    var lineIndex = 0;
    for (final line in lines) {
      lineIndex++;
      final lineStart = line.startTime;
      final lineEnd = lineStart + (line.duration > 0 ? line.duration : 0);

      // 词时间卫生: 排序 + 夹紧到行范围。
      // AMLL 渐变动画按词时间递增累加 offset, 乱序/越界时间戳会触发
      // "Offsets must be monotonically non-decreasing" 异常。
      final words = <(int, int, String)>[];
      for (final word in line.line ?? []) {
        final wText = word.word ?? '';
        if (wText.isEmpty) continue;
        final rawStart = word.startTime ?? 0;
        final wDuration = word.duration ?? 0;
        if (wDuration <= 0) continue;
        // KRC 词时间为相对行起点; 超出行范围则视为绝对时间戳
        final isRelative = rawStart >= 0 && rawStart <= line.duration;
        var absStart = isRelative ? lineStart + rawStart : rawStart;
        absStart = absStart.clamp(lineStart, lineEnd);
        final absEnd = (absStart + wDuration).clamp(absStart, lineEnd);
        if (absEnd <= absStart) continue;
        words.add((absStart, absEnd, wText));
      }
      words.sort((a, b) => a.$1.compareTo(b.$1));

      buffer.writeln(
          '      <p begin="${_formatTime(lineStart)}" end="${_formatTime(lineEnd)}" itunes:key="L$lineIndex">');

      for (final w in words) {
        final content = _escapeXml(w.$3);
        buffer.writeln(
            '        <span begin="${_formatTime(w.$1)}" end="${_formatTime(w.$2)}">$content</span>');
      }

      buffer.writeln('      </p>');
    }

    buffer.writeln('    </div>');
    buffer.writeln('  </body>');
    buffer.writeln('</tt>');
    return buffer.toString();
  }

  static String _formatTime(int timeMs) {
    final hours = timeMs ~/ 3600000;
    final minutes = (timeMs % 3600000) ~/ 60000;
    final seconds = (timeMs % 60000) ~/ 1000;
    final milliseconds = timeMs % 1000;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
