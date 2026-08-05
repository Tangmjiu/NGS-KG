import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../theme/theme_assets.dart';
import '../services/music_service.dart';

class CommentsScreen extends StatefulWidget {
  final String type;
  final int id;

  /// 歌单 global_collection_id（type == 'playlist' 时使用，
  /// 文档要求 /comment/playlist 传该格式而非 int listid）
  final String? gcId;

  const CommentsScreen(
      {super.key, required this.type, required this.id, this.gcId});

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
        _comments = await _musicService
            .getPlaylistComments(widget.gcId ?? widget.id.toString());
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, s) {
      Log.e('comments_screen', 'error', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Responsive.isDesktopLayout(context)
          ? null
          : AppBar(
              title: const Text('评论'),
              automaticallyImplyLeading: Responsive.isMobileLayout(context),
            ),
      body: Responsive.constrainedContent(
        context,
        maxWidth: Responsive.maxWidthList,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _comments.isEmpty
                ? emptyStateWidget(
                    ThemeAssets.emptyContent, Icons.comment, '暂无评论')
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage:
                              c.userAvatar != null && c.userAvatar!.isNotEmpty
                                  ? NetworkImage(c.userAvatar!)
                                  : null,
                          child: (c.userAvatar == null || c.userAvatar!.isEmpty)
                              ? const Icon(Icons.person, size: 18)
                              : null,
                        ),
                        title: Text(c.userName ?? '匿名',
                            style: Theme.of(context).textTheme.bodyMedium),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.content,
                                style: Theme.of(context).textTheme.bodyMedium),
                            if (c.time != null)
                              Text(c.time!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline)),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 48,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                  child: Text('${c.likedCount}',
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall)),
                              const Icon(Icons.thumb_up, size: 14),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
