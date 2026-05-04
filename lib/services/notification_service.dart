import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _notifId = 0;
  VoidCallback? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onTap,
    );
    _initialized = true;
  }

  void _onTap(NotificationResponse res) {
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
    final androidDetails = AndroidNotificationDetails(
      'playback',
      '音乐播放',
      channelDescription: '控制音乐播放',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: duration > 0,
      indeterminate: duration <= 0,
      maxProgress: duration,
      progress: position,
      actions: [
        const AndroidNotificationAction('prev', '上一首'),
        AndroidNotificationAction(
          'play_pause',
          isPlaying ? '暂停' : '播放'),
        const AndroidNotificationAction('next', '下一首'),
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
    final androidDetails = const AndroidNotificationDetails(
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
      NotificationDetails(android: androidDetails),
    );
  }
}
