import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../widgets/song_tile.dart';
import '../widgets/desktop_song_table.dart';
import '../widgets/desktop_route_wrapper.dart';

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
      if (mounted) setState(() => _isLoading = false);
    }
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
    return DesktopRouteWrapper(
      title: _album?.name ?? widget.albumName ?? '专辑详情',
      actions: [
        IconButton(
          icon: Icon(_isSelecting ? Icons.close : Icons.checklist),
          tooltip: _isSelecting ? '取消选择' : '多选',
          onPressed: _toggleSelectMode,
        ),
      ],
      child: _buildDesktopContent(),
    );
  }

  Widget _buildDesktopContent() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final name = _album?.name ?? widget.albumName ?? '专辑详情';
    final img = _album?.coverUrl ?? '';
    final artist = _album?.artistName ?? '';
    final desc = _album?.description ?? '';

    return Column(
      children: [
        // ── Album info header ──
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: img.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: img.replaceAll('{size}', '240'),
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
                    Text(name, style: tt.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (artist.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(artist, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 4),
                    Text('${_songs.length} 首', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _songs.isEmpty ? null : () {
                        context.read<PlayerProvider>().playSong(_songs.first, playlist: _songs);
                      },
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
            songs: _songs,
            emptyMessage: '暂无歌曲',
            isSelecting: _isSelecting,
            selectedIndices: _selectedIndices,
            onToggleSelection: _toggleSelection,
            onSelectAll: () => _selectAll(_songs.length),
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
      child: const Icon(Icons.album, size: 40),
    );
  }

  Widget _buildMobile() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final name = _album?.name ?? widget.albumName ?? '专辑详情';
    final img = _album?.coverUrl ?? '';
    final artist = _album?.artistName ?? '';
    final desc = _album?.description ?? '';
    final songCount = _songs.length;

    return Scaffold(
      bottomNavigationBar: _isSelecting
          ? _buildSelectionBar(context)
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.35,
            pinned: true,
            title: _isSelecting
                ? Text('已选 ${_selectedIndices.length} 首')
                : null,
            actions: [
              IconButton(
                icon: Icon(_isSelecting ? Icons.close : Icons.checklist),
                tooltip: _isSelecting ? '取消选择' : '多选',
                onPressed: _toggleSelectMode,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (img.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: img.replaceAll('{size}', '500'),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: cs.surfaceContainerHighest),
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
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  if (!_isSelecting)
                    // 专辑封面小图在底部
                    Positioned(
                    left: 16,
                    bottom: 16,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: img.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: img.replaceAll('{size}', '240'),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                style: tt.titleLarge
                                    ?.copyWith(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (artist.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(artist,
                                  style: tt.bodySmall
                                      ?.copyWith(color: Colors.white70)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 专辑信息区
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.album, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('$songCount 首',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const Spacer(),
                  if (!_isSelecting)
                    // 播放全部按钮
                    FilledButton.tonalIcon(
                    onPressed: _songs.isEmpty
                        ? null
                        : () {
                            context
                                .read<PlayerProvider>()
                                .playSong(_songs.first, playlist: _songs);
                          },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('播放全部'),
                  ),
                ],
              ),
            ),
          ),
          // 专辑简介（可收起）
          if (desc.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('专辑简介',
                        style: tt.labelLarge
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      maxLines: _descExpanded ? null : 3,
                      overflow: _descExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (desc.length > 100)
                      GestureDetector(
                        onTap: () => setState(() => _descExpanded = !_descExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _descExpanded ? '收起' : '展开',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // 歌曲列表标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('歌曲列表',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
          // 歌曲列表
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_songs.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('暂无歌曲')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _songs[index];
                  if (_isSelecting) {
                    final selected = _selectedIndices.contains(index);
                    return ListTile(
                      leading: Checkbox(
                        value: selected,
                        onChanged: (_) => _toggleSelection(index),
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
                  return SongTile(
                    song: song,
                    onTap: (s) => context
                        .read<PlayerProvider>()
                        .playSong(s, playlist: _songs),
                  );
                },
                childCount: _songs.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
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
        ],
      ),
    );
  }

  void _batchAddToPlaylist(BuildContext context) {
    final songs =
        _selectedIndices.map((i) => _songs[i]).toList();

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
                                  ? '${s.name}|${s.hash}|${s.albumId}|${s.mixSongId ?? s.id}'
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
}
