import 'package:flutter/material.dart';
import '../models/artist.dart';
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
          _artists = list.map((e) => Artist.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('歌手')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _artists.isEmpty
              ? const Center(child: Text('暂无数据'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _artists.length,
                  itemBuilder: (_, i) {
                    final artist = _artists[i];
                    return GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/artist/detail',
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
                  },
                ),
    );
  }
}
