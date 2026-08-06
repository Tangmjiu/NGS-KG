import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';

class ArtistListScreen extends StatefulWidget {
  const ArtistListScreen({super.key});

  @override
  State<ArtistListScreen> createState() => _ArtistListScreenState();
}

class _ArtistListScreenState extends State<ArtistListScreen> {
  final MusicService _musicService = MusicService();
  List<Artist> _artists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _musicService.getArtistList();
      if (mounted) {
        setState(() {
          _artists = list;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      Log.e('artist_list_screen', 'error', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_artists.isEmpty) {
      return const Scaffold(body: Center(child: Text('暂无数据')));
    }
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount =
              (constraints.maxWidth / 160).floor().clamp(2, 6);
          return CustomScrollView(
            slivers: [
              const SliverAppBar.large(title: Text('歌手')),
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final artist = _artists[i];
                    return GestureDetector(
                      onTap: () => Navigator.pushNamed(
                          context, '/artist/detail',
                          arguments: {'id': artist.id, 'name': artist.name}),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: artist.picUrl != null
                                ? NetworkImage(artist.picUrl!)
                                : null,
                            child: artist.picUrl == null
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }, childCount: _artists.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
