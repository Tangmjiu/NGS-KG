import 'dart:io' show Platform;
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/player_provider.dart';

/// 桌面端集成服务：SMTC + 系统托盘 + 窗口管理。
class DesktopService {
  static final DesktopService _instance = DesktopService._();
  static DesktopService get instance => _instance;
  DesktopService._();

  SMTCWindows? _smtc;
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

  Future<void> _initSmtc(PlayerProvider player) async {
    try {
      await SMTCWindows.initialize();

      _smtc = SMTCWindows(
        metadata: MusicMetadata(
          title: player.currentSong?.name ?? '',
          album: player.currentSong?.albumName ?? '',
          albumArtist: '',
          artist: player.currentSong?.artistDisplay ?? '',
          thumbnail: player.currentSong?.albumCoverUrl ?? '',
        ),
        timeline: PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: player.duration.inMilliseconds,
          positionMs: player.position.inMilliseconds,
          minSeekTimeMs: 0,
          maxSeekTimeMs: player.duration.inMilliseconds,
        ),
        config: const SMTCConfig(
          fastForwardEnabled: false,
          nextEnabled: true,
          pauseEnabled: true,
          playEnabled: true,
          rewindEnabled: false,
          prevEnabled: true,
          stopEnabled: true,
        ),
      );

      _smtc!.buttonPressStream.listen((event) {
        switch (event) {
          case PressedButton.play:
            if (!player.isPlaying) player.togglePlayPause();
          case PressedButton.pause:
            if (player.isPlaying) player.togglePlayPause();
          case PressedButton.next:
            player.playNext();
          case PressedButton.previous:
            player.playPrevious();
          case PressedButton.stop:
            if (player.isPlaying) player.togglePlayPause();
          default:
            break;
        }
      });
    } catch (e) {
      debugPrint('DesktopService: SMTC init failed: $e');
    }
  }

  void sync({
    dynamic song,
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    String? lyricText,
  }) {
    if (_smtc == null) return;
    try {
      if (song != null) {
        _smtc!.updateMetadata(MusicMetadata(
          title: song.name ?? '',
          album: song.albumName ?? '',
          albumArtist: '',
          artist: song.artistDisplay ?? '',
          thumbnail: song.albumCoverUrl ?? '',
        ));
        // 同时更新托盘提示显示当前歌词
        final tip = lyricText != null && lyricText.isNotEmpty
            ? '${song.name ?? ''} - ${song.artistDisplay ?? ''}\n$lyricText'
            : '${song.name ?? ''} - ${song.artistDisplay ?? ''}';
        try {
          trayManager.setToolTip(tip);
        } catch (_) {}
      }
      if (isPlaying != null) {
        _smtc!.setPlaybackStatus(
            isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused);
      }
      if (positionMs != null && durationMs != null && durationMs > 0) {
        _smtc!.updateTimeline(PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: durationMs,
          positionMs: positionMs,
          minSeekTimeMs: 0,
          maxSeekTimeMs: durationMs,
        ));
      }
    } catch (e) {
      debugPrint('DesktopService: SMTC sync error: $e');
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

  Future<void> dispose() async {
    _smtc?.dispose();
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
