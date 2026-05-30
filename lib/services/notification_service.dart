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

  // ─── 旧通知备用（fallback） ───
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final int _notifId = 0;


  // ─── 回调 ───
  VoidCallback? onNotificationTap;
  VoidCallback? onPrev;
  VoidCallback? onPlayPause;
  VoidCallback? onNext;

  // ─── 初始化 ───

  Future<void> init() async {
    if (_initialized) return;

    // 初始化 flutter_local_notifications（作为备选）
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onLegacyTap,
    );

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
        switch (msg) {
          case 'onPrev':
            onPrev?.call();
          case 'onPlayPause':
            onPlayPause?.call();
          case 'onNext':
            onNext?.call();
        }
        return '';
      });

      // 告诉原生端设置回调
      await _mediaChannel.invokeMethod('setCallbacks');
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

      // 更新播放状态（播放/暂停 + 进度）
      await _mediaChannel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
        'position': position,
      });
    } catch (_) {
      // 原生通道失败时用 flutter_local_notifications 回退
      await _showLegacyNotification(
        title: title,
        artist: artist,
        albumArtUrl: albumArtUrl,
        lyricLine: lyricLine,
        isPlaying: isPlaying,
      );
    }
  }

  Future<void> cancelMediaNotification() async {
    if (Platform.isAndroid) {
      try {
        await _mediaChannel.invokeMethod('release');
      } catch (_) {}
    }
    await _plugin.cancel(_notifId);
  }

  // ─── 旧版通知回退 ───

  Future<void> _showLegacyNotification({
    required String title,
    required String artist,
    String? albumArtUrl,
    String? lyricLine,
    bool isPlaying = true,
  }) async {
    final importance = isPlaying ? Importance.high : Importance.defaultImportance;
    final displayTitle = lyricLine != null && lyricLine.isNotEmpty
        ? '$title - $artist'
        : title;
    final displayBody = (lyricLine != null && lyricLine.isNotEmpty)
        ? lyricLine
        : artist;

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
        const AndroidNotificationAction('prev', '上一首'),
        AndroidNotificationAction('play_pause', isPlaying ? '暂停' : '播放'),
        const AndroidNotificationAction('next', '下一首'),
      ],
    );

    await _plugin.show(
      _notifId,
      displayTitle,
      displayBody,
      NotificationDetails(android: androidDetails),
      payload: 'open_player',
    );
  }

  void _onLegacyTap(NotificationResponse res) {
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
      // 点击通知打开播放器
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
