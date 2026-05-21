import 'package:flutter/material.dart';

class LyricLine {
  final Duration time;
  final String text;
  const LyricLine({required this.time, required this.text});
}

class LyricsView extends StatelessWidget {
  final List<LyricLine> lyrics;
  final int currentLine;
  final bool isLoading;
  final bool autoScroll;
  final ScrollController scrollController;
  final ValueChanged<Duration> onTapLine;
  final VoidCallback onResumeAutoScroll;

  const LyricsView({
    super.key,
    required this.lyrics,
    required this.currentLine,
    required this.isLoading,
    required this.autoScroll,
    required this.scrollController,
    required this.onTapLine,
    required this.onResumeAutoScroll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('暂无歌词',
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification && n.dragDetails != null) {
          if (autoScroll) {
            // Notify parent to toggle via callback
            onResumeAutoScroll();
          }
        }
        return false;
      },
      child: Stack(
        children: [
          ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            itemCount: lyrics.length,
            itemBuilder: (_, i) {
              final line = lyrics[i];
              final isCurrent = i == currentLine;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GestureDetector(
                  onTap: () => onTapLine(line.time),
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isCurrent ? 17 : 14,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
          if (!autoScroll)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                heroTag: 'scrollToCurrent',
                onPressed: onResumeAutoScroll,
                child: const Icon(Icons.skip_next, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

List<LyricLine> parseLyrics(String raw) {
  final lines = <LyricLine>[];
  for (final line in raw.split('\n')) {
    final match =
        RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)').firstMatch(line);
    if (match != null) {
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final ms = int.parse(match.group(3)!.padRight(3, '0'));
      final text = match.group(4)?.trim() ?? '';
      if (text.isNotEmpty) {
        lines.add(LyricLine(
          time: Duration(milliseconds: min * 60000 + sec * 1000 + ms),
          text: text,
        ));
      }
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}
