import 'package:flutter_test/flutter_test.dart';

List<_LyricLine> parseLyrics(String raw) {
  final lines = <_LyricLine>[];
  for (final line in raw.split('\n')) {
    final match =
        RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)').firstMatch(line);
    if (match != null) {
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final ms = int.parse(match.group(3)!.padRight(3, '0'));
      final text = match.group(4)?.trim() ?? '';
      if (text.isNotEmpty) {
        lines.add(_LyricLine(
          time: Duration(minutes: min, seconds: sec, milliseconds: ms),
          text: text,
        ));
      }
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

class _LyricLine {
  final Duration time;
  final String text;
  const _LyricLine({required this.time, required this.text});
}

void main() {
  group('Lyrics parser', () {
    test('parses simple LRC format', () {
      final raw = '[00:01.00]Hello\n[00:02.50]World\n';
      final lines = parseLyrics(raw);
      expect(lines.length, 2);
      expect(lines[0].text, 'Hello');
      expect(lines[0].time.inMilliseconds, 1000);
      expect(lines[1].text, 'World');
      expect(lines[1].time.inMilliseconds, 2500);
    });

    test('handles 3-digit milliseconds', () {
      final raw = '[01:30.123]Test\n';
      final lines = parseLyrics(raw);
      expect(lines.length, 1);
      expect(lines[0].time.inMilliseconds, 90123);
    });

    test('sorts by time', () {
      final raw = '[00:03.00]Third\n[00:01.00]First\n[00:02.00]Second\n';
      final lines = parseLyrics(raw);
      expect(lines[0].text, 'First');
      expect(lines[1].text, 'Second');
      expect(lines[2].text, 'Third');
    });

    test('skips metadata lines', () {
      final raw =
          '[ti:Title]\n[ar:Artist]\n[00:01.00]Lyric\n';
      final lines = parseLyrics(raw);
      expect(lines.length, 1);
      expect(lines[0].text, 'Lyric');
    });

    test('ignores empty text', () {
      final raw = '[00:01.00]\n[00:02.00]Text\n';
      final lines = parseLyrics(raw);
      expect(lines.length, 1);
      expect(lines[0].text, 'Text');
    });

    test('returns empty for invalid input', () {
      expect(parseLyrics('').length, 0);
      expect(parseLyrics('no timestamps').length, 0);
    });
  });

  group('Song model', () {
    test('fromTrackJson parses "Artist - Title" format', () {
      // Import and test
    });
  });
}
