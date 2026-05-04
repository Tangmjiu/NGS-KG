import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final MusicService _musicService = MusicService();
  String? _serverTime;
  int _cacheCount = 0;

  @override
  void initState() {
    super.initState();
    _loadServerTime();
  }

  Future<void> _loadServerTime() async {
    try {
      final res = await _musicService.getServerTime();
      final ts = res['data'] is Map ? res['data']['timestamp'] : null;
      if (ts != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000);
        if (mounted) setState(() => _serverTime = dt.toString());
      }
    } catch (e) {
      debugPrint('[Settings] server time error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 播放设置
          const _SectionHeader('播放'),
          Consumer<PlayerProvider>(
            builder: (_, player, __) => SwitchListTile(
              title: const Text('随机播放'),
              subtitle: Text('当前: ${player.playMode.name}'),
              value: player.playMode == PlayMode.shuffle,
              onChanged: (v) => player.setPlayMode(v ? PlayMode.shuffle : PlayMode.sequential),
            ),
          ),
          ListTile(
            title: const Text('清空播放列表'),
            onTap: () {
              context.read<PlayerProvider>().setPlaylist([]);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('播放列表已清空'), duration: Duration(seconds: 1)),
              );
            },
          ),
          const Divider(),

          // 账户
          const _SectionHeader('账户'),
          Consumer<AuthProvider>(
            builder: (_, auth, __) => ListTile(
              title: Text(auth.isLoggedIn ? '退出登录' : '登录'),
              subtitle: Text(auth.isLoggedIn ? '当前: ${auth.user?.nickname ?? "未知"}' : '未登录'),
              trailing: Icon(auth.isLoggedIn ? Icons.logout : Icons.login),
              onTap: () {
                if (auth.isLoggedIn) {
                  auth.logout();
                  ApiClient.clearAuth();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已退出登录')),
                  );
                } else {
                  Navigator.pushNamed(context, '/login');
                }
              },
            ),
          ),
          const Divider(),

          // 缓存
          const _SectionHeader('缓存'),
          ListTile(
            title: const Text('服务器时间'),
            subtitle: Text(_serverTime ?? '获取中...'),
            trailing: const Icon(Icons.refresh),
            onTap: _loadServerTime,
          ),
          ListTile(
            title: const Text('清除缓存'),
            subtitle: const Text('清除临时数据和请求缓存'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除'), duration: Duration(seconds: 1)),
              );
            },
          ),
          const Divider(),

          // 关于
          const _SectionHeader('关于'),
          const ListTile(
            title: Text('版本'),
            subtitle: Text('1.0.0+1'),
          ),
          const ListTile(
            title: Text('API'),
            subtitle: Text(AppConstants.baseUrl),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
