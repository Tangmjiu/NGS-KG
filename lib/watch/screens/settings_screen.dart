// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/quality.dart';
import '../../providers/audio_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_cache_service.dart';
import '../widgets/round_list_tile.dart';
import 'audio_output_screen.dart';
import 'log_export_screen.dart';
import 'login_screen.dart';

class WatchSettingsScreen extends StatefulWidget {
  const WatchSettingsScreen({super.key});
  @override
  State<WatchSettingsScreen> createState() => _WatchSettingsScreenState();
}

class _WatchSettingsScreenState extends State<WatchSettingsScreen> {
  String _cache = '正在读取…';
  bool _clearing = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _readCache();
  }

  Future<void> _readCache() async {
    final revision = ++_revision;
    try {
      final value = await AudioCacheService.instance.getCacheSizeFormatted();
      if (mounted && revision == _revision) setState(() => _cache = value);
    } catch (_) {
      if (mounted && revision == _revision) setState(() => _cache = '大小未知');
    }
  }

  Future<void> _clear() async {
    if (_clearing) return;
    final ok = await _confirm(context, '清除音频缓存？', '缓存的音频将从手表移除。');
    if (!mounted || !ok || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _clearing = true);
    try {
      await AudioCacheService.instance.clearCache();
      if (mounted) await _readCache();
    } catch (_) {
      if (mounted) setState(() => _cache = '清除失败，请重试');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _open(Widget screen) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final quality = context.watch<AudioSettingsProvider>().wifiQuality;
    final avatar = user?.avatarUrl;
    return WatchFlowPage(
      title: '设置',
      children: [
        if (auth.isLoggedIn && user != null) ...[
          RoundListTile(
            title: user.nickname?.isNotEmpty == true ? user.nickname! : '酷狗账号',
            subtitle: user.isVipActive ? 'VIP 会员' : '已登录',
            leading: avatar == null || avatar.isEmpty
                ? const Icon(Icons.account_circle_outlined)
                : ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatar,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.person_outline_rounded),
                    ),
                  ),
          ),
          RoundListTile(
            title: '退出登录',
            leading: const Icon(Icons.logout_rounded),
            onTap: () => confirmWatchLogout(context),
          ),
        ] else
          RoundListTile(
            title: '登录账号',
            leading: const Icon(Icons.account_circle_outlined),
            onTap: () => _open(const WatchLoginScreen()),
          ),
        RoundListTile(
          title: 'Wi-Fi 音质',
          subtitle: Quality.label(quality),
          leading: const Icon(Icons.graphic_eq_rounded),
          onTap: () => _open(const WatchWifiQualityScreen()),
        ),
        RoundListTile(
          title: '音频输出',
          leading: const Icon(Icons.headphones_rounded),
          onTap: () => _open(const WatchAudioOutputScreen()),
        ),
        RoundListTile(
          title: '清除音频缓存',
          subtitle: _clearing ? '正在清除…' : _cache,
          leading: const Icon(Icons.cleaning_services_outlined),
          onTap: _clearing ? null : _clear,
        ),
        RoundListTile(
          title: '导出日志',
          leading: const Icon(Icons.description_outlined),
          onTap: () => _open(const WatchLogExportScreen()),
        ),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String reason) async {
  if (ModalRoute.of(context)?.isCurrent != true) return false;
  return await showDialog<bool>(
        context: context,
        useSafeArea: false,
        animationStyle: AnimationStyle.noAnimation,
        builder: (ctx) => WatchFlowPage(
          title: title,
          center: true,
          children: [
            Text(reason, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                IconButton.filledTonal(
                  tooltip: '取消',
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                IconButton.filled(
                  tooltip: '确认',
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> confirmWatchLogout(BuildContext context) async {
  final ok = await _confirm(context, '退出登录？', '下次收藏歌曲时需要重新登录。');
  if (ok && context.mounted && ModalRoute.of(context)?.isCurrent == true) {
    context.read<AuthProvider>().logout();
  }
}

class WatchWifiQualityScreen extends StatelessWidget {
  const WatchWifiQualityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AudioSettingsProvider>();
    return WatchFlowPage(
      title: 'Wi-Fi 音质',
      children: [
        for (final level in Quality.levels)
          RoundListTile(
            title: Quality.label(level),
            selected: level == settings.wifiQuality,
            trailing: level == settings.wifiQuality
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () async {
              if (ModalRoute.of(context)?.isCurrent != true) return;
              Navigator.pop(context);
              await settings.setWifiQuality(level);
            },
          ),
      ],
    );
  }
}
