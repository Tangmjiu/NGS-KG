import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final Dio _dio = Dio();
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
        final plugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await plugin?.requestNotificationsPermission();
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

  /// 下载封面到临时目录，返回本地文件路径
  Future<String?> _downloadArt(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/notif_art_${url.hashCode}.jpg';
      final file = File(filePath);
      if (await file.exists()) return filePath; // 已缓存
      await _dio.download(url.replaceAll('{size}', '240'), filePath);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> showMediaNotification({
    required String title,
    required String artist,
    String? albumArtUrl,
    String? lyricLine,
    bool isPlaying = true,
    int duration = 0,
    int position = 0,
  }) async {
    if (Platform.isAndroid && !_permissionGranted) return;

    final importance = isPlaying ? Importance.high : Importance.defaultImportance;

    // 歌词显示在 body，歌手在标题后
    final displayTitle = lyricLine != null && lyricLine.isNotEmpty
        ? '$title - $artist'
        : title;
    final displayBody = (lyricLine != null && lyricLine.isNotEmpty)
        ? lyricLine
        : artist;

    // 下载封面
    final artPath = await _downloadArt(albumArtUrl);

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
      largeIcon: artPath != null ? FilePathAndroidBitmap(artPath) : null,
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
      displayTitle,
      displayBody,
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
