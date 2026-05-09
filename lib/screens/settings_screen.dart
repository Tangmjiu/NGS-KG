import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';
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
            onTap: () async {
              await CacheService.instance.clear();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清除'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
          const Divider(),

          // 播放设置
          const _SectionHeader('播放'),
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

  Future<void> _loadInfo() async {
    final cookie = await ApiClient.instance.getCookieString();
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
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/NGS-KG+_Logs');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final timestamp = DateTime.now().toString().replaceAll(':', '-').split('.').first;
      final file = File('${dir.path}/NGS-KG+_log_$timestamp.txt');
      final content = '''
══════════════════════════════════════════
NGS-KG+ Debug Log
══════════════════════════════════════════
Export Time: ${DateTime.now().toIso8601String()}
──────────────────────────────────────────
dfid: $_dfid
token: $_token
userid: $_userId
API: ${AppConstants.baseUrl}
──────────────────────────────────────────
App Version: 1.0.0
Platform: ${Platform.operatingSystem}
──────────────────────────────────────────
''';
      await file.writeAsString(content);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('日志已导出到: Download/NGS-KG+_Logs/'),
        duration: const Duration(seconds: 3),
      ));
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
            title: const Text('导出日志'),
            subtitle: const Text('保存到 Download/NGS-KG+_Logs'),
            onTap: _exportLog,
          ),
        ],
      ),
    );
  }
}
