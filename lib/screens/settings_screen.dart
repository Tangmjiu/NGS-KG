import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_settings_provider.dart';
import '../models/song.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/device_service.dart';
import '../services/cache_service.dart';
import '../utils/logger.dart';
import 'log_viewer_screen.dart';
import 'audio_effects_screen.dart';
import 'theme_settings_screen.dart';
import 'about_screen.dart';
import '../widgets/support_me_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 880;
    final body = ListView(
      children: [
          // ── 主题 ──
          const _SectionHeader('主题'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题设置'),
            subtitle: const Text('主题模式、强调色、动态取色'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ThemeSettingsScreen()),
            ),
          ),
          const Divider(),

          // ── 账户 ──
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

          // ── API 服务 ──
          const _SectionHeader('API 服务'),
          const _ApiConfigTile(),
          const Divider(),

          // ── 缓存 ──
          const _SectionHeader('缓存'),
          const _ServerTimeTile(),
          ListTile(
            title: const Text('清除缓存'),
            subtitle: const Text('清除临时数据和请求缓存'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await CacheService.instance.clear();
              if (context.mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('缓存已清除'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
          const Divider(),

          // ── 播放 ──
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

          // ── 音质 ──
          const _SectionHeader('音质'),
          Consumer<AudioSettingsProvider>(
            builder: (_, settings, __) => Column(
              children: [
                _QualityTile(
                  icon: Icons.wifi,
                  label: 'WiFi 网络',
                  value: settings.wifiQuality,
                  onSelected: (key) => settings.setWifiQuality(key),
                ),
                _QualityTile(
                  icon: Icons.signal_cellular_alt,
                  label: '蜂窝网络',
                  value: settings.cellularQuality,
                  onSelected: (key) => settings.setCellularQuality(key),
                ),
                _QualityTile(
                  icon: Icons.download,
                  label: '下载音质',
                  value: settings.downloadQuality,
                  onSelected: (key) => settings.setDownloadQuality(key),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome),
                  title: const Text('智能模式'),
                  subtitle: const Text('WiFi 自动最高音质，蜂窝按设定'),
                  value: settings.smartMode,
                  onChanged: (v) => settings.setSmartMode(v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.history),
                  title: const Text('提交听歌历史'),
                  subtitle: const Text('关闭后不会向服务器上报播放记录'),
                  value: settings.uploadHistory,
                  onChanged: (v) => settings.setUploadHistory(v),
                ),
              ],
            ),
          ),
          const Divider(),

          // ── 支持作者 ──
          const _SectionHeader('支持'),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('支持作者'),
            subtitle: const Text('去 GitHub 点个 star 或者赞助'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showSupportMeDialog(context),
          ),
          const Divider(),

          // ── 关于 ──
          const _SectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于 NGS-KG+'),
            subtitle: const Text('版本 1.0.0+1 · 开源声明'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
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
    );
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: body,
              ),
            )
          : body,
    );
  }

}

// ─── 主题色圆点组件 ───

// ─── 通用组件 ───

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

class _ServerTimeTile extends StatefulWidget {
  const _ServerTimeTile();
  @override
  State<_ServerTimeTile> createState() => _ServerTimeTileState();
}

class _ServerTimeTileState extends State<_ServerTimeTile> {
  final MusicService _musicService = MusicService();
  String? _serverTime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    return ListTile(
      title: const Text('服务器时间'),
      subtitle: Text(_serverTime ?? '获取中...'),
      trailing: const Icon(Icons.refresh),
      onTap: _load,
    );
  }
}

/// API 服务器地址配置组件
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

/// 单行音质选择：标签 + 当前值 + 点击弹出选择
class _QualityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ValueChanged<String> onSelected;

  const _QualityTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final display = Song.qualityLabelMap[value] ?? value;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(display, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('选择 $label 音质',
                    style: Theme.of(ctx).textTheme.titleSmall),
              ),
              ...Song.qualityKeys.map((key) {
                final label = Song.qualityLabelMap[key] ?? key;
                return RadioListTile<String>(
                  title: Text(label),
                  subtitle: Text(_qualityDesc(key)),
                  value: key,
                  groupValue: value,
                  onChanged: (v) {
                    if (v != null) onSelected(v);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static String _qualityDesc(String key) {
    switch (key) {
      case '128': return '约 1 MB/min，最省流量';
      case '320': return '约 2.4 MB/min，音质与流量均衡';
      case 'high': return '无损格式，适合 WiFi 环境';
      case 'viper_clear': return '蝰蛇超清音质增强';
      case 'super': return 'DSD 超高解析，文件较大';
      default: return '';
    }
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
