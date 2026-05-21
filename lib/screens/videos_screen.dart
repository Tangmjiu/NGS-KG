import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';
import '../models/video.dart';
import '../routes/app_routes.dart';

class VideosScreen extends StatefulWidget {
  final bool showLiked;
  const VideosScreen({super.key, this.showLiked = false});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final MusicService _musicService = MusicService();
  List<Video> _videos = [];
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
      if (mounted) {
        setState(() => _videos = list.map((e) => Video.fromJson(e)).toList());
      }
    } catch (e, s) {
      Log.e('Videos', 'load error', e, s);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _playVideo(Video video) {
    Navigator.pushNamed(
      context,
      AppRoutes.mv,
      arguments: {'hash': video.id, 'name': video.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.showLiked ? '喜欢的视频' : '收藏的视频')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? Center(
                  child: Text(
                    widget.showLiked ? '暂无喜欢的视频' : '暂无收藏的视频',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _videos.length,
                  itemBuilder: (_, i) {
                    final v = _videos[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: v.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: v.coverUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _placeholderIcon(theme),
                                  errorWidget: (_, __, ___) => _placeholderIcon(theme),
                                )
                              : _placeholderIcon(theme),
                        ),
                        title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(v.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        trailing: Icon(Icons.play_circle_fill, color: theme.colorScheme.primary),
                        onTap: () => _playVideo(v),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _placeholderIcon(ThemeData theme) {
    return Container(
      width: 60,
      height: 60,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
      child: Icon(Icons.video_library, size: 28, color: theme.colorScheme.primary),
    );
  }
}
