import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String? gcId;
  final String? playlistName;

  const PlaylistDetailScreen({
    super.key,
    this.gcId,
    this.playlistName,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gcId = widget.gcId;
      if (gcId != null) {
        context.read<PlaylistProvider>().fetchPlaylistDetail(gcId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Consumer<PlaylistProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = provider.currentPlaylist;
          if (detail == null) {
            return const Center(child: Text('加载失败'));
          }
          if (detail.songs.isEmpty) {
            return const Center(child: Text('暂无歌曲'));
          }

          final pl = detail.playlist;
          final name = pl.name;
          final cover = pl.coverUrl;
          final desc = pl.description;
          final hasDesc = desc != null && desc.isNotEmpty;
          final songCount = detail.songs.length;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: (MediaQuery.of(context).size.height * 0.32).clamp(180, 300),
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cover != null && cover.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: cover.replaceAll('{size}', '500'),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(color: cs.surfaceContainerHighest),
                        )
                      else
                        Container(color: cs.surfaceContainerHighest),
                      // 渐变遮罩
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      // 底部：歌单名 + 歌曲数
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                style: tt.titleLarge
                                    ?.copyWith(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('$songCount 首',
                                style: tt.bodySmall
                                    ?.copyWith(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 播放全部 + 描述
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.queue_music,
                              size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text('$songCount 首',
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              context
                                  .read<PlayerProvider>()
                                  .playSong(detail.songs.first,
                                      playlist: detail.songs);
                            },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('播放全部'),
                          ),
                        ],
                      ),
                      if (hasDesc) ...[
                        const SizedBox(height: 12),
                        Text(desc,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
              ),
              // 歌曲列表
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => SongTile(
                    song: detail.songs[index],
                    onTap: (s) => context
                        .read<PlayerProvider>()
                        .playSong(s, playlist: detail.songs),
                  ),
                  childCount: detail.songs.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}
