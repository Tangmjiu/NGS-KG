import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';
import 'playing_indicator.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final void Function(Song song)? onTap;

  const SongTile({super.key, required this.song, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final player = context.watch<PlayerProvider>();
    final isCurrent = player.currentSong?.id == song.id;
    final isPlaying = isCurrent && player.isPlaying;

    return Semantics(
      button: true,
      child: M3PressScale(
        scaleDown: 0.96,
        child: AnimatedContainer(
          duration: AppMotion.dShort4,
          curve: AppMotion.emphasized,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isCurrent ? cs.primaryContainer : Colors.transparent,
            borderRadius: AppShape.md,
          ),
          child: InkWell(
            borderRadius: AppShape.md,
            onTap: () => onTap?.call(song),
            onLongPress: () => _showContextMenu(context),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Album Art
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: AppShape.sm,
                        child: song.albumCoverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: song.albumCoverUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _placeholder(cs),
                                errorWidget: (_, __, ___) => _placeholder(cs),
                              )
                            : _placeholder(cs),
                      ),
                      // Playing Indicator Overlay
                      if (isCurrent)
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: AppShape.sm,
                          ),
                          child: Center(
                            child: isPlaying
                                ? const PlayingIndicator(size: 24, color: Colors.white)
                                : const Icon(Icons.pause_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? cs.onPrimaryContainer : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            color: isCurrent 
                                ? cs.onPrimaryContainer.withValues(alpha: 0.8) 
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Trailing Actions
                  Consumer<LikedSongsProvider>(
                    builder: (_, lp, __) {
                      final liked = lp.likedIds.contains(song.id);
                      return M3BounceFeedback(
                        trigger: liked,
                        child: IconButton(
                          icon: Icon(
                            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 24,
                          ),
                          color: liked ? cs.error : (isCurrent ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                          tooltip: liked ? '取消喜欢' : '喜欢',
                          onPressed: () async {
                            final info = SongInfo(
                              id: song.id,
                              name: song.name,
                              hash: song.hash ?? '',
                              albumId: song.albumId,
                              audioId: song.id,
                            );
                            await lp.toggle(info);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      width: 56,
      height: 56,
      child: albumPlaceholderWidget(size: 32),
    );
  }

  void _showContextMenu(BuildContext context) {
    showM3ModalBottomSheet(
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
    return M3PressScale(
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
    showM3ModalBottomSheet(
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
                  return M3StaggeredFadeIn(
                    index: i,
                    child: M3PressScale(
                      child: ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(pl.name),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final data = (song.hash?.isNotEmpty ?? false)
                              ? '${song.name}|${song.hash}|${song.albumId}|${song.id}'
                              : song.name;
                          try {
                            await MusicService().addTracksToPlaylist(pl.id, data);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已添加到歌单')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('添加失败: $e')),
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
