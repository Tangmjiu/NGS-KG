import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/playlist_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
            if (auth.isLoggedIn) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: auth.user!.avatarUrl != null
                        ? NetworkImage(auth.user!.avatarUrl!)
                        : null,
                    child: auth.user!.avatarUrl == null
                        ? const Icon(Icons.person, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.user!.nickname ?? '用户',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      if (auth.user!.userId != null)
                        Text('ID: ${auth.user!.userId}',
                            style: TextStyle(color: Colors.grey[400])),
                      if (auth.user!.isVipActive)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            auth.user!.vipLevelDisplay,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('我的歌单',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (playlistProv.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (playlistProv.userPlaylists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('暂无歌单')),
                )
              else
                ...playlistProv.userPlaylists
                    .map((pl) => PlaylistCard(playlist: pl)),
            ] else ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 60, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('未登录', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: const Text('去登录'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.audiotrack),
                title: const Text('本地音乐'),
                subtitle: Text('扫描设备中的音频文件',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/local/music'),
              ),
            ),
            if (auth.isLoggedIn) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: auth.logout,
                icon: const Icon(Icons.logout),
                label: const Text('退出登录'),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
              ),
            ],
          ],
        );
      },
    );
  }
}
