import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopManager with WindowListener, TrayListener {
  static final DesktopManager instance = DesktopManager._();
  DesktopManager._();

  bool _isInit = false;

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (_isInit) return;
    _isInit = true;

    windowManager.addListener(this);
    trayManager.addListener(this);

    // 拦截关闭事件，防止直接退出
    await windowManager.setPreventClose(true);

    try {
      // 设置托盘图标和菜单
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/images/icon.ico'
            : 'assets/images/icon.png',
      );
      Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: '显示主窗口',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: '退出应用',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (_) {}
  }

  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }

  // WindowListener
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      final prefs = await SharedPreferences.getInstance();
      final closeToTray = prefs.getBool('close_to_tray') ?? true;
      if (closeToTray) {
        windowManager.hide(); // 隐藏到托盘
      } else {
        windowManager.destroy();
        exit(0);
      }
    }
  }

  // TrayListener
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy(); // 完全退出
      exit(0);
    }
  }
}

// ---- Shortcuts ----

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class NextIntent extends Intent {
  const NextIntent();
}

class PrevIntent extends Intent {
  const PrevIntent();
}

class FullscreenIntent extends Intent {
  const FullscreenIntent();
}

class BackIntent extends Intent {
  const BackIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class DesktopShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;

  const DesktopShortcuts({
    super.key,
    required this.child,
    this.onPlayPause,
    this.onNext,
    this.onPrev,
    this.onBack,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return child;
    }
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.space): const PlayPauseIntent(),
        LogicalKeySet(
                LogicalKeyboardKey.control, LogicalKeyboardKey.arrowRight):
            const NextIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowLeft):
            const PrevIntent(),
        LogicalKeySet(LogicalKeyboardKey.f11): const FullscreenIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const BackIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const SearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          PlayPauseIntent: CallbackAction<PlayPauseIntent>(
            onInvoke: (intent) {
              onPlayPause?.call();
              return null;
            },
          ),
          NextIntent: CallbackAction<NextIntent>(
            onInvoke: (intent) {
              onNext?.call();
              return null;
            },
          ),
          PrevIntent: CallbackAction<PrevIntent>(
            onInvoke: (intent) {
              onPrev?.call();
              return null;
            },
          ),
          FullscreenIntent: CallbackAction<FullscreenIntent>(
            onInvoke: (intent) async {
              bool isFullScreen = await windowManager.isFullScreen();
              windowManager.setFullScreen(!isFullScreen);
              return null;
            },
          ),
          BackIntent: CallbackAction<BackIntent>(
            onInvoke: (intent) {
              onBack?.call();
              return null;
            },
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (intent) {
              onSearch?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
