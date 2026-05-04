import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import 'lyrics_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        if (player.currentSong == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('暂无播放')),
          );
        }
        final song = player.currentSong!;
        return Scaffold(
          appBar: AppBar(
            title: Text(song.name),
            actions: [
              IconButton(
                icon: Icon(_showLyrics ? Icons.library_music : Icons.lyrics),
                onPressed: () => setState(() => _showLyrics = !_showLyrics),
              ),
              IconButton(
                icon: const Icon(Icons.comment, size: 20),
                onPressed: () => Navigator.pushNamed(context, '/comments',
                    arguments: {'type': 'music', 'id': song.id}),
              ),
            ],
          ),
          body: _showLyrics
              ? const LyricsScreen()
              : _buildPlayer(player, song),
        );
      },
    );
  }

  Widget _buildPlayer(PlayerProvider player, Song song) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Album art
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: song.albumCoverUrl != null
                ? CachedNetworkImage(
                    imageUrl: song.albumCoverUrl!,
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 280,
                      height: 280,
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, size: 80),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 280,
                      height: 280,
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, size: 80),
                    ),
                  )
                : Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.music_note, size: 80),
                  ),
          ),
          const Spacer(flex: 1),
          // Song info
          Text(song.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(song.artistDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: Colors.grey[400])),
          const SizedBox(height: 24),
          // Progress
          Row(
            children: [
              Text(_formatDuration(player.position),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Expanded(
                child: Slider(
                  value: player.progress.isFinite ? player.progress : 0,
                  onChanged: (v) => player.seek(
                    Duration(milliseconds:
                        (v * player.duration.inMilliseconds).round()),
                  ),
                ),
              ),
              Text(_formatDuration(player.duration),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 16),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_playModeIcon(player.playMode), size: 24),
                onPressed: () {
                  final modes = [
                    PlayMode.sequential,
                    PlayMode.shuffle,
                    PlayMode.repeatOne,
                  ];
                  final next =
                      modes[(modes.indexOf(player.playMode) + 1) % modes.length];
                  player.setPlayMode(next);
                },
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 36),
                onPressed: player.playPrevious,
              ),
              const SizedBox(width: 24),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    player.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 40,
                    color: Colors.black,
                  ),
                  onPressed: player.togglePlayPause,
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 36),
                onPressed: player.playNext,
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.repeat, size: 24),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Quality selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['128K', '320K', 'FLAC']
                .map((q) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(q, style: const TextStyle(fontSize: 11)),
                        selected: q == '128K',
                        onSelected: (_) {},
                        visualDensity: VisualDensity.compact,
                      ),
                    ))
                .toList(),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  IconData _playModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.repeatOne:
        return Icons.repeat_one;
      default:
        return Icons.repeat;
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
