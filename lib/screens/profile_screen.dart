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
  Map<String, dynamic>? _vipInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<PlaylistProvider>().fetchUserPlaylist(auth.user?.userId);
        _loadVipInfo();
      }
    });
  }

  Future<void> _loadVipInfo() async {
    try {
      final info = await _musicService.getVipInfo();
      if (mounted) setState(() => _vipInfo = info);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, PlaylistProvider>(
      builder: (_, auth, playlistProv, __) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (auth.isLoggedIn) ...[
              _buildUserHeader(auth, playlistProv),
              const SizedBox(height: 16),
              _buildVipCard(),
              const SizedBox(height: 16),
            ],
            _buildMenuSection(auth),
            if (auth.isLoggedIn) ...[
              const SizedBox(height: 16),
              _buildMyPlaylists(playlistProv),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: auth.logout,
                icon: const Icon(Icons.logout),
                label: const Text('退出登录'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUserHeader(AuthProvider auth, PlaylistProvider playlistProv) {
    final user = auth.user!;
    return Row(
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (user.userId != null)
              Text('ID: ${user.userId}',
                  style: TextStyle(color: Colors.grey[400])),
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
      ],
    );
  }

  Widget _buildVipCard() {
    if (_vipInfo == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VIP 信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.yellow[700])),
            const SizedBox(height: 8),
            Text('类型: ${_vipInfo!['vipType'] ?? _vipInfo!['vip_type'] ?? '-'}'),
            Text('到期: ${_vipInfo!['vipEndTime'] ?? _vipInfo!['vip_end_time'] ?? '-'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(AuthProvider auth) {
    return Column(
      children: [
        Card(
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
                subtitle: Text('扫描设备中的音频文件', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/local/music'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('听歌历史'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/history'),
              ),
              if (auth.isLoggedIn) ...[
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: const Text('云盘'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/cloud'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyPlaylists(PlaylistProvider playlistProv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('我的歌单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (playlistProv.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (playlistProv.userPlaylists.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('暂无歌单')),
          )
        else
          ...playlistProv.userPlaylists.map((pl) => PlaylistCard(playlist: pl)),
      ],
    );
  }
}
