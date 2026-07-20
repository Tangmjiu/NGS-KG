// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// 监听 Android Intent 文件打开事件
///
/// 当用户在系统文件管理器或其他应用中选择"用 NGS-KG+ 打开"时，
/// 该服务将文件 URI/路径推送给注册的监听者。
class IntentHandlerService {
  static final IntentHandlerService instance = IntentHandlerService._();
  IntentHandlerService._();

  static const _channel = EventChannel('com.mjiutang.ngskg/intent');

  StreamSubscription? _sub;
  final _controller = StreamController<String>.broadcast();

  /// 可监听的文件路径流，每当有新文件需要打开时会推送一条路径字符串
  Stream<String> get onFileOpen => _controller.stream;

  /// 启动监听（在 main.dart 中调用一次）
  void start() {
    if (!Platform.isAndroid) return;
    _sub?.cancel();
    _sub = _channel.receiveBroadcastStream().listen(
      (event) {
        final uri = event?.toString() ?? '';
        if (uri.isEmpty) return;
        final path = _resolveToPath(uri);
        if (path != null) {
          Log.i('IntentHandlerService', '收到文件打开请求: $path');
          _controller.add(path);
        }
      },
      onError: (e) => Log.e('IntentHandlerService', 'Intent stream error', e),
    );
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }

  /// 将 content:// 或 file:// URI 转成文件路径字符串
  static String? _resolveToPath(String uri) {
    if (uri.startsWith('/')) return uri;
    if (uri.startsWith('file://')) {
      try {
        return Uri.parse(uri).toFilePath();
      } catch (_) {
        return uri.replaceFirst('file://', '');
      }
    }
    // content:// URI 已经在 Android 侧尝试解析为真实路径了，
    // 如果仍然是 content:// 说明无法解析，返回 null 忽略
    if (uri.startsWith('content://')) {
      Log.w('IntentHandlerService', '无法解析 content URI: $uri');
      return null;
    }
    return uri;
  }
}
