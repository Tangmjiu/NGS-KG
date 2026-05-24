/// A single line of lyrics with timing information.
///
/// Supports both basic LRC timing ([time] + [text]) and Apple Music-style
/// word-level timing via the optional [words] field.
class LyricLine {
  /// The time at which this lyric line starts.
  final Duration time;

  /// The text content of this lyric line.
  final String text;

  /// Optional word-level timing data for this line.
  ///
  /// When non-null, each [LyricWord] provides precise start and end times
  /// for individual words, enabling word-by-word highlighting effects.
  final List<LyricWord>? words;

  /// Creates a lyric line with the given [time] and [text].
  ///
  /// Optional [words] can be supplied for word-level timing support.
  const LyricLine({
    required this.time,
    required this.text,
    this.words,
  });

  /// The display duration of this lyric line.
  ///
  /// Returns `null` by default. Callers should compute this externally
  /// based on the time gap to the next [LyricLine] in the sequence.
  Duration? get lineDuration => null;
}

/// A single word with precise start and end timing for word-level lyric display.
///
/// Used in conjunction with [LyricLine.words] to enable per-word highlighting
/// or karaoke-style effects where each word is animated individually.
class LyricWord {
  /// The word text as it appears in the lyric line.
  final String word;

  /// Start time of this word relative to the song, in milliseconds.
  final int startMs;

  /// End time of this word relative to the song, in milliseconds.
  final int endMs;

  /// Creates a lyric word with precise timing boundaries.
  const LyricWord({
    required this.word,
    required this.startMs,
    required this.endMs,
  });
}

/// Parses raw LRC-format lyrics into a sorted list of [LyricLine] objects.
///
/// The standard LRC format uses lines of the form `[mm:ss.xx]text` where
/// `mm` are minutes, `ss` are seconds, and `xx` are hundredths or thousandths
/// of a second. Lines that do not match this format are silently ignored.
///
/// Lines with empty or whitespace-only text after the timestamp are skipped.
/// All parsed lines are sorted by ascending [LyricLine.time].
///
/// Example input:
/// ```
/// [00:05.00]First line
/// [00:10.50]Second line
/// [00:15.750]Third line with millisecond precision
/// ```
List<LyricLine> parseLyrics(String raw) {
  final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
  final lines = <LyricLine>[];

  for (final match in regex.allMatches(raw)) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final fractional = match.group(3)!;
    final text = match.group(4)!.trim();

    if (text.isEmpty) continue;

    // Normalize fractional part to milliseconds:
    //   2 digits (hundredths) → multiply by 10
    //   3 digits (thousandths) → use directly
    final ms = fractional.length == 2
        ? int.parse(fractional) * 10
        : int.parse(fractional);

    final time = Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: ms,
    );

    lines.add(LyricLine(time: time, text: text));
  }

  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}
