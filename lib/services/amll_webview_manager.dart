import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart';

import '../utils/local_server.dart';

/// AMLL Webview 常驻管理器。
///
/// 应用启动时预初始化 WebView2 并加载 AMLL 页面，全屏播放器打开时
/// 直接显示已加载好的页面，实现"即开即用"。
///
/// 生命周期：应用启动 → [init]（后台进行）→ `Webview` widget 常驻挂载
/// （由 [desktop_shell] 通过 Offstage 控制显隐）→ 应用退出（进程回收，
/// 无需显式 dispose）。
class AmllWebviewManager {
  AmllWebviewManager._();

  static final AmllWebviewManager instance = AmllWebviewManager._();

  /// 共享的 WebView2 控制器（只能 initialize 一次）。
  final WebviewController controller = WebviewController();

  /// 页面脚本执行完毕（收到 `[JS] INIT`）后置 true。
  final ValueNotifier<bool> isReady = ValueNotifier(false);

  bool _initialized = false;

  /// 预初始化 WebView2 并加载 AMLL 页面。可在应用启动时后台调用，
  /// 失败后允许重试（重置 [_initialized]）。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await controller.initialize();

      controller.webMessage.listen((msg) {
        debugPrint('[AMLL] JS: $msg');
        // 页面 main.js 执行完毕会发送 `[JS] INIT: done ...`
        if (msg.contains('[JS] INIT')) {
          isReady.value = true;
        }
      });

      final port = LocalServer.port;
      if (port > 0) {
        debugPrint('[AMLL] Preloading http://127.0.0.1:$port/index.html');
        await controller.loadUrl('http://127.0.0.1:$port/index.html');
      } else {
        debugPrint('[AMLL] LocalServer not running!');
      }
    } catch (e) {
      debugPrint('[AMLL] Preload init error: $e');
      _initialized = false; // 允许重试
    }
  }
}
