import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';

/// 播放控制核心按键组 (上一首、播放/暂停、下一首)
///
/// 特性规范：
/// 1. **弹性按压交互 (Tactile Scale)**：全按键统一封装 `M3PressScale`，并结合 `mediumImpact` 触感震动。
/// 2. **自旋转播放转场 (Morphing Transition)**：播放/暂停图标在 AnimatedSwitcher 切换时，自旋 90 度并伴随缩放淡入。
class PlayerControlsBar extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final bool isDesktop;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const PlayerControlsBar({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) return _buildDesktop(context);
    return _buildMobile(context);
  }

  Widget _buildMobile(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -- Previous --
        M3PressScale(
          child: IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 38, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              onPrevious();
            },
            splashRadius: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
          ),
        ),

        const SizedBox(width: 16),

        // -- Play / Pause --
        M3PressScale(
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              onPlayPause();
            },
            borderRadius: AppShape.xl,
            customBorder: const CircleBorder(),
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.dMedium1,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: RotationTransition(
                      turns: Tween<double>(begin: -0.25, end: 0.0).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
                child: _buildPlayPauseChildMobile(),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // -- Next --
        M3PressScale(
          child: IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 38, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              onNext();
            },
            splashRadius: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
          ),
        ),
      ],
    );
  }

  /// 桌面端
  Widget _buildDesktop(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(isPlaying ? 16 : 26);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        M3PressScale(
          child: IconButton(
            icon: Icon(Icons.skip_previous_rounded, size: 32, color: cs.onSurface),
            onPressed: () {
              HapticFeedback.lightImpact();
              onPrevious();
            },
            tooltip: '上一首',
          ),
        ),
        const SizedBox(width: 12),
        M3PressScale(
          child: AnimatedContainer(
            duration: AppMotion.dMedium1,
            curve: AppMotion.emphasized,
            width: isPlaying ? 58 : 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: () {
                HapticFeedback.mediumImpact();
                onPlayPause();
              },
              child: AnimatedSwitcher(
                duration: AppMotion.dMedium1,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: RotationTransition(
                      turns: Tween<double>(begin: -0.25, end: 0.0).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
                child: _buildPlayPauseChildDesktop(cs),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        M3PressScale(
          child: IconButton(
            icon: Icon(Icons.skip_next_rounded, size: 32, color: cs.onSurface),
            onPressed: () {
              HapticFeedback.lightImpact();
              onNext();
            },
            tooltip: '下一首',
          ),
        ),
      ],
    );
  }

  Widget _buildPlayPauseChildMobile() {
    if (isLoading) {
      return const SizedBox(
        key: ValueKey('loading'),
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.black54,
        ),
      );
    }

    return Icon(
      key: ValueKey(isPlaying),
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 38,
      color: Colors.black87,
    );
  }

  Widget _buildPlayPauseChildDesktop(ColorScheme cs) {
    if (isLoading) {
      return SizedBox(
        key: const ValueKey('loading'),
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: cs.primary,
        ),
      );
    }

    return Icon(
      key: ValueKey(isPlaying),
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 30,
      color: cs.onPrimaryContainer,
    );
  }
}
