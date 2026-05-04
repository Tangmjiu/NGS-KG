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
        if (!auth.isLoggedIn) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('未登录', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('去登录'),
                ),
              ],
            ),
          );
        }
        final user = auth.user!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? const Icon(Icons.person, size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.nickname ?? '用户',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    if (user.userId != null)
                      Text('ID: ${user.userId}',
                          style: TextStyle(color: Colors.grey[400])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('我的歌单',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (playlistProv.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (playlistProv.userPlaylists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('暂无歌单')),
              )
            else
              ...playlistProv.userPlaylists.map(
                  (pl) => PlaylistCard(playlist: pl)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                auth.logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('退出登录'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
            ),
          ],
        );
      },
    );
  }
}
