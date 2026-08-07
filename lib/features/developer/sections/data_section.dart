// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_config.dart';
import '../../../services/cache_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/theme.dart';
import '../export_service.dart';
import 'section_card.dart';

/// 数据与存储分组
///
/// - 清除缓存（请求缓存 + 图片缓存，二次确认）
/// - 重置所有设置（恢复默认，二次确认；保留设备注册与登录数据）
/// - 导出应用数据（JSON + 分享面板）
// 新增功能：数据与存储
class DataSection extends StatelessWidget {
  const DataSection({super.key});

  /// 可安全重置的设置键前缀（theme_/audio_/api_ + mjiutang_route）
  ///
  /// 注意：device_info（设备注册指纹）与登录数据**不在**重置范围，
  /// 避免导致设备失效或登录状态丢失。
  static const List<String> _resetPrefixes = [
    'theme_',
    'audio_',
    'api_',
  ];

  static const List<String> _resetExactKeys = ['mjiutang_route'];

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showM3Dialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('将清除请求缓存与图片缓存（不影响登录与设置），确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await CacheService.instance.clear();
    // 图片内存缓存
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    Log.i('DEVTOOLS', '缓存已清除（请求缓存 + 图片缓存）');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('缓存已清除'),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _resetSettings(BuildContext context) async {
    final confirmed = await showM3Dialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置所有设置'),
        content: const Text('将恢复主题、音质、API 等所有设置为默认值（保留设备注册与登录），确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('重置'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    var removed = 0;
    for (final key in prefs.getKeys().toList()) {
      final lower = key.toLowerCase();
      final matched =
          _resetExactKeys.contains(key) || _resetPrefixes.any(lower.startsWith);
      if (matched) {
        await prefs.remove(key);
        removed++;
      }
    }
    // API 配置走专用重置（含缓存清理）
    await ApiConfig.instance.resetToDefault();
    Log.i('DEVTOOLS', '已重置设置，共移除 $removed 个设置键');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已重置 $removed 项设置，重启应用后完全生效'),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _exportAppData(BuildContext context) async {
    try {
      final file = await ExportService.exportAppData();
      await ExportService.shareFile(file, title: 'NGS-KG+ 应用数据导出');
      Log.i('DEVTOOLS', '应用数据已导出: ${file.path}');
    } catch (e) {
      Log.e('DEVTOOLS', '应用数据导出失败', e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeveloperSectionCard(
      icon: Icons.folder_open_outlined,
      title: '数据与存储',
      subtitle: '缓存管理、设置重置、数据导出',
      initiallyExpanded: false,
      children: [
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('清除缓存'),
          subtitle: const Text('请求缓存 + 图片缓存'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _clearCache(context),
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: const Text('重置所有设置'),
          subtitle: const Text('恢复默认值（保留设备注册与登录）'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _resetSettings(context),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: const Text('导出应用数据'),
          subtitle: const Text('API 配置/设备/设置/缓存统计 → JSON'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _exportAppData(context),
        ),
      ],
    );
  }
}
