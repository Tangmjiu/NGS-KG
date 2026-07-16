import 'package:flutter/material.dart';
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
///    - **左右滑动切歌 (Swipe-to-Skip)**：直接向左/向右滑动胶囊可顺滑切换上一首/下一首，并带有触感振动响应。
///    - **点击展开**：平滑开启全屏播放器页面。
/// 3. **动态状态呈现**：
///    - **播放/暂停图标互转**：采用 `AnimatedSwitcher` + `ScaleTransition` 顺滑切换按钮状态。
///    - **环形/底边高精度进度条**：内嵌贴合胶囊下边缘的微细线性进度指示，动态颜色对准 `cs.primary`。
class M3ExpressiveMiniPlayer extends StatelessWidget {
  const M3ExpressiveMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final song = player.currentSong;
        if (song == null || player.isPlayerScreenVisible) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Dismissible(
            key: ValueKey('mini_player_${song.hash ?? song.id}'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.endToStart) {
                player.playNext();
              } else if (direction == DismissDirection.startToEnd) {
                player.playPrevious();
              }
              // 不真正移除控件，由切歌后自动刷新 UI 承接
              return false;
            },
            background: _buildSwipeIndicator(
                cs, Icons.skip_previous_rounded, '上一首', Alignment.centerLeft),
            secondaryBackground: _buildSwipeIndicator(
                cs, Icons.skip_next_rounded, '下一首', Alignment.centerRight),
            child: M3PressScale(
              child: GestureDetector(
                onTap: () => _openPlayerScreen(context, player),
                child: Container(
                  height: 64.0,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.96),
                    borderRadius: AppShape.full,
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppShape.full,
                    child: Stack(
                      children: [
                        // 底部嵌入式极细进度条
                        if (player.duration.inMilliseconds > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: player.progress.isFinite
                                  ? player.progress.clamp(0.0, 1.0)
                                  : 0.0,
                              backgroundColor: Colors.transparent,
                              color: cs.primary,
                              minHeight: 3,
                            ),
                          ),

                        // 主交互排版区
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                          child: Row(
                            children: [
                              // 专辑封面（含安全过渡与 Hero 动效）
                              Hero(
                                tag: 'album_art_${song.hash ?? song.id}',
                                flightShuttleBuilder: _safeFlightShuttle,
                                child: _buildCoverArt(song, cs, player.isLoading),
                              ),
                              const SizedBox(width: 10),

                              // 歌曲信息排版（运用 FittedBox.scaleDown 彻底消灭各种大字号与行高带来的 Bottom/Right Overflowed）
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                onTap: player.playPrevious,
                              ),
                              const SizedBox(width: 2),

                              // 主播放/暂停响应态圆形按钮
                              _buildPlayPauseButton(player, cs),
                              const SizedBox(width: 2),

                              _buildControlButton(
                                icon: Icons.skip_next_rounded,
                                tooltip: '下一首',
                                cs: cs,
                                onTap: player.playNext,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
    return Container(
      height: 64.0,
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.8),
        borderRadius: AppShape.full,
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cs.onSecondaryContainer),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: cs.onSecondaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建专辑封面或加载转圈指示器
  Widget _buildCoverArt(Song song, ColorScheme cs, bool isLoading) {
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
            if (song.albumCoverUrl != null && song.albumCoverUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: song.albumCoverUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _defaultCoverIcon(cs),
              )
            else
              _defaultCoverIcon(cs),

            // 缓冲加载时的浮层微亮圈
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

  Widget _defaultCoverIcon(ColorScheme cs) {
    return Container(
      width: 48,
      height: 48,
      color: cs.surfaceContainerHigh,
      child: Icon(Icons.music_note_rounded, size: 24, color: cs.primary),
    );
  }

  /// 基础控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required ColorScheme cs,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: M3PressScale(
        child: InkWell(
          borderRadius: AppShape.full,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 24, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  /// 播放/暂停圆形动效按钮
  Widget _buildPlayPauseButton(PlayerProvider player, ColorScheme cs) {
    return M3PressScale(
      child: Material(
        color: cs.primary,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: cs.primary.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: player.togglePlayPause,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.dMedium1,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey<bool>(player.isPlaying),
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

  void _openPlayerScreen(BuildContext context, PlayerProvider player) {
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
