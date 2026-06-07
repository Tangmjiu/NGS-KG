import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
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
      final news = await _musicService.getFollowedArtistNews();
      if (mounted) setState(() => _news = news);
    } catch (e, s) {
      Log.e('Messages', 'load error', e, s);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 880;
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              _sectionTile(Icons.person_add, '关注歌手消息',
                  subtitle: '${_news.length} 条动态',
                  onTap: () => Navigator.pushNamed(context, '/artist/followed/news')),
              const Divider(),
              _sectionTile(Icons.notifications_outlined, '系统通知',
                  subtitle: '暂无新通知'),
              const Divider(),
              _sectionTile(Icons.favorite_outline, '点赞与收藏',
                  subtitle: '暂无新消息',
                  onTap: () => Navigator.pushNamed(context, '/messages')), // Placeholder
              const Divider(),
              _sectionTile(Icons.video_library, '收藏的视频',
                  onTap: () => Navigator.pushNamed(context, '/videos/favorite')),
              const Divider(),
              _sectionTile(Icons.thumb_up, '喜欢的视频',
                  onTap: () => Navigator.pushNamed(context, '/videos/liked')),
            ],
          );
    return Scaffold(
      appBar: AppBar(title: const Text('消息')),
      body: isWide
          ? Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: body,
            ))
          : body,
    );
  }

  Widget _sectionTile(IconData icon, String title, {String? subtitle, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
