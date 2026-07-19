import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../utils/theme.dart';

/// 到底了 & 自适应避让占位组件
///
/// 当 MiniPlayer 显示时，能够以平滑动画展开底部高度，保证“到底了”字样露在 MiniPlayer 上方。
class ListBottomSpacer extends StatelessWidget {
  final bool isHome;
  final bool showText;

  const ListBottomSpacer({
    super.key,
    this.isHome = false,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // 精确选择：只订阅 MiniPlayer 显隐条件，不随播放进度重建
    final showMini = context.select<PlayerProvider, bool>(
      (p) => p.currentSong != null && !p.isPlayerScreenVisible,
    );

    double spacerHeight;
    if (isHome) {
      spacerHeight = showMini ? 156.0 : 80.0;
    } else {
      spacerHeight = showMini ? 92.0 : 24.0;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showText) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 12),
              Text(
                '已经到底了',
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ],
          ),
        ],
        AnimatedContainer(
          duration: AppMotion.dMedium2,
          curve: AppMotion.emphasizedDecelerate,
          height: spacerHeight,
        ),
      ],
    );
  }
}
