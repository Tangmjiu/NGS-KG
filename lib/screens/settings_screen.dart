// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/responsive.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/preview_config.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/cache_service.dart';
import '../services/device_service.dart';
import '../utils/logger.dart';
import 'audio_quality_screen.dart';
import '../widgets/support_me_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../routes/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  bool _closeToTray = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadDesktopSettings();
  }

  Future<void> _loadDesktopSettings() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _closeToTray = prefs.getBool('close_to_tray') ?? true;
        });
      }
    }
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
    final isDesktop = Responsive.isDesktopLayout(context);

    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: const Text('设置')),
      body: Responsive.constrainedContent(
        context,
        maxWidth: Responsive.maxWidthSettings,
        child: ListView(
          padding: isDesktop
              ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
              : EdgeInsets.zero,
          children: [
            if (isDesktop)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '设置中心',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            // ── 账户 ──
            const _SectionHeader('账户'),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => ListTile(
                title: Text(auth.isLoggedIn ? '退出登录' : '登录'),
                subtitle: Text(auth.isLoggedIn
                    ? '当前: ${auth.user?.nickname ?? "未知"}'
                    : '未登录'),
                trailing: Icon(auth.isLoggedIn ? Icons.logout : Icons.login),
                onTap: () {
                  if (auth.isLoggedIn) {
                    auth.logout();
                    ApiClient.clearAuth();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('已退出登录')));
                  } else {
                    Navigator.pushNamed(context, AppRoutes.login);
                  }
                },
              ),
            ),
            Consumer<AudioSettingsProvider>(
              builder: (_, settings, __) => SwitchListTile(
                secondary: const Icon(Icons.history),
                title: const Text('提交听歌历史'),
                subtitle: const Text('关闭后不会向服务器上报播放记录'),
                value: settings.uploadHistory,
                onChanged: (v) => settings.setUploadHistory(v),
              ),
            ),
            const Divider(),

            // ── API 服务 ──
            const _SectionHeader('API 服务'),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('API 服务器'),
              subtitle: const Text('选择服务器路线或自定义地址'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.apiSettings),
            ),
            const Divider(),

            // ── 主题 ──
            const _SectionHeader('主题'),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('主题设置'),
              subtitle: const Text('主题模式、强调色、动态取色'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.themeSettings),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('主题市场'),
              subtitle: const Text('发现、下载、应用社区主题'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.themeMarket),
            ),
            Consumer<ThemeProvider>(
              builder: (_, tp, __) => SwitchListTile(
                secondary: const Icon(Icons.blur_on),
                title: const Text('动态流光'),
                subtitle: const Text('播放器背景根据专辑封面产生流动光效'),
                value: tp.flowLightEnabled,
                onChanged: (v) => tp.setFlowLightEnabled(v),
              ),
            ),
            const Divider(),

            // ── 桌面设置 ──
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
              const _SectionHeader('桌面设置'),
              SwitchListTile(
                secondary: const Icon(Icons.minimize),
                title: const Text('关闭主面板时隐藏到托盘'),
                subtitle: const Text('如果不勾选，关闭主面板将直接退出程序'),
                value: _closeToTray,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('close_to_tray', v);
                  setState(() => _closeToTray = v);
                },
              ),
              const Divider(),
            ],

            // ── 播放与音质 ──
            const _SectionHeader('播放与音质'),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('音效'),
              subtitle: const Text('音量、播放速度、均衡器'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.audioEffects),
            ),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('音质设置'),
              subtitle: const Text('WiFi/蜂窝/下载音质、智能模式'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AudioQualityScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
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

            // ── 关于 ──
            const _SectionHeader('关于'),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于 NGS-KG+'),
              subtitle: Text(
                  '版本 $_appVersion${PreviewConfig.enabled ? ' · preview' : ''} · 开源声明'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.about),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: const Text('支持作者'),
              subtitle: const Text('去 GitHub 点个 star 或者赞助'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showSupportMeDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text('开发者'),
              subtitle: const Text('调试功能'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showM3Dialog(
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
      ),
    );
  }
}

// ─── 通用组件 ───

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
      ),
    );
  }
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
      appBar: AppBar(
        title: const Text('开发者'),
        automaticallyImplyLeading: Responsive.isMobileLayout(context),
      ),
      body: Responsive.constrainedContent(
        context,
        maxWidth: Responsive.maxWidthSettings,
        child: ListView(
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
              onTap: () => Navigator.pushNamed(context, AppRoutes.logViewer),
            ),
          ],
        ),
      ),
    );
  }
}
