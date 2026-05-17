import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/auth_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/player_provider.dart';
import '../services/api_client.dart';
import '../services/music_service.dart';
import '../widgets/song_tile.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/user/detail');
      _detail = res.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[UserProfile] load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: Text(user?.nickname ?? '个人主页')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(user?.nickname ?? '未知',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                if (user?.userId != null)
                  Center(
                    child: Text('ID: ${user!.userId}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                if (user?.isVipActive == true)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(user!.vipLevelDisplay,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ),
                const SizedBox(height: 24),
                if (_detail != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('账号信息',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          _infoRow('昵称', _detail!['nickname']?.toString() ?? ''),
                          _infoRow('性别', _detail!['sex'] == 1 ? '男' : _detail!['sex'] == 2 ? '女' : '未设置'),
                          _infoRow('地区', _detail!['city']?.toString() ?? ''),
                          _infoRow('等级', _detail!['level']?.toString() ?? ''),
                          if (_detail!['birthday']?.toString().isNotEmpty == true)
                            _infoRow('生日', _detail!['birthday'].toString()),
                          _infoRow('注册时间', _detail!['reg_time']?.toString() ?? ''),
                        ],
                      ),
                    ),
                  ),
                  if (_detail!['sign']?.toString().isNotEmpty == true)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('个人签名',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(_detail!['sign'].toString()),
                          ],
                        ),
                      ),
                    ),
                  Consumer<LikedSongsProvider>(
                    builder: (_, liked, __) => Card(
                      child: ListTile(
                        leading: Icon(Icons.favorite, color: Theme.of(context).colorScheme.error),
                        title: const Text('我喜欢的音乐'),
                        subtitle: Text('${liked.likedIds.length} 首'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
          ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  final MusicService _musicService = MusicService();
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await _musicService.getPlaylistTracksById(1);
      if (mounted) setState(() => _songs = songs);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我喜欢的音乐')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? const Center(child: Text('暂无收藏'))
              : ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (_, i) {
                    final song = _songs[i];
                    return SongTile(
                      song: song,
                      onTap: (s) => context.read<PlayerProvider>().playSong(s, playlist: _songs),
                    );
                  },
                ),
    );
  }
}
