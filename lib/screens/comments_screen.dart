import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../utils/logger.dart';
import '../theme/theme_assets.dart';
import '../services/music_service.dart';

class CommentsScreen extends StatefulWidget {
  final String type;
  final int id;

  const CommentsScreen({super.key, required this.type, required this.id});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final MusicService _musicService = MusicService();
  List<Comment> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.type == 'music') {
        _comments = await _musicService.getMusicComments(widget.id);
      } else {
        _comments = await _musicService.getPlaylistComments(widget.id);
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, s) { Log.e('comments_screen', 'error', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('评论')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _comments.isEmpty
              ? emptyStateWidget(ThemeAssets.emptyContent, Icons.comment, '暂无评论')
              : ListView.builder(
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final c = _comments[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundImage: c.userAvatar != null && c.userAvatar!.isNotEmpty
                            ? NetworkImage(c.userAvatar!)
                            : null,
                        child: (c.userAvatar == null || c.userAvatar!.isEmpty)
                            ? const Icon(Icons.person, size: 18)
                            : null,
                      ),
                      title: Text(c.userName ?? '匿名',
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(child: Text('${c.likedCount}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12))),
                          const Icon(Icons.thumb_up, size: 14),
                        ],
                      ),
                    ),
                  );
                },
              );
    return Scaffold(
      appBar: AppBar(title: const Text('评论')),
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: bodyContent,
              ),
            )
          : bodyContent,
    );
  }
}
