// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../ui/app_ui.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/preview_config.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/cache_service.dart';
import '../services/device_service.dart';
import 'audio_quality_screen.dart';
import '../widgets/support_me_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {
      // 静默失败
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: ListView(
            padding: EdgeInsets.fromLTRB(tokens.pagePadding, 16,
                tokens.pagePadding, 40 + MediaQuery.paddingOf(context).bottom),
            children: [
              const AppPageHeader(
                padding: EdgeInsets.zero,
                title: '设置',
                subtitle: '让每一次聆听都更合心意',
                showBack: true,
              ),
              SizedBox(height: tokens.sectionSpacing),
              _SettingsSection(
                title: '账号与隐私',
                children: [
                  Consumer<AuthProvider>(
                    builder: (_, auth, __) => ListTile(
                      leading: Icon(auth.isLoggedIn
                          ? Icons.person_outline_rounded
                          : Icons.login_rounded),
                      title: Text(auth.isLoggedIn ? '退出登录' : '登录音乐账号'),
                      subtitle: Text(auth.isLoggedIn
                          ? '当前账号：${auth.user?.nickname ?? "未知"}'
                          : '同步收藏、歌单与云盘'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        if (auth.isLoggedIn) {
                          auth.logout();
                          ApiClient.clearAuth();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已退出登录')));
                        } else {
                          Navigator.pushNamed(context, '/login');
                        }
                      },
                    ),
                  ),
                  Consumer<AudioSettingsProvider>(
                    builder: (_, settings, __) => SwitchListTile(
                      secondary: const Icon(Icons.history_rounded),
                      title: const Text('提交听歌历史'),
                      subtitle: const Text('将播放记录同步到音乐账号'),
                      value: settings.uploadHistory,
                      onChanged: settings.setUploadHistory,
                    ),
                  ),
                ],
              ),
              _SettingsSection(
                title: '外观与主题',
                children: [
                  _navigationTile(
                    icon: Icons.palette_outlined,
                    title: '主题与外观',
                    subtitle: '主题包、配色与明暗模式',
                    route: '/settings/theme',
                  ),
                  _navigationTile(
                    icon: Icons.storefront_outlined,
                    title: '主题市场',
                    subtitle: '发现和应用社区主题',
                    route: '/settings/theme/market',
                  ),
                  Consumer<ThemeProvider>(
                    builder: (_, theme, __) => SwitchListTile(
                      secondary: const Icon(Icons.blur_on_rounded),
                      title: const Text('动态流光'),
                      subtitle: const Text('让播放器背景随专辑封面流动'),
                      value: theme.flowLightEnabled,
                      onChanged: theme.setFlowLightEnabled,
                    ),
                  ),
                ],
              ),
              _SettingsSection(
                title: '播放与声音',
                children: [
                  _navigationTile(
                    icon: Icons.tune_rounded,
                    title: '音效',
                    subtitle: '音量、播放速度与均衡器',
                    route: '/settings/audio/effects',
                  ),
                  ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: const Text('音质设置'),
                    subtitle: const Text('无线网络、移动网络与下载音质'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AudioQualityScreen(),
                        )),
                  ),
                ],
              ),
              _SettingsSection(
                title: '连接与存储',
                children: [
                  _navigationTile(
                    icon: Icons.dns_outlined,
                    title: 'API 服务器',
                    subtitle: '选择服务器线路或自定义地址',
                    route: '/settings/api',
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('清除缓存'),
                    subtitle: const Text('清理临时数据和请求缓存'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await CacheService.instance.clear();
                      if (context.mounted) {
                        messenger.showSnackBar(const SnackBar(
                          content: Text('缓存已清除'),
                          duration: Duration(seconds: 1),
                        ));
                      }
                    },
                  ),
                ],
              ),
              _SettingsSection(
                title: '关于与支持',
                children: [
                  _navigationTile(
                    icon: Icons.info_outline_rounded,
                    title: '关于 NGS-KG+',
                    subtitle:
                        '版本 $_appVersion${PreviewConfig.enabled ? ' · preview' : ''} · 开源声明',
                    route: '/about',
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite_outline_rounded),
                    title: const Text('支持作者'),
                    subtitle: const Text('关注项目或支持持续开发'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showSupportMeDialog(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.terminal_rounded),
                    title: const Text('开发者工具'),
                    subtitle: const Text('设备信息与调试日志'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openDeveloperTools,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.pushNamed(context, route),
      );

  void _openDeveloperTools() {
    showAppDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('开发者工具'),
        content: const Text('此界面用于诊断与调试，修改设备信息可能影响登录状态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DeveloperScreen(),
                  ));
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: AppThemeTokens.of(context).sectionSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(padding: EdgeInsets.zero, title: title),
            const SizedBox(height: 12),
            AppSurface(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: children),
            ),
          ],
        ),
      );
}

// ─── 音质子页面（独立为 audio_quality_screen.dart）

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
    if (!mounted) return;
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
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: AppPageBody(
          child: ListView(
            padding: EdgeInsets.all(tokens.pagePadding),
            children: [
              const AppPageHeader(
                padding: EdgeInsets.zero,
                title: '开发者工具',
                subtitle: '诊断连接与设备状态',
                showBack: true,
              ),
              SizedBox(height: tokens.sectionSpacing),
              _SettingsSection(
                title: '连接信息',
                children: [
                  for (final field in [
                    ('API 地址', _apiUrl),
                    ('dfid', _dfid),
                    ('mid', _mid),
                    ('guid', _guid),
                    ('serverDev', _serverDev),
                    ('token', _token),
                    ('userid', _userId),
                  ])
                    ListTile(
                      title: Text(field.$1),
                      subtitle: SelectableText(field.$2 ?? '暂无数据'),
                    ),
                ],
              ),
              _SettingsSection(
                title: '调试操作',
                children: [
                  ListTile(
                    leading: const Icon(Icons.devices_rounded),
                    title: const Text('重新注册设备'),
                    subtitle: const Text('重置 dfid 及完整设备指纹'),
                    onTap: _resetDfid,
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('清除 Cookie'),
                    subtitle: const Text('退出登录并清除认证信息'),
                    onTap: _clearCookie,
                  ),
                  ListTile(
                    leading: const Icon(Icons.terminal_rounded),
                    title: const Text('输出日志'),
                    subtitle: const Text('实时查看完整日志'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings/developer/log'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
