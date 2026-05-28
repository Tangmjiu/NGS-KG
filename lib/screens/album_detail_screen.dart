import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../widgets/song_tile.dart';

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final name = _album?.name ?? widget.albumName ?? '专辑详情';
    final img = _album?.coverUrl ?? '';
    final artist = _album?.artistName ?? '';
    final desc = _album?.description ?? '';
    final songCount = _album?.songCount ?? _songs.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.35,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                            SizedBox(
                              width: MediaQuery.of(context).size.width - 100,
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.titleMedium
                                      ?.copyWith(color: Colors.white)),
                            ),
                            if (artist.isNotEmpty) ...[
                              const SizedBox(height: 2),
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
          // 专辑简介
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
                    Text(desc,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
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
                (context, index) => SongTile(
                  song: _songs[index],
                  onTap: (s) => context
                      .read<PlayerProvider>()
                      .playSong(s, playlist: _songs),
                ),
                childCount: _songs.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
