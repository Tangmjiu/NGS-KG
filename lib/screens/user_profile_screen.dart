import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../services/music_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final MusicService _musicService = MusicService();
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _musicService.getUserDetail();
      if (mounted) setState(() => _detail = detail);
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
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                if (user?.userId != null)
                  Center(
                    child: Text('ID: ${user!.userId}',
                        style: TextStyle(color: Colors.grey[400])),
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
                          const Text('账号信息',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _infoRow('昵称', _detail!['nickname']?.toString() ?? ''),
                          _infoRow('性别', _detail!['sex'] == 1 ? '男' : _detail!['sex'] == 2 ? '女' : '未设置'),
                          _infoRow('地区', _detail!['city']?.toString() ?? ''),
                          _infoRow('等级', _detail!['level']?.toString() ?? ''),
                          if (_detail!['birthday']?.toString()?.isNotEmpty == true)
                            _infoRow('生日', _detail!['birthday'].toString()),
                          _infoRow('注册时间', _detail!['reg_time']?.toString() ?? ''),
                        ],
                      ),
                    ),
                  ),
                  if (_detail!['sign']?.toString()?.isNotEmpty == true)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('个人签名',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(_detail!['sign'].toString()),
                          ],
                        ),
                      ),
                    ),
                  Consumer<LikedSongsProvider>(
                    builder: (_, liked, __) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.favorite, color: Colors.red),
                        title: const Text('我喜欢的音乐'),
                        subtitle: Text('${liked.likedIds.length} 首'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
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
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey[400]))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
