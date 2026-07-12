import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'shell_navigation_scope.dart';
import '../models/playlist.dart';
import '../providers/playlist_provider.dart';
import '../screens/playlist_detail_screen.dart';
import '../theme/theme_assets.dart';

class PlaylistCard extends StatefulWidget {
  final Playlist playlist;

  const PlaylistCard({super.key, required this.playlist});

  @override
  State<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<PlaylistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _isHovered ? cs.surfaceContainerHigh : Colors.transparent,
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: _isHovered ? 2 : 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final gcId = widget.playlist.globalCollectionId ??
                    'collection_3_${widget.playlist.createUserId}_${widget.playlist.id}_0';
                ShellNavigationScope.navigate(
                  context,
                  routeName: '/playlist/detail',
                  arguments: {
                    'gcId': gcId,
                    'name': widget.playlist.name,
                  },
                  shellPageBuilder: () => PlaylistDetailScreen(
                    gcId: gcId,
                    playlistName: widget.playlist.name,
                  ),
                );
              },
              onLongPress: () {
                showModalBottomSheet(
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
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('确认删除'),
                                content: Text('确定要删除歌单"${widget.playlist.name}"吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final ok = await context
                                          .read<PlaylistProvider>()
                                          .deletePlaylist(widget.playlist.id);
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
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.playlist.coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: widget.playlist.coverUrl!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => ExcludeSemantics(
                                child: Container(
                                    color: cs.surfaceContainerHighest,
                                    width: 64,
                                    height: 64),
                              ),
                              errorWidget: (_, __, ___) => ExcludeSemantics(
                                  child: playlistPlaceholderWidget(size: 40)),
                            )
                          : ExcludeSemantics(
                              child: Container(
                                color: cs.surfaceContainerHighest,
                                width: 64,
                                height: 64,
                                child: playlistPlaceholderWidget(size: 40),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('${widget.playlist.trackCount} 首',
                              style: tt.bodySmall?.copyWith(color: cs.outline)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
