import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';
import 'audio_effects_screen.dart';

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

  void _showSleepTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('睡眠定时', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...[15, 30, 45, 60].map((m) => ListTile(
              title: Text('$m 分钟'),
              onTap: () {
                context.read<PlayerProvider>().setSleepTimer(Duration(minutes: m));
                Navigator.pop(ctx);
              },
            )),
            ListTile(
              title: const Text('当前曲目播放完毕'),
              onTap: () {
                Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('音效'),
            subtitle: const Text('音量、播放速度、均衡器'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioEffectsScreen()),
            ),
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

          // 播放设置
          const _SectionHeader('播放'),
          Consumer<PlayerProvider>(
            builder: (_, player, __) => SwitchListTile(
              title: const Text('跑步模式'),
              subtitle: const Text('播放时保持屏幕常亮'),
              value: player.isKeepScreenOn,
              onChanged: (v) => player.setKeepScreenOn(v),
            ),
          ),
          Consumer<PlayerProvider>(
            builder: (_, player, __) {
              final remaining = player.sleepTimerRemaining;
              return ListTile(
                title: const Text('睡眠定时'),
                subtitle: Text(remaining != null
                    ? '${remaining.inMinutes}分钟后关闭'
                    : '未设置'),
                trailing: remaining != null
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: player.cancelSleepTimer,
                      )
                    : const Icon(Icons.chevron_right),
                onTap: remaining != null ? null : () => _showSleepTimerDialog(context),
              );
            },
          ),
          const Divider(),

          // 关于
          const _SectionHeader('关于'),
          const ListTile(title: Text('版本'), subtitle: Text('1.0.0+1')),
          ListTile(
            title: const Text('开发者'),
            subtitle: const Text('调试功能'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('警告'),
                  content: const Text('此界面仅供调试使用'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DeveloperScreen()),
                        );
                      },
                      child: const Text('继续'),
                    ),
                  ],
                ),
              );
            },
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

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  String? _dfid;
  String? _token;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  void _loadInfo() {
    final cookie = ApiClient.getCookieString();
    setState(() {
      _dfid = ApiClient.dfid;
      final tokenMatch = RegExp(r'token=([^;]+)').firstMatch(cookie);
      final userMatch = RegExp(r'userid=([^;]+)').firstMatch(cookie);
      _token = tokenMatch?.group(1);
      _userId = userMatch?.group(1);
    });
  }

  Future<void> _resetDfid() async {
    final dfid = await MusicService().registerDevice();
    if (dfid.isNotEmpty) {
      ApiClient.setDfid(dfid);
      _loadInfo();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('dfid 已重置')));
    }
  }

  Future<void> _clearCookie() async {
    ApiClient.clearAuth();
    _loadInfo();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cookie 已清除')));
  }

  Future<void> _exportLog() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/debug_log.txt');
      final content = '''
dfid: $_dfid
token: $_token
userid: $_userId
API: ${AppConstants.baseUrl}
''';
      await file.writeAsString(content);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导出到: ${file.path}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开发者')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('dfid'),
            subtitle: Text(_dfid ?? '未知'),
          ),
          ListTile(
            title: const Text('token'),
            subtitle: Text(_token ?? '未登录'),
          ),
          ListTile(
            title: const Text('userid'),
            subtitle: Text(_userId ?? '未登录'),
          ),
          const Divider(),
          ListTile(
            title: const Text('重置 dfid'),
            subtitle: const Text('重新注册设备'),
            onTap: _resetDfid,
          ),
          ListTile(
            title: const Text('清除 Cookie'),
            subtitle: const Text('退出登录并清除认证信息'),
            onTap: _clearCookie,
          ),
          ListTile(
            title: const Text('导出 Log'),
            subtitle: const Text('导出当前调试信息'),
            onTap: _exportLog,
          ),
        ],
      ),
    );
  }
}
