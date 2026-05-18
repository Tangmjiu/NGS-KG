import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
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
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _album?.name ?? widget.albumName ?? '专辑详情';
    final img = _album?.coverUrl ?? '';
    final artist = _album?.artistName ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.35,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              background: img.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(imageUrl: img.replaceAll('{size}', '500'),
                            fit: BoxFit.cover),
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
                      ],
                    )
                  : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            ),
          ),
          if (artist.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('歌手: $artist', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ),
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
        ],
      ),
    );
  }
}