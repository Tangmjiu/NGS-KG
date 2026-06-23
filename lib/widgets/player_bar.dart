import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import 'shell_navigation_scope.dart';

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
          onTap: () {
            // Use push (not navigate) so the player opens without DesktopRouteWrapper
            // PlayerScreen/PlayerDesktopView has its own close button
            final scope = ShellNavigationScope.of(context);
            if (scope != null) {
              scope.openInShell(const PlayerScreen());
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.duration.inMilliseconds > 0)
                  LinearProgressIndicator(
                    value: player.progress,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                          Text(song.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                        tooltip: '上一首',
                        constraints: const BoxConstraints(minWidth: 44),
                      ),
                      IconButton(
                        icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: player.togglePlayPause,
                        tooltip: player.isPlaying ? '暂停' : '播放',
                        constraints: const BoxConstraints(minWidth: 44),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 20),
                        onPressed: player.playNext,
                        tooltip: '下一首',
                        constraints: const BoxConstraints(minWidth: 44),
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
