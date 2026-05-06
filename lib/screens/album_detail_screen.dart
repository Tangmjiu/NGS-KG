import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_service.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
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

  Map<String, dynamic>? _album;
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
    final name = _album?['albumname'] as String? ?? widget.albumName ?? '专辑详情';
    final img = _album?['imgurl'] as String? ?? '';
    final artist = _album?['singername'] as String? ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              background: img.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(img.replaceAll('{size}', '500'),
                            fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: Colors.grey[800]),
            ),
          ),
          if (artist.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('歌手: $artist', style: TextStyle(color: Colors.grey[400])),
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