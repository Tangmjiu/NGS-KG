import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';
import '../widgets/playlist_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final MusicService _musicService = MusicService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<PlaylistProvider>().fetchUserPlaylist(auth.user?.userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, PlaylistProvider>(
      builder: (_, auth, playlistProv, __) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (auth.isLoggedIn) _buildUserHeader(auth),
            const SizedBox(height: 16),
            _buildMenu(auth),
            const SizedBox(height: 16),
            if (auth.isLoggedIn) _buildPlaylists(playlistProv, auth),
          ],
        );
      },
    );
  }

  Widget _buildUserHeader(AuthProvider auth) {
    final user = auth.user!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/user/profile'),
              child: CircleAvatar(
                radius: 32,
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null ? const Icon(Icons.person, size: 32) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.nickname ?? '用户',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (user.userId != null)
                    Text('ID: ${user.userId}', style: TextStyle(color: Colors.grey[400])),
                  if (user.isVipActive)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(user.vipLevelDisplay,
                          style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(AuthProvider auth) {
    return Card(
      child: Column(
        children: [
          if (!auth.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('登录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/login'),
            ),
          ListTile(
            leading: const Icon(Icons.audiotrack),
            title: const Text('本地音乐'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/local/music'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('听歌历史'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('消息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/messages'),
          ),
          if (auth.isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('云盘'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/cloud'),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylists(PlaylistProvider playlistProv, AuthProvider auth) {
    if (playlistProv.isLoading) return const Center(child: CircularProgressIndicator());

    final List<dynamic> personal = [];
    final List<dynamic> collected = [];
    final userId = auth.user?.userId;

    for (final pl in playlistProv.userPlaylists) {
      // API doesn't directly tell us ownership, use a heuristic:
      // personal playlists tend to be created by the user
      // For now, show all as "my playlists" since the API separates by list vs collect counts
      personal.add(pl);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (personal.isNotEmpty) ...[
          const Text('我的歌单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...personal.map((pl) => PlaylistCard(playlist: pl)),
        ],
        if (collected.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('收藏的歌单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...collected.map((pl) => PlaylistCard(playlist: pl)),
        ],
        if (personal.isEmpty && collected.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('暂无歌单')),
          ),
      ],
    );
  }
}
