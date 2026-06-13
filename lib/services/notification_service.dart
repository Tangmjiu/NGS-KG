// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 原生媒体通知 & MediaSession 管理器（Dart 端）
///
/// 通过 MethodChannel 与 Android 端的 MediaSessionManager.kt 通信，
/// 实现：
/// - 系统媒体通知（MediaStyle，显示在快捷面板媒体中心）
/// - 锁屏控制
/// - 车载蓝牙 A2DP 元数据广播
/// - 通知栏按钮控制
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  // ─── 原生通信 ───

  static const _mediaChannel = MethodChannel('com.kugou.ngskg/media_session');
  static const _callbackChannel = BasicMessageChannel<String>(
    'com.kugou.ngskg/media_callbacks',
    StringCodec(),
  );

  // ─── 全局通知（非媒体，仅用于消息提示） ───
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ─── 回调 ───
  VoidCallback? onNotificationTap;
  VoidCallback? onPrev;
  VoidCallback? onPlayPause;
  VoidCallback? onNext;
  VoidCallback? onLike;
  VoidCallback? onSwitchMode;
  void Function(int positionMs)? onSeekTo;

  // ─── 初始化 ───

  Future<void> init() async {
    if (_initialized) return;

    // 初始化 flutter_local_notifications（仅用于非媒体消息提示）
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidSettings));

    // Android 13+ 通知权限请求
    if (Platform.isAndroid) {
      try {
        final p = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await p?.requestNotificationsPermission();
      } catch (_) {}
    }

    if (Platform.isAndroid) {
      // 注册原生回调通道（媒体按钮 → Flutter）
      _callbackChannel.setMessageHandler((msg) async {
        if (msg == 'onPrev') {
          onPrev?.call();
        } else if (msg == 'onPlayPause') {
          onPlayPause?.call();
        } else if (msg == 'onNext') {
          onNext?.call();
        } else if (msg == 'onLike') {
          onLike?.call();
        } else if (msg == 'onSwitchMode') {
          onSwitchMode?.call();
        } else if (msg?.startsWith('onSeekTo|') == true) {
          final parts = msg!.split('|');
          if (parts.length >= 2) {
            final posMs = int.tryParse(parts[1]);
            if (posMs != null) onSeekTo?.call(posMs);
          }
        }
        return '';
      });

    }

    _initialized = true;
  }

  // ─── 媒体通知核心 ───

  /// 更新媒体元数据和播放状态
  ///
  /// 通知原生端更新 MediaSession 和 MediaStyle 通知。
  Future<void> showMediaNotification({
    required String title,
    required String artist,
    String? albumArtUrl,
    String? lyricLine,
    bool isPlaying = true,
    int duration = 0,    // 秒
    int position = 0,    // 秒
    bool isBuffering = false, // 是否缓冲中
  }) async {
    if (!Platform.isAndroid) return;

    try {
      // 更新元数据（标题、歌手、封面、时长、歌词）
      await _mediaChannel.invokeMethod('updateMetadata', {
        'title': title,
        'artist': artist,
        'albumArtUrl': albumArtUrl,
        'duration': duration,
        'lyricLine': lyricLine,
      });

      // 更新播放状态（播放/暂停 + 进度 + 缓冲）
      await _mediaChannel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
        'position': position,
        'isBuffering': isBuffering,
      });
    } catch (_) {
      // 原生通道失败时不创建重复通知，静默降级
    }
  }

  /// 更新自定义按钮状态（收藏、播放模式）
  Future<void> updateCustomButtons({
    required bool liked,
    required String playMode,  // "sequential" | "shuffle" | "repeatOne"
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _mediaChannel.invokeMethod('updateCustomButtons', {
        'liked': liked,
        'playMode': playMode,
      });
    } catch (_) {}
  }

  Future<void> cancelMediaNotification() async {
    if (Platform.isAndroid) {
      try {
        await _mediaChannel.invokeMethod('release');
      } catch (_) {}
    }
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

  /// 释放
  void dispose() {
  }
}
