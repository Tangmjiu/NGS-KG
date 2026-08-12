// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import '../utils/app_icons.dart';
import '../utils/theme.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/preview_config.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';
import '../routes/app_routes.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ── 账户 ──
          const _SectionHeader('账户'),
          Consumer<AuthProvider>(
            builder: (_, auth, __) => ListTile(
              title: Text(auth.isLoggedIn ? '退出登录' : '登录'),
              subtitle: Text(auth.isLoggedIn
                  ? '当前: ${auth.user?.nickname ?? "未知"}'
                  : '未登录'),
              trailing:
                  Icon(auth.isLoggedIn ? AppIcons.logout : AppIcons.login),
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
          Consumer<AudioSettingsProvider>(
            builder: (_, settings, __) => SwitchListTile(
              secondary: const Icon(AppIcons.history),
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
            leading: const Icon(AppIcons.dns),
            title: const Text('API 服务器'),
            subtitle: const Text('选择服务器路线或自定义地址'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => Navigator.pushNamed(context, '/settings/api'),
          ),
          const Divider(),

          // ── 主题 ──
          const _SectionHeader('主题'),
          ListTile(
            leading: const Icon(AppIcons.palette),
            title: const Text('主题设置'),
            subtitle: const Text('主题模式、强调色、动态取色'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => Navigator.pushNamed(context, '/settings/theme'),
          ),
          ListTile(
            leading: const Icon(AppIcons.storefront),
            title: const Text('主题市场'),
            subtitle: const Text('发现、下载、应用社区主题'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => Navigator.pushNamed(context, '/settings/theme/market'),
          ),
          Consumer<ThemeProvider>(
            builder: (_, tp, __) => SwitchListTile(
              secondary: const Icon(AppIcons.blurOn),
              title: const Text('动态流光'),
              subtitle: const Text('播放器背景根据专辑封面产生流动光效'),
              value: tp.flowLightEnabled,
              onChanged: (v) => tp.setFlowLightEnabled(v),
            ),
          ),
          const Divider(),

          // ── 播放与音质 ──
          const _SectionHeader('播放与音质'),
          ListTile(
            leading: const Icon(AppIcons.tune),
            title: const Text('音效'),
            subtitle: const Text('音量、播放速度、均衡器'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/audio/effects'),
          ),
          ListTile(
            leading: const Icon(AppIcons.speed),
            title: const Text('音质设置'),
            subtitle: const Text('WiFi/蜂窝/下载音质、智能模式'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => Navigator.pushNamed(context, AppRoutes.audioQuality),
          ),
          ListTile(
            leading: const Icon(AppIcons.cleaningServices),
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
            leading: const Icon(AppIcons.info),
            title: const Text('关于 NGS-KG+'),
            subtitle: Text(
                '版本 $_appVersion${PreviewConfig.enabled ? ' · preview' : ''} · 开源声明'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
          ListTile(
            leading: const Icon(AppIcons.favoriteBorder),
            title: const Text('支持作者'),
            subtitle: const Text('去 GitHub 点个 star 或者赞助'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => showSupportMeDialog(context),
          ),
          // 开发者工具（仅 Debug/Profile 构建可见，Release 自动隐藏）
          // 新增功能：开发者工具入口
          if (!kReleaseMode)
            ListTile(
              leading: const Icon(AppIcons.terminal),
              title: const Text('开发者'),
              subtitle: const Text('调试功能'),
              trailing: const Icon(AppIcons.chevronRight),
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
                          Navigator.pushNamed(context, AppRoutes.developer);
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

// ─── 音质子页面（独立为 audio_quality_screen.dart）
