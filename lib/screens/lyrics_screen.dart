import 'dart:convert';
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
  final ScrollController _lyricScrollController = ScrollController();
  List<_LyricLine> _lyrics = [];
  bool _loading = false;
  int _currentLine = 0;
  String? _lastLoadedHash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoad());
  }

  @override
  void dispose() {
    _lyricScrollController.dispose();
    super.dispose();
  }

  void _autoLoad() {
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return;
    if (song.hash != null && song.hash != _lastLoadedHash) {
      _loadLyrics(song.hash!, songName: song.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        if (player.currentSong == null) {
          return const Scaffold(body: Center(child: Text('暂无播放')));
        }
        if (_lyrics.isNotEmpty && player.position.inMilliseconds > 0) {
          _updateCurrentLine(player.position);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(player.currentSong!.name),
            actions: [
              if (_lyrics.isNotEmpty)
                Text('${_currentLine + 1}/${_lyrics.length}',
                    style: const TextStyle(fontSize: 12)),
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

  void _updateCurrentLine(Duration pos) {
    final ms = pos.inMilliseconds;
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (_lyrics[i].time.inMilliseconds <= ms) {
        if (_currentLine != i) {
          _currentLine = i;
          _scrollToCurrentLine();
          if (mounted) setState(() {});
        }
        return;
      }
    }
  }

  void _scrollToCurrentLine() {
    final offset = (_currentLine - 3).clamp(0, _lyrics.length - 1) * 56.0;
    if (_lyricScrollController.hasClients) {
      _lyricScrollController.animateTo(offset,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Widget _buildBody(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(player.currentSong!.name,
                style: tt.headlineSmall),
            const SizedBox(height: 8),
            Text(player.currentSong!.artistDisplay,
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            Text(player.currentSong!.hash == null ? '无歌词信息' : '加载失败'),
            if (player.currentSong!.hash != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadLyrics(player.currentSong!.hash!),
                child: const Text('重新加载'),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _lyricScrollController,
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
                  ? cs.primary
                  : cs.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadLyrics(String hash, {String? songName}) async {
    _loading = true;
    _lastLoadedHash = hash;
    if (mounted) setState(() {});
    try {
      final searchRes = await _musicService.searchLyricByHash(hash, keywords: songName);
      final candidates = searchRes['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = c['id'] as int;
        final key = c['accesskey'] as String? ?? '';
        final content = await _musicService.fetchLyricContent(id, key);
        if (content.isNotEmpty) {
          try {
            String decoded;
            try {
              decoded = utf8.decode(base64Decode(content));
            } catch (_) {
              decoded = content;
            }
            _lyrics = _parseLyrics(decoded);
          } catch (_) {}
        }
      }
    } catch (_) {}
    _loading = false;
    if (mounted) setState(() {});
  }

  List<_LyricLine> _parseLyrics(String raw) {
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
}

class _LyricLine {
  final Duration time;
  final String text;
  const _LyricLine({required this.time, required this.text});
}
