import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';
import '../widgets/shell_navigation_scope.dart';
import 'artist_followed_news_screen.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_route_wrapper.dart';

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
                  onTap: () => ShellNavigationScope.navigate(
                    context,
                    routeName: '/artist/followed/news',
                    shellPageBuilder: () => const ArtistFollowedNewsScreen(),
                  )),
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
    return ResponsiveLayoutBuilder(
      desktop: (_) => DesktopRouteWrapper(
        title: '消息',
        maxWidth: 600,
        child: _buildContent(),
      ),
      mobile: (_) => Scaffold(
        appBar: AppBar(title: const Text('消息')),
        body: _buildContent(),
      ),
      tablet: (_) => Scaffold(
        appBar: AppBar(title: const Text('消息')),
        body: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              _sectionTile(Icons.person_add, '关注歌手消息',
                  subtitle: '${_news.length} 条动态',
                  onTap: () => ShellNavigationScope.navigate(
                    context,
                    routeName: '/artist/followed/news',
                    shellPageBuilder: () => const ArtistFollowedNewsScreen(),
                  )),
              const Divider(),
              _sectionTile(Icons.notifications_outlined, '系统通知',
                  subtitle: '暂无新通知'),
              const Divider(),
              _sectionTile(Icons.favorite_outline, '点赞与收藏',
                  subtitle: '暂无新消息',
                  onTap: () => Navigator.pushNamed(context, '/messages')), // Placeholder
              const Divider(),
              // MV:
              // MV: _sectionTile(Icons.video_library, '收藏的视频',
              // MV:     onTap: () => Navigator.pushNamed(context, '/videos/favorite')),
              // MV: const Divider(),
              // MV: _sectionTile(Icons.thumb_up, '喜欢的视频',
              // MV:     onTap: () => Navigator.pushNamed(context, '/videos/liked')),
            ],
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
