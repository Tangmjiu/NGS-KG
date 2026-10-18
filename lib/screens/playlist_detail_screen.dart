// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import '../ui/app_ui.dart';
import '../ui/components/collection_header.dart';
import '../models/song.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../ui/components/song_tile.dart';
import '../ui/components/player_bottom_padding.dart';
import '../services/api_exception.dart';

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
      if (!mounted) return;
      final gcId = widget.gcId;
      if (gcId != null) {
        context.read<PlaylistProvider>().fetchPlaylistDetail(gcId);
      }
    });
  }

  Future<void> _reload() async {
    final provider = context.read<PlaylistProvider>();
    final id =
        widget.gcId ?? provider.currentPlaylist?.playlist.globalCollectionId;
    if (id == null || id.isEmpty) return;
    setState(_selectedIndices.clear);
    await provider.fetchPlaylistDetail(id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(builder: (context, provider, _) {
      final detail = provider.currentPlaylist;
      final playlist = detail?.playlist;
      final name = playlist?.name.isNotEmpty == true
          ? playlist!.name
          : widget.playlistName ?? '歌单详情';
      final songs = detail?.songs ?? <Song>[];
      return Scaffold(
        appBar: AppBar(
          title: Text(_isSelecting ? '已选 ${_selectedIndices.length} 首' : '歌单',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (songs.isNotEmpty || _isSelecting)
              IconButton(
                icon:
                    Icon(_isSelecting ? Icons.close : Icons.checklist_rounded),
                tooltip: _isSelecting ? '取消选择' : '多选',
                onPressed: _toggleSelectMode,
              ),
            if (!_isSelecting && playlist != null)
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                tooltip: '评论',
                onPressed: () => Navigator.pushNamed(context, '/comments',
                    arguments: {'type': 'playlist', 'id': playlist.id}),
              ),
          ],
        ),
        body: AppPageBody(
            child: RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (provider.isLoading)
                const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: AppLoadingIndicator()))
              else if (detail == null)
                SliverToBoxAdapter(
                    child: AppEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: '歌单暂时无法加载',
                  message: '稍后再试，或下拉重新加载。',
                  action: FilledButton.tonalIcon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试')),
                ))
              else ...[
                SliverToBoxAdapter(
                    child: CollectionHeader(
                  title: name,
                  kind: '歌单',
                  coverUrl: playlist?.coverUrl,
                  fallbackIcon: Icons.queue_music_rounded,
                  subtitle: '${songs.length} 首歌曲',
                  description: playlist?.description,
                  actions: [
                    if (!_isSelecting)
                      FilledButton.icon(
                        onPressed: songs.isEmpty
                            ? null
                            : () => context
                                .read<PlayerProvider>()
                                .playSong(songs.first, playlist: songs),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('播放全部'),
                      ),
                  ],
                )),
                if (songs.isEmpty)
                  const SliverToBoxAdapter(
                      child: AppEmptyState(
                    icon: Icons.queue_music_rounded,
                    title: '歌单里还没有歌曲',
                    message: '找到喜欢的音乐后，可以添加到这里。',
                  ))
                else
                  SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                    final song = songs[index];
                    if (_isSelecting) {
                      return ListTile(
                        leading: Checkbox(
                            value: _selectedIndices.contains(index),
                            onChanged: (_) => _toggleSelection(index)),
                        title: Text(song.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(song.artistDisplay,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _toggleSelection(index),
                      );
                    }
                    return Dismissible(
                      key: ValueKey('pl_song_${song.id}_${song.hash}_$index'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) =>
                          _removeSong(song, detail.playlist.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Icon(Icons.delete_outline_rounded,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer),
                      ),
                      child: SongTile(
                          song: song,
                          onTap: (song) => context
                              .read<PlayerProvider>()
                              .playSong(song, playlist: songs)),
                    );
                  }, childCount: songs.length)),
                const SliverToBoxAdapter(child: PlayerBottomPadding()),
              ],
            ],
          ),
        )),
        bottomNavigationBar: _isSelecting ? _buildSelectionBar(context) : null,
      );
    });
  }

  Future<bool> _removeSong(Song song, int playlistId) async {
    if (song.fileId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法移除：缺少歌曲标识')));
      return false;
    }
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除歌曲'),
        content: Text('从歌单移除「${song.name}」？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('移除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    try {
      await MusicService()
          .removeTracksFromPlaylist(playlistId, song.fileId.toString());
      if (mounted) await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('移除失败：${friendlyError(error)}')));
      }
    }
    // 列表由请求成功后的刷新更新，避免失败时保留已移除的 Dismissible 状态。
    return false;
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
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          TextButton.icon(
            icon: Icon(
              _selectedIndices.length == total
                  ? Icons.deselect
                  : Icons.select_all,
              size: 18,
            ),
            label: Text(_selectedIndices.length == total ? '取消全选' : '全选'),
            onPressed: () => _selectAll(total),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: '添加到歌单',
            onPressed: count == 0 ? null : () => _batchAddToPlaylist(context),
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep, color: cs.error),
            tooltip: '删除选中',
            onPressed: count == 0 ? null : () => _batchDelete(context),
          ),
        ],
      ),
    );
  }

  void _batchAddToPlaylist(BuildContext context) {
    final detail = context.read<PlaylistProvider>().currentPlaylist;
    if (detail == null) return;
    final songs = _selectedIndices
        .where((i) => i < detail.songs.length)
        .map((i) => detail.songs[i])
        .toList();

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
              child: Text('添加到歌单 — 共 ${songs.length} 首',
                  style: Theme.of(context).textTheme.titleSmall),
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
                      try {
                        for (final s in songs) {
                          final data = (s.hash?.isNotEmpty ?? false)
                              ? '${s.name}|${s.hash}|${s.albumId}|${s.id}'
                              : s.name;
                          await MusicService().addTracksToPlaylist(pl.id, data);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text('已添加 ${songs.length} 首到「${pl.name}」')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('添加失败：${friendlyError(e)}')));
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
    final detail = context.read<PlaylistProvider>().currentPlaylist;
    if (detail == null) return;
    final songs = _selectedIndices
        .where((i) => i < detail.songs.length)
        .map((i) => detail.songs[i])
        .toList();

    showAppDialog(
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
                  setState(() {
                    _isSelecting = false;
                    _selectedIndices.clear();
                  });
                  context
                      .read<PlaylistProvider>()
                      .fetchPlaylistDetail(widget.gcId ?? '');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败：${friendlyError(e)}')),
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
