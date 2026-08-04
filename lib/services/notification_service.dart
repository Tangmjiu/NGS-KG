// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通用消息通知管理器（非媒体通知）。
///
/// 媒体通知（MediaSession + MediaStyle）现在由 [MusicAudioHandler]
/// 通过 audio_service 包自动管理，不再需要本类的媒体通知方法。
///
/// 本类仅保留：
/// - 应用内消息通知（如版本更新、后台任务完成等）
/// - Android 13+ 通知权限请求
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin
        .initialize(const InitializationSettings(android: androidSettings));

    // Android 13+ 通知权限请求
    if (Platform.isAndroid) {
      try {
        final p = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await p?.requestNotificationsPermission();
      } catch (_) {}
    }

    _initialized = true;
  }

  Future<void> showMessageNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'messages',
      '消息',
      channelDescription: '应用消息通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}
