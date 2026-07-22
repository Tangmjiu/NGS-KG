// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/platform_helper.dart';

/// 通用消息通知管理器（非媒体通知）。
///
/// 媒体通知（MediaSession + MediaStyle）在 Android 上由 [MusicAudioHandler]
/// 通过 audio_service 包自动管理。OHOS 上通过 MethodChannel 与原生 AVSession 通信。
///
/// 本类仅保留：
/// - 应用内消息通知（如版本更新、后台任务完成等）
/// - Android 13+ 通知权限请求
/// - OHOS AVSession 原生通道
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ─── OHOS MethodChannel ───
  static const _mediaChannel = MethodChannel('com.mjiutang.ngskg/media_session');
  static const _callbackChannel = MethodChannel('com.mjiutang.ngskg/media_callback');

  // 媒体按钮回调
  VoidCallback? onPrev;
  VoidCallback? onPlayPause;
  VoidCallback? onNext;
  VoidCallback? onLike;
  VoidCallback? onSwitchMode;
  void Function(int positionMs)? onSeekTo;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
        const InitializationSettings(android: androidSettings));

    // Android 13+ 通知权限请求
    if (Platform.isAndroid) {
      try {
        final p = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await p?.requestNotificationsPermission();
      } catch (_) {}
    }

    if (isOhos) {
      // OHOS: 注册原生回调通道（媒体按钮 → Flutter）
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

  // ─── OHOS AVSession (Android 由 audio_service 管理) ───

  /// OHOS: 更新媒体元数据和播放状态
  Future<void> showMediaNotification({
    required String title,
    required String artist,
    String? albumArtUrl,
    String? lyricLine,
    bool isPlaying = true,
    int duration = 0,
    int position = 0,
    bool isBuffering = false,
  }) async {
    if (!isOhos) return;

    try {
      await _mediaChannel.invokeMethod('updateMetadata', {
        'title': title,
        'artist': artist,
        'albumArtUrl': albumArtUrl,
        'duration': duration,
        'lyricLine': lyricLine,
      });
      await _mediaChannel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
        'position': position,
        'isBuffering': isBuffering,
      });
    } catch (_) {}
  }

  /// OHOS: 更新自定义按钮状态（收藏、播放模式）
  Future<void> updateCustomButtons({
    required bool liked,
    required String playMode,
  }) async {
    if (!isOhos) return;
    try {
      await _mediaChannel.invokeMethod('updateCustomButtons', {
        'liked': liked,
        'playMode': playMode,
      });
    } catch (_) {}
  }

  Future<void> cancelMediaNotification() async {
    if (isOhos) {
      try { await _mediaChannel.invokeMethod('release'); } catch (_) {}
    }
  }

  // ─── 通用消息通知 ───
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

