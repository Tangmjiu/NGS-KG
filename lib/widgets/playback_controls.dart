import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final cs = Theme.of(context).colorScheme;
        return LayoutBuilder(
          builder: (_, constraints) {
            final isWide = constraints.maxWidth > 400;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_modeIcon(player.playMode), size: 22),
                  tooltip: '播放模式',
                  color: cs.onSurfaceVariant,
                  onPressed: _modeCycle(player),
                ),
                SizedBox(width: isWide ? 8 : 4),
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 32),
                  tooltip: '上一首',
                  onPressed: player.playPrevious,
                ),
                SizedBox(width: isWide ? 16 : 8),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    heroTag: 'playPause',
                    onPressed: player.togglePlayPause,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.fastOutSlowIn,
                      switchOutCurve: Curves.fastOutSlowIn,
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        key: ValueKey(player.isPlaying),
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isWide ? 16 : 8),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 32),
                  tooltip: '下一首',
                  onPressed: player.playNext,
                ),
                SizedBox(width: isWide ? 8 : 4),
                IconButton(
                  icon: const Icon(Icons.playlist_play, size: 22),
                  tooltip: '播放列表',
                  color: cs.onSurfaceVariant,
                  onPressed: () => showPlaylistStatic(context, player),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.repeatOne:
        return Icons.repeat_one;
      default:
        return Icons.repeat;
    }
  }

  VoidCallback _modeCycle(PlayerProvider player) {
    return () {
      const modes = [PlayMode.sequential, PlayMode.shuffle, PlayMode.repeatOne];
      final next = modes[(modes.indexOf(player.playMode) + 1) % modes.length];
      player.setPlayMode(next);
    };
  }

  static void showPlaylistStatic(BuildContext context, PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('播放列表',
                  style: Theme.of(context).textTheme.titleSmall),
              trailing: Text('${player.playlist.length} 首',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            if (player.playlist.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(32), child: Text('列表为空'))
            else
              SizedBox(
                height: 320,
                child: ListView.builder(
                  itemCount: player.playlist.length,
                  itemBuilder: (_, i) {
                    final s = player.playlist[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: i == player.currentIndex
                            ? cs.primaryContainer
                            : Colors.transparent,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: i == player.currentIndex
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(s.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        s.artistDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                      selected: i == player.currentIndex,
                      selectedTileColor: cs.primaryContainer.withValues(alpha: 40/255),
                      onTap: () {
                        Navigator.pop(context);
                        player.playIndex(i);
                      },
                    );
                  },
                ),
              ),
            Divider(height: 1, color: cs.outlineVariant),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('收藏到歌单'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(context, player);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_sweep, color: cs.error),
              title: Text('清空列表', style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmClear(context, player);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showAddToPlaylist(BuildContext context, PlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Consumer<PlaylistProvider>(
          builder: (_, pp, __) {
            final playlists = pp.userPlaylists;
            if (playlists.isEmpty) {
              return const Padding(
                  padding: EdgeInsets.all(24), child: Text('暂无歌单'));
            }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('收藏到歌单',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  SizedBox(
                    height: (playlists.length * 56.0).clamp(80.0, 320.0),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (_, i) {
                      final pl = playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(pl.name),
                        onTap: () async {
                          Navigator.pop(context);
                          await _addSongToPlaylist(context, pl.id, song);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Future<void> _addSongToPlaylist(
      BuildContext context, int playlistId, Song song) async {
    try {
      final data = (song.hash?.isNotEmpty ?? false)
          ? '${song.name}|${song.hash}|0|${song.id}'
          : song.name;
      await MusicService().addTracksToPlaylist(playlistId, data);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已收藏到歌单')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('收藏失败: $e')));
      }
    }
  }

  static void _confirmClear(BuildContext context, PlayerProvider player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空播放列表吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              player.setPlaylist([]);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
