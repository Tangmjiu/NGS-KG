import 'package:flutter/material.dart';
import '../services/music_service.dart';

class VideosScreen extends StatefulWidget {
  final bool showLiked;
  const VideosScreen({super.key, this.showLiked = false});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = widget.showLiked
          ? await _musicService.getLikedVideos()
          : await _musicService.getFavoriteVideos();
      if (mounted) setState(() => _videos = list);
    } catch (e) {
      debugPrint('[Videos] load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.showLiked ? '喜欢的视频' : '收藏的视频')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? Center(child: Text(widget.showLiked ? '暂无喜欢的视频' : '暂无收藏的视频',
                  style: TextStyle(color: Colors.grey[400])))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _videos.length,
                  itemBuilder: (_, i) {
                    final v = _videos[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.video_library, color: Colors.blue),
                        title: Text(v['name'] as String? ?? v['title'] as String? ?? ''),
                        subtitle: Text(v['author'] as String? ?? '',
                            style: TextStyle(color: Colors.grey[400])),
                      ),
                    );
                  },
                ),
    );
  }
}
