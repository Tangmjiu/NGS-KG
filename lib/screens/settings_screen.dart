import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/device_service.dart';
import '../services/cache_service.dart';
import '../utils/logger.dart';
import 'log_viewer_screen.dart';
import 'audio_effects_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeChanged;
  final ThemeMode currentTheme;

  const SettingsScreen(
      {super.key, this.onThemeChanged, this.currentTheme = ThemeMode.dark});

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
      final dt = await _musicService.getServerTime();
      if (dt != null && mounted) {
        setState(() => _serverTime = dt.toString());
      }
    } catch (e, s) {
      Log.e('Settings', 'server time error', e, s);
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
          RadioGroup<ThemeMode>(
            groupValue: widget.currentTheme,
            onChanged: (v) {
              final mode = v ?? widget.currentTheme;
              widget.onThemeChanged?.call(mode);
              Navigator.pop(context);
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('跟随系统'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('浅色模式'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('深色模式'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),

          // 账户
          const _SectionHeader('账户'),
          Consumer<AuthProvider>(
            builder: (_, auth, __) => ListTile(
              title: Text(auth.isLoggedIn ? '退出登录' : '登录'),
              subtitle: Text(
                  auth.isLoggedIn ? '当前: ${auth.user?.nickname ?? "未知"}' : '未登录'),
              trailing: Icon(auth.isLoggedIn ? Icons.logout : Icons.login),
              onTap: () {
                if (auth.isLoggedIn) {
                  auth.logout();
                  ApiClient.clearAuth();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('已退出登录')));
                } else {
                  Navigator.pushNamed(context, '/login');
                }
              },
            ),
          ),
          const Divider(),

          // API 服务
          const _SectionHeader('API 服务'),
          const _ApiConfigTile(),
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
              final messenger = ScaffoldMessenger.of(context);
              await CacheService.instance.clear();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('缓存已清除'), duration: Duration(seconds: 1)),
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
                          MaterialPageRoute(
                              builder: (_) => const DeveloperScreen()),
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

// ─── 组件 ───

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              )),
    );
  }
}

/// API 服务器地址配置组件
///
/// 仿 MoeKoeMusic 的设置页面——支持：
/// - 输入自定义 API 地址
/// - 测试连接（调用 /register/dev）
/// - 恢复默认值
class _ApiConfigTile extends StatefulWidget {
  const _ApiConfigTile();
  @override
  State<_ApiConfigTile> createState() => _ApiConfigTileState();
}

class _ApiConfigTileState extends State<_ApiConfigTile> {
  final TextEditingController _urlCtrl = TextEditingController();
  String _currentUrl = '';
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await ApiConfig.instance.getBaseUrl();
    setState(() {
      _currentUrl = url;
      _urlCtrl.text = url;
    });
  }

  Future<void> _testConnection() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final result = await ApiClient.testConnection(url);

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = result['ok'] == true
          ? '连接成功，dfid: ${result['dfid'] ?? '已返回'}'
          : '连接失败: ${result['error'] ?? '未知错误'}';
    });
  }

  Future<void> _saveUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    final err = ApiConfig.validateUrl(url);
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }

    await ApiConfig.instance.setBaseUrl(url);
    ApiClient.instance.reinitialize();

    if (mounted) {
      setState(() => _currentUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API 地址已更新，即时生效')),
      );
    }
  }

  Future<void> _resetToDefault() async {
    await ApiConfig.instance.resetToDefault();
    const defUrl = ApiConfig.defaultBaseUrl;
    setState(() {
      _currentUrl = defUrl;
      _urlCtrl.text = defUrl;
    });
    ApiClient.instance.reinitialize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复默认 API 地址')),
      );
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'API 服务器地址',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _urlCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _urlCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _saveUrl(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.check, size: 20),
                onPressed:
                    _urlCtrl.text.trim() != _currentUrl ? _saveUrl : null,
                tooltip: '保存',
                style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                icon: _testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find, size: 16),
                label: Text(_testing ? '测试中...' : '测试连接'),
                onPressed: _testing ? null : _testConnection,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('恢复默认'),
                onPressed: _resetToDefault,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 6),
            Text(
              _testResult!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _testResult!.startsWith('连接成功')
                        ? Colors.green
                        : Colors.redAccent,
                  ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '当前: $_currentUrl',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── 开发者调试 ───

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  String? _dfid;
  String? _token;
  String? _userId;
  String? _mid;
  String? _guid;
  String? _serverDev;
  String? _apiUrl;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final cookie = await ApiClient.instance.getCookieString();
    final device = await DeviceService.instance.getDeviceInfo();
    final baseUrl = await ApiConfig.instance.getBaseUrl();
    setState(() {
      _dfid = ApiClient.dfid ?? device?.dfid;
      _mid = device?.mid;
      _guid = device?.guid;
      _serverDev = device?.serverDev;
      _apiUrl = baseUrl;
      final tokenMatch = RegExp(r'token=([^;]+)').firstMatch(cookie);
      final userMatch = RegExp(r'userid=([^;]+)').firstMatch(cookie);
      _token = tokenMatch?.group(1);
      _userId = userMatch?.group(1);
    });
  }

  Future<void> _resetDfid() async {
    final device = await DeviceService.instance.registerDevice();
    if (device.isValid) {
      ApiClient.instance.reinitialize();
      _loadInfo();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('设备已重新注册')));
      }
    }
  }

  Future<void> _clearCookie() async {
    ApiClient.clearAuth();
    _loadInfo();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cookie 已清除')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开发者')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('API 地址'),
            subtitle: Text(_apiUrl ?? '未知'),
          ),
          ListTile(
            title: const Text('dfid'),
            subtitle: Text(_dfid ?? '未知'),
          ),
          ListTile(
            title: const Text('mid'),
            subtitle: Text(_mid ?? '未知'),
          ),
          ListTile(
            title: const Text('guid'),
            subtitle: Text(_guid ?? '未知'),
          ),
          ListTile(
            title: const Text('serverDev'),
            subtitle: Text(_serverDev ?? '未知'),
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
            title: const Text('重新注册设备'),
            subtitle: const Text('重置 dfid 及完整设备指纹'),
            onTap: _resetDfid,
          ),
          ListTile(
            title: const Text('清除 Cookie'),
            subtitle: const Text('退出登录并清除认证信息'),
            onTap: _clearCookie,
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('输出日志'),
            subtitle: const Text('实时查看完整日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogViewerScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
