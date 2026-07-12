import 'package:flutter/material.dart';
import '../widgets/staggered_fade_slide.dart';

/// 发现页通用横向滚动卡片区块
///
/// 包含：标题行（可带"查看更多"）+ 横向 ListView
/// 替代了原来 discover_screen.dart 中 8 个重复的
/// SizedBox + ListView.builder + GestureDetector 模式。
class HorizontalCardSection extends StatelessWidget {
  final String title;
  final int itemCount;
  final double height;
  final double cardWidth;
  final EdgeInsetsGeometry? padding;
  final double gap;
  final VoidCallback? onViewAll;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const HorizontalCardSection({
    super.key,
    required this.title,
    required this.itemCount,
    required this.height,
    required this.cardWidth,
    required this.itemBuilder,
    this.padding,
    this.gap = 12.0,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──
        Padding(
          padding: padding ??
              const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Text(
                title,
                style: tt.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    '查看更多',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Horizontal card list ──
        SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            itemBuilder: (context, index) => StaggeredFadeSlide(
              index: index,
              slideOffset: 8,
              staggerMs: 20,
              child: Padding(
                padding: EdgeInsets.only(right: index < itemCount - 1 ? gap : 0),
                child: SizedBox(
                  width: cardWidth,
                  child: itemBuilder(context, index),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
