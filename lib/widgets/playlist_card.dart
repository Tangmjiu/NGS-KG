import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../providers/playlist_provider.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';

class PlaylistCard extends StatelessWidget {
  final Playlist playlist;

  const PlaylistCard({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: M3PressScale(
        scaleDown: 0.95,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: AppShape.lg,
          ),
          child: InkWell(
            borderRadius: AppShape.lg,
            onTap: () {
              Navigator.pushNamed(context, '/playlist/detail', arguments: {
                'gcId': playlist.globalCollectionId ??
                    'collection_3_${playlist.createUserId}_${playlist.id}_0',
                'name': playlist.name,
              });
            },
            onLongPress: () {
              showM3ModalBottomSheet(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.delete, color: cs.error),
                        title: Text('删除歌单', style: TextStyle(color: cs.error)),
                        onTap: () {
                          Navigator.pop(context);
                          showM3Dialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('确认删除'),
                              content: Text('确定要删除歌单"${playlist.name}"吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final ok = await context
                                        .read<PlaylistProvider>()
                                        .deletePlaylist(playlist.id);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(ok ? '已删除' : '删除失败')),
                                      );
                                    }
                                  },
                                  child: Text('删除',
                                      style: TextStyle(color: cs.error)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppShape.md,
                    child: playlist.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: playlist.coverUrl!,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => ExcludeSemantics(
                              child: Container(
                                  color: cs.surfaceContainerHighest,
                                  width: 68,
                                  height: 68),
                            ),
                            errorWidget: (_, __, ___) => ExcludeSemantics(
                                child: playlistPlaceholderWidget(size: 44)),
                          )
                        : ExcludeSemantics(
                            child: Container(
                              color: cs.surfaceContainerHighest,
                              width: 68,
                              height: 68,
                              child: playlistPlaceholderWidget(size: 44),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('${playlist.trackCount} 首',
                            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.5), size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
     );
   }
}
