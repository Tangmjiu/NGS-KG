// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表设置页 — 账号 / 音质 / 关于，M3E 胶囊列表

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/audio_settings_provider.dart';
import '../../services/audio_cache_service.dart';
import '../utils/watch_layout.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_scaffold.dart';
import 'login_screen.dart';

/// 手表版设置。
class WatchSettingsScreen extends StatelessWidget {
  const WatchSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    return WatchScaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          layout.listHorizontal,
          4,
          layout.listHorizontal,
          layout.bottomInset + 16,
        ),
        children: const [
          _LoginSection(),
          _AudioSection(),
          _CacheSection(),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _LoginSection extends StatelessWidget {
  const _LoginSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoggedIn && auth.user != null) {
          final user = auth.user!;
          final isVip =
              user.isVipActive || (user.vipType != null && user.vipType! > 0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ClipOval(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person_rounded,
                            size: 28,
                            color: theme.colorScheme.onSurface,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 28,
                          color: theme.colorScheme.onSurface,
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                user.nickname ?? '用户',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                isVip ? 'VIP' : '普通用户',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      isVip ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              RoundListTile(
                title: '退出登录',
                leading: Icon(Icons.logout_rounded,
                    color: theme.colorScheme.error, size: 20),
                onTap: () => auth.logout(),
              ),
            ],
          );
        }
        return RoundListTile(
          title: '登录账号',
          subtitle: '登录后可使用收藏等功能',
          leading: Icon(Icons.login_rounded, color: theme.colorScheme.primary),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WatchLoginScreen()),
          ),
        );
      },
    );
  }
}

class _AudioSection extends StatelessWidget {
  const _AudioSection();

  static const _qualities = ['128', '320', 'high', 'flac'];

  static String _label(String q) => switch (q) {
        '128' => '标准',
        '320' => '高品',
        'high' => '无损',
        'flac' => 'Hi-Res',
        _ => q,
      };

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioSettingsProvider>(
      builder: (context, settings, _) {
        return RoundListTile(
          title: 'WiFi 音质',
          subtitle: _label(settings.wifiQuality),
          leading: const Icon(Icons.graphic_eq_rounded),
          onTap: () {
            final idx = _qualities.indexOf(settings.wifiQuality);
            final next = _qualities[(idx + 1) % _qualities.length];
            settings.setWifiQuality(next);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('WiFi 音质：${_label(next)}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }
}

class _CacheSection extends StatefulWidget {
  const _CacheSection();

  @override
  State<_CacheSection> createState() => _CacheSectionState();
}

class _CacheSectionState extends State<_CacheSection> {
  String _sizeText = '...';

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  Future<void> _refreshSize() async {
    final size = await AudioCacheService.instance.getCacheSizeFormatted();
    if (mounted) setState(() => _sizeText = size);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoundListTile(
      title: '清除音频缓存',
      subtitle: '当前缓存: $_sizeText',
      leading: Icon(Icons.cleaning_services_rounded,
          color: theme.colorScheme.primary, size: 20),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        await AudioCacheService.instance.clearCache();
        _refreshSize();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('缓存已清除'),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return const RoundListTile(
      title: 'NGS-KG+ Watch',
      subtitle: 'v1.5.3-preview-watch · Wear OS / Android 手表',
      leading: Icon(Icons.info_outline_rounded),
    );
  }
}
