import 'dart:io' show Platform;
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/player_provider.dart';
import 'linux_mpris_service.dart';

/// 桌面端集成服务：系统托盘 + 窗口管理 + MPRIS (Linux).
class DesktopService {
  static final DesktopService _instance = DesktopService._();
  static DesktopService get instance => _instance;
  DesktopService._();

  PlayerProvider? _player;
  bool _initialized = false;
  final LinuxMprisService _mpris = LinuxMprisService();

  Future<void> init(PlayerProvider player) async {
    if (_initialized) return;
    _initialized = true;
    _player = player;

    if (Platform.isLinux) {
      await _mpris.init(player);
    }

    await _initTray(player);
    await _initWindow();
  }

  /// 由 PlayerProvider 的 listener 调用，同步状态到 MPRIS 和托盘。
  void sync({
    dynamic song,
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    String? lyricText,
  }) {
    // MPRIS (Linux)
    if (Platform.isLinux) {
      _mpris.sync(
        song: song,
        isPlaying: isPlaying,
        positionMs: positionMs,
        durationMs: durationMs,
        lyricText: lyricText,
      );
    }

    // 托盘提示
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
      await windowManager.setPreventClose(true);
      // Linux: 隐藏原生 GTK 标题栏，使用 Flutter 自定义 M3TitleBar
      try {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      } catch (_) {
        // setTitleBarStyle 在部分 Linux WM 上可能不支持，静默忽略
      }
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

  Future<void> dispose() async {
    await _mpris.dispose();
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
