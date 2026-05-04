import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        if (player.currentSong == null) {
          return const SizedBox.shrink();
        }
        final song = player.currentSong!;
        return GestureDetector(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                  top: BorderSide(color: Colors.grey[800]!, width: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.duration.inMilliseconds > 0)
                  LinearProgressIndicator(
                    value: player.progress,
                    backgroundColor: Colors.grey[800],
                    color: Theme.of(context).colorScheme.primary,
                    minHeight: 2,
                  ),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(song.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                    if (player.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else ...[
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 20),
                        onPressed: player.playPrevious,
                      ),
                      IconButton(
                        icon: Icon(player.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow),
                        onPressed: player.togglePlayPause,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 20),
                        onPressed: player.playNext,
                      ),
                    ],
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
