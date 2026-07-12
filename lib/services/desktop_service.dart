import 'dart:io' show Platform;
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
// import 'package:smtc_windows/smtc_windows.dart'; // Linux: MPRIS TBD
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/player_provider.dart';

/// 桌面端集成服务：SMTC + 系统托盘 + 窗口管理。
///
/// 实现 [TrayListener] 以响应 GNOME 顶栏托盘图标的点击事件。
class DesktopService implements TrayListener {
  static final DesktopService _instance = DesktopService._();
  static DesktopService get instance => _instance;
  DesktopService._();

  final _smtc = null;
  PlayerProvider? _player;
  bool _initialized = false;

  Future<void> init(PlayerProvider player) async {
    if (_initialized) return;
    _initialized = true;
    _player = player;

    if (Platform.isWindows) {
      await _initSmtc(player);
    }

    await _initTray(player);
    await _initWindow();
  }

  // ═══════════════════════════════════════════════
  //  SMTC
  // ═══════════════════════════════════════════════

  Future<void> _initSmtc(PlayerProvider player) async {}

  void sync({
    dynamic song,
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    String? lyricText,
  }) {
    // Linux: SMTC 部分已注释（MPRIS TBD），仅保留托盘提示更新
    if (song != null) {
      final tip = lyricText != null && lyricText.isNotEmpty
          ? '${song.name ?? ''} - ${song.artistDisplay ?? ''}\n$lyricText'
          : '${song.name ?? ''} - ${song.artistDisplay ?? ''}';
      try {
        trayManager.setToolTip(tip);
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════════
  //  系统托盘
  // ═══════════════════════════════════════════════

  Future<void> _initTray(PlayerProvider player) async {
    try {
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/icons/app_icon.ico'
            : 'assets/images/icon.png',
      );
      await trayManager.setToolTip('NGS-KG+');
      await _updateTrayMenu(player.isPlaying);
      trayManager.addListener(this);
    } catch (e) {
      debugPrint('DesktopService: Tray init failed: $e');
    }
  }

  Future<void> _updateTrayMenu(bool isPlaying) async {
    final label = isPlaying ? '暂停' : '播放';
    try {
      await trayManager.setContextMenu(Menu(
        items: [
          MenuItem(label: '显示', onClick: (_) => _restoreWindow()),
          MenuItem(label: '上一首', onClick: (_) => _player?.playPrevious()),
          MenuItem(label: label, onClick: (_) => _player?.togglePlayPause()),
          MenuItem(label: '下一首', onClick: (_) => _player?.playNext()),
          MenuItem.separator(),
          MenuItem(label: '退出', onClick: (_) => _quitApp()),
        ],
      ));
    } catch (_) {}
  }

  void _restoreWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  void _quitApp() async {
    try {
      await windowManager.destroy();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════
  //  窗口管理
  // ═══════════════════════════════════════════════

  Future<void> _initWindow() async {
    try {
      await windowManager.setMinimumSize(const Size(960, 600));
      // 关闭按钮 → 隐藏到托盘，不退出
      await windowManager.setPreventClose(true);
      windowManager.addListener(_CloseToTrayListener(this));
    } catch (e) {
      debugPrint('DesktopService: Window init error: $e');
    }
  }

  void _hideWindow() async {
    try {
      await windowManager.hide();
    } catch (_) {}
  }

  Future<void> setCloseToTray(bool enabled) async {
    try {
      await windowManager.setPreventClose(enabled);
    } catch (_) {}
  }

  // ── TrayListener ──
  // GNOME AppIndicator 扩展将托盘图标显示在顶栏。
  // 左键 → 切换窗口显示/隐藏；右键 → 弹出上下文菜单（由 setContextMenu 处理）。

  @override
  void onTrayIconMouseDown() {
    _toggleWindowVisibility();
  }

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconRightMouseDown() {}

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {}

  void _toggleWindowVisibility() async {
    try {
      final visible = await windowManager.isVisible();
      if (visible) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    // _smtc?.dispose(); // Linux: no SMTC on Linux
  }
}

/// 关闭按钮 → 隐藏到托盘
class _CloseToTrayListener extends WindowListener {
  final DesktopService _service;
  _CloseToTrayListener(this._service);

  @override
  void onWindowClose() {
    _service._hideWindow();
  }
}
