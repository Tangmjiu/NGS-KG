import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../utils/logger.dart';
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
              ? const Center(child: Text('暂无评论'))
              : ListView.builder(
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final c = _comments[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundImage: c.userAvatar != null
                            ? NetworkImage(c.userAvatar!)
                            : null,
                        child: c.userAvatar == null
                            ? const Icon(Icons.person, size: 18)
                            : null,
                      ),
                      title: Text(c.userName ?? '匿名',
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.content, style: const TextStyle(fontSize: 14)),
                          if (c.time != null)
                            Text(c.time!,
                                style: TextStyle(
                                    fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                        ],
                      ),
                      trailing: SizedBox(
                        width: 48,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                ),
    );
  }
}
