// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import 'local_cover_art.dart';

/// 桌面端自绘标题栏（替代 Windows/Linux 原生标题栏）。
///
/// 布局：应用图标 + 应用名 | 当前播放歌曲（封面 + 歌名/歌手）| 窗口控制按钮。
/// - 空白区域支持拖拽移动窗口、双击最大化/还原
/// - 播放信息点击打开全屏播放器
/// - 全屏时自动隐藏
class DesktopTitleBar extends StatefulWidget {
  const DesktopTitleBar({super.key});

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  bool _isMaximized = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      _initState();
    }
  }

  Future<void> _initState() async {
    final maximized = await windowManager.isMaximized();
    final fullScreen = await windowManager.isFullScreen();
    if (mounted) {
      setState(() {
        _isMaximized = maximized;
        _isFullScreen = fullScreen;
      });
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() => _isFullScreen = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface.withValues(alpha: 0.92),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // ── 拖拽区域（含应用图标、标题、播放信息） ──
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: _toggleMaximize,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    // 应用图标
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        'assets/images/icon.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 20,
                          height: 20,
                          color: cs.primaryContainer,
                          child: Icon(Icons.music_note,
                              size: 14, color: cs.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'NGS-KG+',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 当前播放信息
                    Expanded(child: _buildNowPlaying(cs)),
                  ],
                ),
              ),
            ),
            // ── 窗口控制按钮 ──
            _WinButton(
              icon: Icons.remove,
              tooltip: '最小化',
              onPressed: () => windowManager.minimize(),
            ),
            _WinButton(
              icon: _isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              iconSize: 13,
              tooltip: _isMaximized ? '还原' : '最大化',
              onPressed: _toggleMaximize,
            ),
            _WinButton(
              icon: Icons.close,
              tooltip: '关闭',
              isClose: true,
              onPressed: () => windowManager.close(),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlaying(ColorScheme cs) {
    final song = context.select<PlayerProvider, Song?>((p) => p.currentSong);

    return GestureDetector(
      onTap: () {
        if (song != null) {
          context.read<PlayerProvider>().setPlayerScreenVisible(true);
        }
      },
      child: Row(
        children: [
          LocalCoverArt(
            url: song?.albumCoverUrl,
            coverData: song?.coverData,
            size: 24,
            borderRadius: 6,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song?.name ?? '未在播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        song != null ? FontWeight.w500 : FontWeight.normal,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (song != null && song.artists.isNotEmpty)
                  Text(
                    song.artists.join(' / '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }
}

/// 窗口控制按钮（最小化/最大化/关闭）。
class _WinButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;
  final double iconSize;

  const _WinButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
    this.iconSize = 16,
  });

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 44,
            height: 38,
            color: _isHovered
                ? (widget.isClose
                    ? const Color(0xFFC42B1C)
                    : cs.onSurface.withValues(alpha: 0.08))
                : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _isHovered && widget.isClose
                  ? Colors.white
                  : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
