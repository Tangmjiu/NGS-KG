import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';
import '../theme/theme_assets.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final void Function(Song song)? onTap;

  const SongTile({super.key, required this.song, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: MergeSemantics(
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: song.albumCoverUrl != null
                ? CachedNetworkImage(
                    imageUrl: song.albumCoverUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ExcludeSemantics(
                      child: Container(
                          color: cs.surfaceContainerHighest,
                          width: 48,
                          height: 48),
                    ),
                    errorWidget: (_, __, ___) => ExcludeSemantics(
                        child: albumPlaceholderWidget(size: 32)),
                  )
                : ExcludeSemantics(
                    child: Container(
                      color: cs.surfaceContainerHighest,
                      width: 48,
                      height: 48,
                      child: albumPlaceholderWidget(size: 32),
                    ),
                  ),
          ),
          title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.artistDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<LikedSongsProvider>(
                builder: (_, lp, __) {
                  final liked = lp.likedIds.contains(song.id);
                  return IconButton(
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                    ),
                    color: liked ? Colors.red : cs.onSurfaceVariant,
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
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_outline, size: 24),
                tooltip: '播放',
                onPressed: () => onTap?.call(song),
              ),
            ],
          ),
          onTap: () => onTap?.call(song),
          onLongPress: () => _showContextMenu(context),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
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
          ],
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
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
    showModalBottomSheet(
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
                  return ListTile(
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
