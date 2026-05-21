import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';

class ArtistFollowedNewsScreen extends StatefulWidget {
  const ArtistFollowedNewsScreen({super.key});

  @override
  State<ArtistFollowedNewsScreen> createState() => _ArtistFollowedNewsScreenState();
}

class _ArtistFollowedNewsScreenState extends State<ArtistFollowedNewsScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _news = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _musicService.getFollowedArtistNews();
      if (mounted) setState(() => _news = list);
    } catch (e, s) { Log.e('artist_followed_news_screen', 'error', e, s); }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关注动态')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _news.isEmpty
              ? const Center(child: Text('暂无动态'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _news.length,
                  itemBuilder: (_, i) {
                    final item = _news[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(item['artist'] as String? ?? ''),
                        subtitle: Text(item['content'] as String? ?? item['title'] as String? ?? ''),
                      ),
                    );
                  },
                ),
    );
  }
}
