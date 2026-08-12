// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/notification_service.dart';
import '../../../utils/logger.dart';
import '../debug_prefs_provider.dart';
import '../dev_channel.dart';
import 'section_card.dart';

/// 系统交互与触发分组
///
/// - 跳转系统开发者选项 / 本应用设置（原生 MethodChannel）
/// - 触发测试通知（flutter_local_notifications）
/// - 模拟低内存（onTrimMemory）
/// - 模拟网络断开（Dio 拦截层，可恢复）
// 新增功能：系统交互与触发
class SystemSection extends StatelessWidget {
  const SystemSection({super.key});

  Future<void> _showMessage(BuildContext context, String text) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    await NotificationService.instance.init();
    await NotificationService.instance
        .showMessageNotification('NGS-KG+ 测试通知', '这是一条来自开发者工具的测试通知');
    Log.i('DEVTOOLS', '已触发测试通知');
    if (!context.mounted) return;
    await _showMessage(context, '测试通知已发送');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DebugPrefsProvider>(
      builder: (context, prefs, _) {
        return DeveloperSectionCard(
          icon: Icons.touch_app_outlined,
          title: '系统交互与触发',
          subtitle: '系统跳转、测试通知、低内存与断网模拟',
          initiallyExpanded: false,
          children: [
            const ListTile(
              leading: Icon(Icons.developer_mode),
              title: Text('跳转系统开发者选项'),
              subtitle: Text('Android 系统设置 → 开发者选项'),
              trailing: Icon(Icons.chevron_right),
              onTap: DevChannel.openSystemDeveloperSettings,
            ),
            const ListTile(
              leading: Icon(Icons.settings_applications),
              title: Text('跳转应用设置'),
              subtitle: Text('本应用系统设置页面（权限/通知）'),
              trailing: Icon(Icons.chevron_right),
              onTap: DevChannel.openAppSettings,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('触发测试通知'),
              subtitle: const Text('发送一条应用内测试通知'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _sendTestNotification(context),
            ),
            ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('模拟低内存'),
              subtitle: const Text('触发 onTrimMemory 低内存警告'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await DevChannel.triggerLowMemory();
                Log.i('DEVTOOLS', '已触发低内存警告');
                if (!context.mounted) return;
                await _showMessage(context, '已触发低内存警告');
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.wifi_off),
              title: const Text('模拟网络断开'),
              subtitle:
                  Text(prefs.offlineMode ? '已开启：所有请求将被拦截' : '开启后模拟断网，可随时恢复'),
              value: prefs.offlineMode,
              onChanged: (v) => prefs.offlineMode = v,
            ),
          ],
        );
      },
    );
  }
}
