import 'package:flutter/material.dart';

/// 发现页通用横向滚动列表容器。
///
/// 仅提供滚动容器 + 项间距，不包含标题/页眉。
/// 由 [discover_screen.dart] 配合 [DiscoverSectionHeader] 使用，
/// 避免与 [HorizontalCardSection]（内嵌标题）的标题重复。
///
/// 适用于 7 个横向滚动的 Section：
/// 歌单、单曲、专辑、排行榜、场景、FM、编辑精选。
class HorizontalScrollList extends StatelessWidget {
  final double height;
  final int itemCount;
  final double cardWidth;
  final double gap;
  final EdgeInsetsGeometry? padding;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const HorizontalScrollList({
    super.key,
    required this.height,
    required this.itemCount,
    required this.cardWidth,
    required this.itemBuilder,
    this.gap = 12.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(right: index < itemCount - 1 ? gap : 0),
          child: SizedBox(
            width: cardWidth,
            child: itemBuilder(context, index),
          ),
        ),
      ),
    );
  }
}
