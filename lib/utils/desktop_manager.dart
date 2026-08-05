import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';

class DesktopManager with WindowListener, TrayListener {
  static final DesktopManager instance = DesktopManager._();
  DesktopManager._();

  bool _isInit = false;

  /// 绑定的播放器（用于托盘播放控制与状态联动）。
  PlayerProvider? _player;

  /// 当前托盘图标路径。
  String? _trayIconPath;

  String? _lastSongKey;
  bool _lastIsPlaying = false;

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (_isInit) return;
    _isInit = true;

    windowManager.addListener(this);
    trayManager.addListener(this);

    // 拦截关闭事件，防止直接退出
    await windowManager.setPreventClose(true);

    try {
      if (Platform.isWindows) {
        // Windows 托盘图标仅支持 .ico（原生 LoadImage 不识别 PNG），
        // 先把 asset 图标落到临时目录再设置。
        _trayIconPath = await _materializeIcon('assets/icons/tray.ico');
        await trayManager.setIcon(_trayIconPath!);
      } else {
        await trayManager.setIcon('assets/images/icon.png');
      }
      await trayManager.setToolTip('NGS-KG+');
      await _updateContextMenu();
    } catch (_) {}
  }

  /// 把 asset 资源写入临时目录并返回文件路径（Windows 托盘需要真实文件路径）。
  Future<String> _materializeIcon(String asset) async {
    final data = await rootBundle.load(asset);
    final dir = await getTemporaryDirectory();
    final fileName = 'ngskg_${asset.split('/').last}';
    final file = File('${dir.path}/$fileName');
    if (!await file.exists()) {
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  /// 绑定播放器：监听播放状态变化，同步托盘图标、提示文字与右键菜单。
  void bindPlayer(PlayerProvider player) {
    if (_player == player) return;
    _player?.removeListener(_onPlayerChanged);
    _player = player;
    player.addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  void dispose() {
    _player?.removeListener(_onPlayerChanged);
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }

  /// 播放状态变化时同步托盘（带节流：歌曲或播放状态未变则跳过）。
  void _onPlayerChanged() {
    final player = _player;
    if (player == null) return;
    final song = player.currentSong;
    final songKey = song == null
        ? null
        : '${song.id}_${song.hash ?? ''}_${song.filePath ?? ''}';
    final isPlaying = player.isPlaying;
    if (songKey == _lastSongKey && isPlaying == _lastIsPlaying) return;
    _lastSongKey = songKey;
    _lastIsPlaying = isPlaying;
    _updateTray(song: song, isPlaying: isPlaying);
  }

  Future<void> _updateTray({Song? song, required bool isPlaying}) async {
    try {
      // 图标随播放状态切换：播放中 ▶ / 已暂停 ⏸ / 未播放 默认
      if (Platform.isWindows) {
        final icon = isPlaying
            ? 'assets/icons/tray_playing.ico'
            : (song != null
                ? 'assets/icons/tray_paused.ico'
                : 'assets/icons/tray.ico');
        final path = await _materializeIcon(icon);
        if (path != _trayIconPath) {
          await trayManager.setIcon(path);
          _trayIconPath = path;
        }
      }

      // 提示文字：歌名 - 歌手 - 专辑（Windows 限制 127 字符）
      var tip = 'NGS-KG+';
      if (song != null) {
        final parts = <String>[song.name];
        if (song.artists.isNotEmpty) parts.add(song.artists.join('/'));
        if (song.albumName != null && song.albumName!.isNotEmpty) {
          parts.add(song.albumName!);
        }
        tip = parts.join(' - ');
        if (tip.length > 110) tip = '${tip.substring(0, 110)}…';
      }
      await trayManager.setToolTip(tip);

      await _updateContextMenu();
    } catch (_) {}
  }

  Future<void> _updateContextMenu() async {
    final player = _player;
    final song = player?.currentSong;
    final isPlaying = player?.isPlaying ?? false;

    final items = <MenuItem>[
      MenuItem(key: 'show_window', label: '显示主窗口'),
    ];
    if (song != null) {
      final infoLabel =
          song.name.length > 24 ? '${song.name.substring(0, 24)}…' : song.name;
      final infoSub = [
        if (song.artists.isNotEmpty) song.artists.join('/'),
        if (song.albumName != null && song.albumName!.isNotEmpty)
          song.albumName!,
      ].join(' · ');
      items.addAll([
        MenuItem.separator(),
        MenuItem(
          key: 'song_info',
          label: infoLabel,
          sublabel: infoSub,
          disabled: true,
        ),
        MenuItem.separator(),
        MenuItem(key: 'play_pause', label: isPlaying ? '暂停' : '播放'),
        MenuItem(key: 'prev', label: '上一首'),
        MenuItem(key: 'next', label: '下一首'),
      ]);
    }
    items.addAll([
      MenuItem.separator(),
      MenuItem(key: 'exit_app', label: '退出应用'),
    ]);
    await trayManager.setContextMenu(Menu(items: items));
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
    switch (menuItem.key) {
      case 'show_window':
        windowManager.show();
        windowManager.focus();
        break;
      case 'play_pause':
        _player?.togglePlayPause();
        break;
      case 'prev':
        _player?.playPrevious();
        break;
      case 'next':
        _player?.playNext();
        break;
      case 'exit_app':
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
