import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';

class SongInfoProgress extends StatefulWidget {
  final Song song;

  const SongInfoProgress({super.key, required this.song});

  @override
  State<SongInfoProgress> createState() => _SongInfoProgressState();
}

class _SongInfoProgressState extends State<SongInfoProgress> {
  bool _isDragging = false;
  double _dragProgress = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final label = Song.qualityLabels[player.qualityLevel % Song.qualityLabels.length];
        final progress = _isDragging
            ? _dragProgress
            : (player.progress.isFinite ? player.progress : 0.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Song name + quality badge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.song.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildQualityBadge(cs, label, () => _showQualitySelector(context, player)),
                ],
              ),
              const SizedBox(height: 12),
              // Progress
              Row(
                children: [
                  Text(_formatDuration(player.position),
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          activeTrackColor: cs.primary,
                          inactiveTrackColor: cs.surfaceContainerHighest,
                          thumbColor: cs.primary,
                          overlayColor: cs.primary.withValues(alpha: 25/255),
                        ),
                        child: Slider(
                          value: progress,
                          onChangeStart: (_) => setState(() => _isDragging = true),
                          onChangeEnd: (v) {
                            _isDragging = false;
                            player.seek(Duration(
                                milliseconds: (v * player.duration.inMilliseconds).round()));
                          },
                          onChanged: (v) => setState(() => _dragProgress = v),
                        ),
                      ),
                    ),
                  ),
                  Text(_formatDuration(player.duration),
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 4),
              // Like button
              Align(
                alignment: Alignment.centerRight,
                child: Consumer<LikedSongsProvider>(
                  builder: (_, liked, __) => IconButton(
                    icon: Icon(
                      liked.likedIds.contains(widget.song.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 22,
                    ),
                    tooltip: liked.likedIds.contains(widget.song.id) ? '取消收藏' : '收藏',
                    color: liked.likedIds.contains(widget.song.id)
                        ? cs.error
                        : cs.onSurfaceVariant,
                    onPressed: () => liked.toggle(SongInfo(
                      id: widget.song.id,
                      name: widget.song.name,
                      hash: widget.song.hash ?? '',
                      albumId: widget.song.albumId,
                      audioId: widget.song.id,
                    )),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQualityBadge(ColorScheme cs, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white38),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ),
      ),
    );
  }

  void _showQualitySelector(BuildContext context, PlayerProvider player) {
    final q = player.currentSong?.qualities;
    if (q == null || q.isEmpty) return;
    const labels = ['标准 (128k)', 'HQ (320k)', '无损 (FLAC)'];
    const keys = ['128', '320', 'high'];
    final available = <int>[];
    for (int i = 0; i < keys.length; i++) {
      if (q.containsKey(keys[i])) available.add(i);
    }
    if (available.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('音质选择',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ...available.map((i) => ListTile(
              leading: Icon(
                i == 0 ? Icons.sd : i == 1 ? Icons.hd : Icons.album,
                color: player.isCurrentQuality(keys[i])
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(labels[i]),
              trailing: player.isCurrentQuality(keys[i])
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                player.setQualityIndex(i);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00';
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
