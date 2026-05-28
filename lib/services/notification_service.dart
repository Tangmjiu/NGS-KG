import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final int _notifId = 0;

  // Android 13+ 需要运行时请求通知权限
  bool _permissionGranted = false;

  VoidCallback? onNotificationTap;
  VoidCallback? onPrev;
  VoidCallback? onPlayPause;
  VoidCallback? onNext;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Android 13+ (API 33) 请求通知权限
    if (Platform.isAndroid) {
      try {
        final granted = await _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
        _permissionGranted = granted ?? false;
      } catch (_) {
        _permissionGranted = false;
      }
    }

    _initialized = true;
  }

  void _onTap(NotificationResponse res) {
    switch (res.actionId) {
      case 'prev':
        onPrev?.call();
        return;
      case 'play_pause':
        onPlayPause?.call();
        return;
      case 'next':
        onNext?.call();
        return;
    }
    if (res.payload == 'open_player') {
      onNotificationTap?.call();
    }
  }

  Future<void> showMediaNotification({
    required String title,
    required String artist,
    bool isPlaying = true,
    int duration = 0,
    int position = 0,
  }) async {
    // Android 13+ 未授权时不显示
    if (Platform.isAndroid && !_permissionGranted) return;

    final importance = isPlaying ? Importance.high : Importance.defaultImportance;

    final androidDetails = AndroidNotificationDetails(
      'music_playback',
      '音乐播放',
      channelDescription: '音乐播放控制',
      importance: importance,
      priority: Priority.high,
      ongoing: isPlaying,
      autoCancel: false,
      showProgress: false,
      icon: '@mipmap/ic_launcher',
      actions: [
        const AndroidNotificationAction('prev', '上一首',
            contextual: true),
        AndroidNotificationAction(
          'play_pause',
          isPlaying ? '暂停' : '播放',
          contextual: true,
        ),
        const AndroidNotificationAction('next', '下一首',
            contextual: true),
      ],
    );

    await _plugin.show(
      _notifId,
      title,
      artist,
      NotificationDetails(android: androidDetails),
      payload: 'open_player',
    );
  }

  Future<void> cancelMediaNotification() async {
    await _plugin.cancel(_notifId);
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
