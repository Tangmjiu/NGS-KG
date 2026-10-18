// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import '../ui/app_ui.dart';
import '../ui/components/collection_header.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../ui/components/song_tile.dart';
import '../ui/components/player_bottom_padding.dart';
import '../services/api_exception.dart';

class AlbumDetailScreen extends StatefulWidget {
  final int albumId;
  final String? albumName;

  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    this.albumName,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final _musicService = MusicService();

  Album? _album;
  List<Song> _songs = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _descExpanded = false;
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadFailed = false;
      _isLoading = _songs.isEmpty;
      _selectedIndices.clear();
    });
    try {
      _album = await _musicService.getAlbumDetail(widget.albumId);
      final songs = await _musicService.getAlbumSongs(widget.albumId);
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      Log.e('album_detail_screen', 'load error', e, s);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = AppThemeTokens.of(context).pagePadding;
    final name = _album?.name ?? widget.albumName ?? '专辑详情';
    final artist = _album?.artistName ?? '';
    final description = _album?.description ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelecting ? '已选 ${_selectedIndices.length} 首' : '专辑',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_songs.isNotEmpty || _isSelecting)
            IconButton(
                icon:
                    Icon(_isSelecting ? Icons.close : Icons.checklist_rounded),
                tooltip: _isSelecting ? '取消选择' : '多选',
                onPressed: _toggleSelectMode),
        ],
      ),
      bottomNavigationBar: _isSelecting ? _buildSelectionBar(context) : null,
      body: AppPageBody(
          child: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: CollectionHeader(
              title: name,
              kind: '专辑',
              coverUrl: _album?.coverUrl,
              subtitle: [if (artist.isNotEmpty) artist, '${_songs.length} 首歌曲']
                  .join(' · '),
              actions: [
                if (!_isSelecting)
                  FilledButton.icon(
                    onPressed: _songs.isEmpty
                        ? null
                        : () => context
                            .read<PlayerProvider>()
                            .playSong(_songs.first, playlist: _songs),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('播放全部'),
                  )
              ],
            )),
            if (description.isNotEmpty)
              SliverToBoxAdapter(
                  child: Padding(
                padding: EdgeInsets.fromLTRB(inset, 0, inset, 20),
                child: AppSurface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('专辑简介', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      AnimatedSize(
                        duration: AppMotion.dMedium1,
                        alignment: Alignment.topLeft,
                        child: Text(description,
                            maxLines: _descExpanded ? null : 3,
                            overflow: _descExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                      if (description.length > 100)
                        TextButton(
                            onPressed: () =>
                                setState(() => _descExpanded = !_descExpanded),
                            child: Text(_descExpanded ? '收起' : '展开')),
                    ])),
              )),
            if (_isLoading)
              const SliverToBoxAdapter(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: AppLoadingIndicator())))
            else if (_songs.isEmpty)
              SliverToBoxAdapter(
                  child: AppEmptyState(
                icon:
                    _loadFailed ? Icons.cloud_off_rounded : Icons.album_rounded,
                title: _loadFailed ? '专辑暂时无法加载' : '这张专辑暂无歌曲',
                action: _loadFailed
                    ? FilledButton.tonalIcon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试'))
                    : null,
              ))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _songs[index];
                    if (_isSelecting) {
                      final selected = _selectedIndices.contains(index);
                      return StaggeredEntrance(
                        index: index,
                        child: PressScale(
                          child: ListTile(
                            leading: Checkbox(
                              value: selected,
                              onChanged: (_) => _toggleSelection(index),
                            ),
                            title: Text(song.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(song.artistDisplay,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _toggleSelection(index),
                          ),
                        ),
                      );
                    }
                    return StaggeredEntrance(
                      index: index,
                      child: SongTile(
                        song: song,
                        onTap: (s) => context
                            .read<PlayerProvider>()
                            .playSong(s, playlist: _songs),
                      ),
                    );
                  },
                  childCount: _songs.length,
                ),
              ),
            const SliverToBoxAdapter(
                child: PlayerBottomPadding(showLabel: false)),
          ],
        ),
      )),
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _songs.length;
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
        ],
      ),
    );
  }

  void _batchAddToPlaylist(BuildContext context) {
    final songs = _selectedIndices
        .where((i) => i < _songs.length)
        .map((i) => _songs[i])
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
}
