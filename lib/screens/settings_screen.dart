import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeChanged;
  final ThemeMode currentTheme;

  const SettingsScreen({super.key, this.onThemeChanged, this.currentTheme = ThemeMode.dark});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final MusicService _musicService = MusicService();
  String? _serverTime;

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
          // 主题
          const _SectionHeader('主题'),
          RadioListTile<ThemeMode>(
            title: const Text('跟随系统'),
            value: ThemeMode.system,
            groupValue: widget.currentTheme,
            onChanged: (v) { widget.onThemeChanged?.call(v!); Navigator.pop(context); },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('浅色模式'),
            value: ThemeMode.light,
            groupValue: widget.currentTheme,
            onChanged: (v) { widget.onThemeChanged?.call(v!); Navigator.pop(context); },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('深色模式'),
            value: ThemeMode.dark,
            groupValue: widget.currentTheme,
            onChanged: (v) { widget.onThemeChanged?.call(v!); Navigator.pop(context); },
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
          const ListTile(title: Text('版本'), subtitle: Text('1.0.0+1')),
          const ListTile(title: Text('API'), subtitle: Text(AppConstants.baseUrl)),
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
