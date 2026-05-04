import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  final MusicService _musicService = MusicService();
  List<_LyricLine> _lyrics = [];
  bool _loading = false;
  int _currentLine = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        if (player.currentSong == null) {
          return const Scaffold(
            body: Center(child: Text('暂无播放')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(player.currentSong!.name),
            actions: [
              if (_lyrics.isNotEmpty)
                Text(
                  '${_currentLine + 1}/${_lyrics.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              IconButton(
                icon: const Icon(Icons.comment, size: 20),
                onPressed: () => Navigator.pushNamed(context, '/comments',
                    arguments: {
                      'type': 'music',
                      'id': player.currentSong!.id,
                    }),
              ),
            ],
          ),
          body: _buildBody(player),
        );
      },
    );
  }

  Widget _buildBody(PlayerProvider player) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(player.currentSong!.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(player.currentSong!.artistDisplay,
                style: TextStyle(fontSize: 16, color: Colors.grey[400])),
            const SizedBox(height: 24),
            const Text('暂无歌词'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadLyrics(player.currentSong!.id),
              child: const Text('加载歌词'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _lyrics.length,
      itemBuilder: (_, i) {
        final line = _lyrics[i];
        final isCurrent = i == _currentLine;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            line.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCurrent ? 18 : 14,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[400],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadLyrics(int songId) async {
    _loading = true;
    setState(() {});
    try {
      final data = await _musicService.getLyric(songId);
      final lyricStr = data['lyric'] as String? ?? '';
      _lyrics = _parseLyrics(lyricStr);
    } catch (_) {}
    _loading = false;
    if (mounted) setState(() {});
  }

  List<_LyricLine> _parseLyrics(String raw) {
    final lines = <_LyricLine>[];
    for (final line in raw.split('\n')) {
      final match = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)').firstMatch(line);
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
}

class _LyricLine {
  final Duration time;
  final String text;
  const _LyricLine({required this.time, required this.text});
}
