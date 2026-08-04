// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';
import '../utils/navigation.dart' as app;
import '../utils/theme.dart';
import '../screens/player_screen.dart';

/// Material Design 3 Expressive 悬浮媒体胶囊 (Floating MiniPlayer)
///
/// 特性规范：
/// 1. **悬浮圆角胶囊形态 (Expressive Capsule)**：采用 `AppShape.full`（圆角 28dp），悬浮于底部导航栏或屏幕底部上方，具备轻盈的毛玻璃质感与立体投影。
/// 2. **触控感应与手势反馈 (Tactile & Gesture Mastery)**：
///    - **按压反馈**：卡片整体搭载 `M3PressScale` 微缩下沉物理动效（0.97 比例）。
///    - **左右滑动切歌 (Swipe-to-Skip)**：手势左右拖动卡片可顺滑切换上一首/下一首，带有回弹阻尼与触感振动响应。
///    - **点击展开**：平滑开启全屏播放器页面。
/// 3. **动态状态呈现**：
///    - **播放/暂停图标互转**：采用 `AnimatedSwitcher` + `ScaleTransition` + `RotationTransition` 顺滑且带自旋切换按钮状态。
///    - **环形/底边高精度进度条**：内嵌贴合胶囊下边缘的微细线性进度指示，动态颜色对准 `cs.primary`，配合 `TweenAnimationBuilder` 顺滑流淌。
class M3ExpressiveMiniPlayer extends StatefulWidget {
  const M3ExpressiveMiniPlayer({super.key});

  @override
  State<M3ExpressiveMiniPlayer> createState() => _M3ExpressiveMiniPlayerState();

  /// 构建专辑封面或加载转圈指示器
  static Widget _buildCoverArt(Song song, ColorScheme cs, bool isLoading) {
    Widget coverWidget;
    final url = song.thumbnailCoverUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('file:') || url.startsWith('/')) {
        final path =
            url.startsWith('file:') ? Uri.parse(url).toFilePath() : url;
        final file = File(path);
        if (file.existsSync()) {
          coverWidget = Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultCoverIcon(cs),
          );
        } else {
          coverWidget = _defaultCoverIcon(cs);
        }
      } else {
        coverWidget = CachedNetworkImage(
          imageUrl: url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          memCacheWidth: 96,
          memCacheHeight: 96,
          errorWidget: (_, __, ___) => _defaultCoverIcon(cs),
        );
      }
    } else {
      coverWidget = _defaultCoverIcon(cs);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            coverWidget,
            if (isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _defaultCoverIcon(ColorScheme cs) {
    return Container(
      width: 48,
      height: 48,
      color: cs.surfaceContainerHigh,
      child: Icon(Icons.music_note_rounded, size: 24, color: cs.primary),
    );
  }

  /// 播放/暂停圆形动效按钮 (加入了顺滑旋转自旋转场效果)
  static Widget _buildPlayPauseButton(
    ({bool isPlaying, bool isLoading}) state,
    ColorScheme cs,
    BuildContext context,
  ) {
    return M3PressScale(
      child: Material(
        color: cs.primary,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: cs.primary.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.read<PlayerProvider>().togglePlayPause(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.dMedium1,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: RotationTransition(
                      // 从播放到暂停时微微自旋 90 度，营造物理旋转感
                      turns: Tween<double>(begin: -0.25, end: 0.0).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
                child: Icon(
                  state.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey<bool>(state.isPlaying),
                  color: cs.onPrimary,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _M3ExpressiveMiniPlayerState extends State<M3ExpressiveMiniPlayer>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _hasVibrated = false;
  late AnimationController _resetController;
  Animation<double>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _resetController.addListener(() {
      setState(() {
        _dragOffset = _resetAnimation!.value;
      });
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider?>();
    if (player == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Selector<PlayerProvider,
        ({Song? song, bool visible, bool dismissed})>(
      selector: (_, p) => (
        song: p.currentSong,
        visible: p.isPlayerScreenVisible,
        dismissed: p.isMiniPlayerDismissed,
      ),
      builder: (context, state, _) {
        final song = state.song;
        if (song == null || state.visible || state.dismissed) {
          return const SizedBox.shrink();
        }

        final swipeThreshold = 75.0;
        final dragPercent = (_dragOffset.abs() / swipeThreshold).clamp(0.0, 1.0);

        return Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ── 滑动提示背景 (拖拽时渐显) ──
                if (_dragOffset > 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: dragPercent,
                      child: _buildSwipeIndicator(
                          cs, Icons.skip_previous_rounded, '上一首', Alignment.centerLeft),
                    ),
                  ),
                if (_dragOffset < 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: dragPercent,
                      child: _buildSwipeIndicator(
                          cs, Icons.skip_next_rounded, '下一首', Alignment.centerRight),
                    ),
                  ),

                // ── 主播放条卡片 (包含毛玻璃与手势交互) ──
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_resetController.isAnimating) {
                      _resetController.stop();
                    }
                    setState(() {
                      // 带有阻尼感的拖拽位移
                      _dragOffset += details.delta.dx * 0.75;
                      
                      // 刚超过阈值时触发一次短触感振动
                      if (_dragOffset.abs() >= swipeThreshold) {
                        if (!_hasVibrated) {
                          HapticFeedback.lightImpact();
                          _hasVibrated = true;
                        }
                      } else {
                        _hasVibrated = false;
                      }
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    final player = context.read<PlayerProvider>();
                    if (_dragOffset > swipeThreshold) {
                      player.playPrevious();
                    } else if (_dragOffset < -swipeThreshold) {
                      player.playNext();
                    }

                    // 弹性回弹动画
                    _resetAnimation = Tween<double>(
                      begin: _dragOffset,
                      end: 0.0,
                    ).animate(CurvedAnimation(
                      parent: _resetController,
                      curve: Curves.easeOutBack,
                    ));
                    _resetController.forward(from: 0.0);
                    _hasVibrated = false;
                  },
                  onTap: () => _openPlayerScreen(context),
                  onLongPress: () => _onLongPress(context),
                  child: Transform.translate(
                    offset: Offset(_dragOffset, 0),
                    child: Transform.rotate(
                      // 滑动时微微倾斜，极具动感
                      angle: (_dragOffset / 1200.0).clamp(-0.04, 0.04),
                      child: M3PressScale(
                        child: Material(
                          color: Colors.transparent, // 必须透明以使毛玻璃生效
                          borderRadius: AppShape.full,
                          elevation: 6,
                          shadowColor: cs.shadow.withValues(alpha: 0.16),
                          child: ClipRRect(
                            borderRadius: AppShape.full,
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                height: 64.0,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainer.withValues(alpha: 0.76),
                                  borderRadius: AppShape.full,
                                  border: Border.all(
                                    color: cs.primary.withValues(alpha: 0.14),
                                    width: 1.2,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // 底部嵌入式极细进度条（独立订阅 progress，并带有 Tween 缓动）
                                    const _MiniProgressBar(),

                                    // 主交互排版区
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                                      child: Opacity(
                                        // 滑动时内容微微渐隐
                                        opacity: (1.0 - (dragPercent * 0.45)).clamp(0.55, 1.0),
                                        child: Row(
                                          children: [
                                            // 专辑封面（含安全过渡与 Hero 动效）
                                            Hero(
                                              tag: 'album_art_${song.hash ?? song.id}',
                                              flightShuttleBuilder: _safeFlightShuttle,
                                              child: _MiniCoverArt(song: song),
                                            ),
                                            const SizedBox(width: 10),

                                            // 歌曲信息排版
                                            Expanded(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      song.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: tt.bodyMedium?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        color: cs.onSurface,
                                                        letterSpacing: -0.2,
                                                        height: 1.2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      song.artistDisplay,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: tt.labelSmall?.copyWith(
                                                        color: cs.onSurfaceVariant,
                                                        height: 1.15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),

                                            // 媒体控制按钮组
                                            _buildControlButton(
                                              icon: Icons.skip_previous_rounded,
                                              tooltip: '上一首',
                                              cs: cs,
                                              onTap: () => context
                                                  .read<PlayerProvider>()
                                                  .playPrevious(),
                                            ),
                                            const SizedBox(width: 2),

                                            // 主播放/暂停响应态圆形按钮
                                            const _MiniPlayPauseButton(),
                                            const SizedBox(width: 2),

                                            _buildControlButton(
                                              icon: Icons.skip_next_rounded,
                                              tooltip: '下一首',
                                              cs: cs,
                                              onTap: () =>
                                                  context.read<PlayerProvider>().playNext(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 飞行安全过渡组件（防止路由与 Hero 切出同时出现排版异常抛出黑框）
  Widget _safeFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final Hero toHero = toHeroContext.widget as Hero;
    return Material(
      color: Colors.transparent,
      child: toHero.child,
    );
  }

  /// 滑动切歌时的底部提示背景
  Widget _buildSwipeIndicator(
      ColorScheme cs, IconData icon, String label, Alignment alignment) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      height: 64.0,
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.85),
        borderRadius: AppShape.full,
      ),
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? 24 : 12,
        right: isLeft ? 12 : 24,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLeft) ...[
              Icon(icon, color: cs.onSecondaryContainer, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ] else ...[
              Text(
                label,
                style: TextStyle(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: cs.onSecondaryContainer, size: 22),
            ]
          ],
        ),
      ),
    );
  }

  void _onLongPress(BuildContext context) {
    HapticFeedback.mediumImpact();
    final player = context.read<PlayerProvider>();
    player.dismissMiniPlayer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('播放控制栏已隐藏，播放新歌时会自动重新显示'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '恢复',
          onPressed: () {
            player.showMiniPlayer();
          },
        ),
      ),
    );
  }



  /// 基础控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required ColorScheme cs,
    VoidCallback? onTap,
  }) {
    return M3PressScale(
      child: InkWell(
        borderRadius: AppShape.full,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 24, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }



  void _openPlayerScreen(BuildContext context) {
    final player = context.read<PlayerProvider>();
    player.setPlayerScreenVisible(true);
    app.navKey.currentState
        ?.push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PlayerScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: AppMotion.emphasizedDecelerate,
                  ),
                ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            transitionDuration: AppMotion.dMedium2,
          ),
        )
        .then((_) => player.setPlayerScreenVisible(false));
  }
}

/// 底部独立进度条：只订阅 progress，加入 Linear 250ms 缓动以避免跳格。
class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar();

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, double?>(
      selector: (_, p) {
        final duration = p.duration.inMilliseconds;
        if (duration <= 0) return null;
        final value = p.position.inMilliseconds / duration;
        return value.isFinite ? value.clamp(0.0, 1.0) : null;
      },
      builder: (_, value, __) {
        if (value == null) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.transparent,
            color: Theme.of(context).colorScheme.primary,
            minHeight: 3,
          ),
        );
      },
    );
  }
}

/// 封面 + 加载遮罩：只订阅 isLoading，避免进度变化时重建封面。
class _MiniCoverArt extends StatelessWidget {
  final Song song;

  const _MiniCoverArt({required this.song});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Selector<PlayerProvider, bool>(
      selector: (_, p) => p.isLoading,
      builder: (_, isLoading, __) {
        return M3ExpressiveMiniPlayer._buildCoverArt(song, cs, isLoading);
      },
    );
  }
}

/// 播放/暂停按钮：只订阅 isPlaying / isLoading，避免外部状态重建按钮。
class _MiniPlayPauseButton extends StatelessWidget {
  const _MiniPlayPauseButton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Selector<PlayerProvider, ({bool isPlaying, bool isLoading})>(
      selector: (_, p) => (isPlaying: p.isPlaying, isLoading: p.isLoading),
      builder: (_, state, __) {
        return M3ExpressiveMiniPlayer._buildPlayPauseButton(state, cs, context);
      },
    );
  }
}
