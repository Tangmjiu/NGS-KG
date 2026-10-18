// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cover_art.dart';
import '../../models/song.dart';
import '../../providers/liked_songs_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/music_service.dart';
import '../app_ui.dart';
import '../../widgets/playing_indicator.dart';
import '../../services/api_exception.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final void Function(Song song)? onTap;

  const SongTile({super.key, required this.song, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final tokens = AppThemeTokens.of(context);
    final state =
        context.select<PlayerProvider, ({bool current, bool playing})>((p) {
      final current = p.currentSong;
      final selected = current != null &&
          (identical(current, song) ||
              (song.id > 0 && current.id == song.id) ||
              (song.hash?.isNotEmpty == true && current.hash == song.hash) ||
              (song.filePath != null && current.filePath == song.filePath));
      return (current: selected, playing: selected && p.isPlaying);
    });
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: tokens.pagePadding, vertical: 3),
      child: Material(
        color: state.current ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.controlRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          onTap: () {
            if (onTap != null) {
              onTap!(song);
            } else {
              context.read<PlayerProvider>().playSong(song);
            }
          },
          onLongPress: () => _showContextMenu(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CoverArt(
                      url: song.thumbnailCoverUrl,
                      coverData: song.coverData,
                      size: 52,
                      borderRadius: 14,
                    ),
                    if (state.current)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: state.playing
                            ? const PlayingIndicator(
                                size: 22, color: Colors.white)
                            : const Icon(Icons.pause_rounded,
                                color: Colors.white),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyLarge?.copyWith(
                            fontWeight: state.current
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: state.current
                                ? colors.onPrimaryContainer
                                : colors.onSurface,
                          )),
                      const SizedBox(height: 3),
                      Text(song.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Selector<LikedSongsProvider, bool>(
                  selector: (_, likes) => likes.likedIds.contains(song.id),
                  builder: (context, liked, _) => IconButton(
                    tooltip: liked ? '取消喜欢' : '喜欢',
                    icon: Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 22),
                    color: liked ? colors.primary : colors.onSurfaceVariant,
                    onPressed: () =>
                        context.read<LikedSongsProvider>().toggle(SongInfo(
                              id: song.id,
                              name: song.name,
                              hash: song.hash ?? '',
                              albumId: song.albumId,
                              audioId: song.id,
                            )),
                  ),
                ),
                IconButton(
                  tooltip: '歌曲选项',
                  icon: const Icon(Icons.more_vert_rounded, size: 22),
                  onPressed: () => _showContextMenu(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showAppBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuItem(
              context,
              icon: Icons.skip_next,
              label: '下一首播放',
              onTap: () {
                Navigator.pop(context);
                context.read<PlayerProvider>().playNextSong(song);
              },
            ),
            _menuItem(
              context,
              icon: Icons.playlist_add,
              label: '添加到歌单',
              onTap: () {
                Navigator.pop(context);
                _addToPlaylist(context);
              },
            ),
            _menuItem(
              context,
              icon: Icons.queue_music,
              label: '加入队列',
              onTap: () {
                Navigator.pop(context);
                context.read<PlayerProvider>().addToQueue(song);
              },
            ),
            if (song.albumId > 0)
              _menuItem(
                context,
                icon: Icons.album,
                label: '查看专辑',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/album/detail', arguments: {
                    'id': song.albumId,
                    'name': song.albumName,
                  });
                },
              ),
            if (song.artistId != null && song.artistId! > 0)
              _menuItem(
                context,
                icon: Icons.person,
                label: '查看歌手',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/artist/detail', arguments: {
                    'id': song.artistId,
                    'name': song.artists.isNotEmpty ? song.artists.first : '',
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return PressScale(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }

  void _addToPlaylist(BuildContext context) {
    final playlists = context.read<PlaylistProvider>().userPlaylists;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无歌单，请先创建')),
      );
      return;
    }
    showAppBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Text('添加到歌单', style: Theme.of(context).textTheme.titleSmall),
            ),
            Divider(
                height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            SizedBox(
              height: (playlists.length * 56.0).clamp(80.0, 320.0),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final pl = playlists[i];
                  return StaggeredEntrance(
                    index: i,
                    child: PressScale(
                      child: ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(pl.name),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final data = (song.hash?.isNotEmpty ?? false)
                              ? '${song.name}|${song.hash}|${song.albumId}|${song.id}'
                              : song.name;
                          try {
                            await MusicService()
                                .addTracksToPlaylist(pl.id, data);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已添加到歌单')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('添加失败：${friendlyError(e)}')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
