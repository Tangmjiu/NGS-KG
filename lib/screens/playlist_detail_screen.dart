import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../theme/theme_assets.dart';
import '../utils/responsive.dart';
import '../widgets/song_tile.dart';
import '../widgets/desktop_song_table.dart';
import '../widgets/desktop_route_wrapper.dart';
import '../widgets/shell_navigation_scope.dart';
import 'comments_screen.dart';

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
  bool _isSelecting = false;
  final Set<int> _selectedIndices = {};

  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      if (!_isSelecting) _selectedIndices.clear();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll(int total) {
    setState(() {
      if (_selectedIndices.length == total) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(List.generate(total, (i) => i));
      }
    });
  }

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
    return ResponsiveLayoutBuilder(
      desktop: (_) => _buildDesktop(),
      mobile: (_) => _buildMobile(),
      tablet: (_) => _buildMobile(),
    );
  }

  Widget _buildDesktop() {
    return Consumer<PlaylistProvider>(
      builder: (_, provider, __) {
        return DesktopRouteWrapper(
          title: provider.currentPlaylist?.playlist.name ?? '歌单详情',
          actions: [
            if (!_isSelecting)
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                tooltip: '评论',
                onPressed: () {
                  final pl = provider.currentPlaylist?.playlist;
                  if (pl != null) {
                    ShellNavigationScope.navigate(
                      context,
                      routeName: '/comments',
                      arguments: {'type': 'playlist', 'id': pl.id},
                      shellPageBuilder: () => CommentsScreen(type: 'playlist', id: pl.id),
                    );
                  }
                },
              ),
            IconButton(
              icon: Icon(_isSelecting ? Icons.close : Icons.checklist),
              tooltip: _isSelecting ? '取消选择' : '多选',
              onPressed: _toggleSelectMode,
            ),
          ],
          child: _buildDesktopContent(provider),
        );
      },
    );
  }

  Widget _buildDesktopContent(PlaylistProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = provider.currentPlaylist;
    if (detail == null) {
      return emptyStateWidget(ThemeAssets.loadFailed, Icons.error_outline, '加载失败');
    }
    if (detail.songs.isEmpty) {
      return emptyStateWidget(ThemeAssets.emptyContent, Icons.music_note, '暂无歌曲');
    }

    final pl = detail.playlist;
    final cover = pl.coverUrl;
    final desc = pl.description;
    final hasDesc = desc != null && desc.isNotEmpty;

    return Column(
      children: [
        // ── Playlist info header ──
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: cover != null
                    ? CachedNetworkImage(
                        imageUrl: cover.replaceAll('{size}', '240'),
                        width: 100, height: 100,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _desktopPlaceholder(cs),
                      )
                    : _desktopPlaceholder(cs),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pl.name, style: tt.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${detail.songs.length} 首', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    if (hasDesc) ...[
                      const SizedBox(height: 4),
                      Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => context.read<PlayerProvider>()
                          .playSong(detail.songs.first, playlist: detail.songs),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('播放全部'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── Song table ──
        Expanded(
          child: DesktopSongTable(
            songs: detail.songs,
            emptyMessage: '暂无歌曲',
            isSelecting: _isSelecting,
            selectedIndices: _selectedIndices,
            onToggleSelection: _toggleSelection,
            onSelectAll: () => _selectAll(detail.songs.length),
          ),
        ),
        // ── Selection bar ──
        if (_isSelecting)
          _buildSelectionBar(context),
      ],
    );
  }

  Widget _desktopPlaceholder(ColorScheme cs) {
    return Container(
      width: 100, height: 100,
      color: cs.surfaceContainerHighest,
      child: const Icon(Icons.playlist_play, size: 40),
    );
  }

  Widget _buildMobile() {
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
            return emptyStateWidget(ThemeAssets.loadFailed, Icons.error_outline, '加载失败');
          }
          if (detail.songs.isEmpty) {
            return emptyStateWidget(ThemeAssets.emptyContent, Icons.music_note, '暂无歌曲');
          }

          final pl = detail.playlist;
          final name = pl.name;
          final cover = pl.coverUrl;
          final desc = pl.description;
          final hasDesc = desc != null && desc.isNotEmpty;
          final songCount = detail.songs.length;

          final isWide = MediaQuery.of(context).size.width >= 880;

          Widget mainContent = CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight:
                    MediaQuery.of(context).size.height * 0.32,
                pinned: true,
                title: _isSelecting
                    ? Text('已选 ${_selectedIndices.length} 首')
                    : null,
                actions: [
                  IconButton(
                    icon: Icon(_isSelecting
                        ? Icons.close
                        : Icons.checklist),
                    tooltip:
                        _isSelecting ? '取消选择' : '多选',
                    onPressed: _toggleSelectMode,
                  ),
                  if (!_isSelecting)
                    IconButton(
                      icon: const Icon(Icons.comment_outlined),
                      tooltip: '评论',
                      onPressed: () =>
                        ShellNavigationScope.navigate(
                          context,
                          routeName: '/comments',
                          arguments: {'type': 'playlist', 'id': pl.id},
                          shellPageBuilder: () => CommentsScreen(type: 'playlist', id: pl.id),
                        ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cover != null && cover.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: cover.replaceAll('{size}', '500'),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                              color: cs.surfaceContainerHighest),
                        )
                      else
                        Container(color: cs.surfaceContainerHighest),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              cs.scrim.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      if (!_isSelecting)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.queue_music,
                              size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text('$songCount 首',
                              style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant)),
                          const Spacer(),
                          if (!_isSelecting)
                            FilledButton.tonalIcon(
                              onPressed: () {
                                context
                                    .read<PlayerProvider>()
                                    .playSong(detail.songs.first,
                                        playlist: detail.songs);
                              },
                              icon: const Icon(
                                  Icons.play_arrow, size: 18),
                              label: const Text('播放全部'),
                            ),
                        ],
                      ),
                      if (hasDesc) ...[
                        const SizedBox(height: 12),
                        Text(desc,
                            maxLines: 4, overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
              ),
              // 歌曲列表
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = detail.songs[index];

                    if (_isSelecting) {
                      final selected =
                          _selectedIndices.contains(index);
                      return ListTile(
                        leading: Checkbox(
                          value: selected,
                          onChanged: (_) =>
                              _toggleSelection(index),
                        ),
                        title: Text(song.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(song.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        onTap: () => _toggleSelection(index),
                      );
                    }

                    final tile = SongTile(
                      song: song,
                      onTap: (s) => context
                          .read<PlayerProvider>()
                          .playSong(s,
                              playlist: detail.songs),
                    );
                    return Dismissible(
                      key: ValueKey('pl_song_${song.id}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('移除'),
                            content: Text(
                                '从歌单移除「${song.name}」？'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: const Text('移除'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (_) async {
                        final fileid = song.fileId;
                        if (fileid != null) {
                          try {
                            await MusicService()
                                .removeTracksFromPlaylist(
                                    detail.playlist.id,
                                    fileid.toString());
                            if (context.mounted) {
                              context
                                  .read<PlaylistProvider>()
                                  .fetchPlaylistDetail(
                                      widget.gcId ?? '');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                      content:
                                          Text('移除失败: $e')));
                              context
                                  .read<PlaylistProvider>()
                                  .fetchPlaylistDetail(
                                      widget.gcId ?? '');
                            }
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                                    content: Text(
                                        '无法移除：缺少歌曲标识')));
                          }
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: cs.error,
                        child: Icon(Icons.delete, color: cs.onError),
                      ),
                      child: tile,
                    );
                  },
                  childCount: detail.songs.length,
                ),
              ),
              const SliverToBoxAdapter(
                  child: SizedBox(height: 24)),
            ],
          );

          if (isWide) {
            mainContent = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: mainContent,
              ),
            );
          }
          return mainContent;
        },
      ),
      bottomNavigationBar: _isSelecting
          ? _buildSelectionBar(context)
          : null,
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.read<PlaylistProvider>();
    final detail = provider.currentPlaylist;
    final total = detail?.songs.length ?? 0;
    final count = _selectedIndices.length;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            icon: Icon(
              _selectedIndices.length == total
                  ? Icons.deselect
                  : Icons.select_all,
              size: 18,
            ),
            label: Text(
                _selectedIndices.length == total ? '取消全选' : '全选'),
            onPressed: () => _selectAll(total),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: '添加到歌单',
            onPressed: count == 0
                ? null
                : () => _batchAddToPlaylist(context),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.delete_sweep, color: cs.error),
            tooltip: '删除选中',
            onPressed: count == 0
                ? null
                : () => _batchDelete(context),
          ),
        ],
      ),
    );
  }

  void _batchAddToPlaylist(BuildContext context) {
    final detail =
        context.read<PlaylistProvider>().currentPlaylist;
    if (detail == null) return;
    final songs =
        _selectedIndices.map((i) => detail.songs[i]).toList();

    final playlists =
        context.read<PlaylistProvider>().userPlaylists;
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
              child: Text('添加到歌单 — 共 ${songs.length} 首',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant),
            SizedBox(
              height:
                  (playlists.length * 56.0).clamp(80.0, 320.0),
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
                      try {
                        for (final s in songs) {
                          final data =
                              (s.hash?.isNotEmpty ?? false)
                                  ? '${s.name}|${s.hash}|${s.albumId}|${s.id}'
                                  : s.name;
                          await MusicService()
                              .addTracksToPlaylist(pl.id, data);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                                  content: Text(
                                      '已添加 ${songs.length} 首到「${pl.name}」')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                                  content:
                                      Text('添加失败: $e')));
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

  void _batchDelete(BuildContext context) {
    final detail =
        context.read<PlaylistProvider>().currentPlaylist;
    if (detail == null) return;
    final songs =
        _selectedIndices.map((i) => detail.songs[i]).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: Text('确定从歌单删除选中的 ${songs.length} 首歌曲？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                for (final s in songs) {
                  final fileid = s.fileId;
                  if (fileid != null) {
                    await MusicService().removeTracksFromPlaylist(
                        detail.playlist.id, fileid.toString());
                  }
                }
                if (context.mounted) {
                  _toggleSelectMode();
                  context
                      .read<PlaylistProvider>()
                      .fetchPlaylistDetail(widget.gcId ?? '');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
