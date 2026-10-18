// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../foundation/app_layout.dart';
import '../foundation/app_motion.dart';
import '../foundation/app_spring.dart';

/// 共用目的地，底部导航与侧边导航保持相同顺序和辅助功能语义。
class AppNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool rail;

  const AppNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.rail = false,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, '首页'),
    (Icons.explore_outlined, Icons.explore_rounded, '发现'),
    (Icons.search_rounded, Icons.search_rounded, '搜索'),
    (Icons.library_music_outlined, Icons.library_music_rounded, '资料库'),
  ];

  Widget _icon(int index) => AppSpring(
        value: selectedIndex == index ? 1.12 : 1,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child:
            Icon(selectedIndex == index ? _items[index].$2 : _items[index].$1),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (rail) {
      return SafeArea(
        right: false,
        child: NavigationRail(
          minWidth: AppChrome.railExtent,
          backgroundColor: Colors.transparent,
          groupAlignment: -0.65,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          labelType: NavigationRailLabelType.all,
          useIndicator: true,
          indicatorColor: colors.secondaryContainer,
          destinations: [
            for (var index = 0; index < _items.length; index++)
              NavigationRailDestination(
                icon: Tooltip(message: _items[index].$3, child: _icon(index)),
                label: Text(_items[index].$3),
              ),
          ],
        ),
      );
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        height: AppChrome.navigationExtent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Material(
                elevation: NavigationBarTheme.of(context).elevation ?? 3,
                shadowColor: colors.shadow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(40),
                clipBehavior: Clip.antiAlias,
                child: NavigationBar(
                  height: 64,
                  elevation: 0,
                  backgroundColor: colors.surfaceContainer,
                  indicatorColor: colors.secondaryContainer,
                  animationDuration:
                      AppMotion.duration(context, AppMotion.dMedium2),
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelected,
                  labelBehavior: MediaQuery.textScalerOf(context).scale(12) > 20
                      ? NavigationDestinationLabelBehavior.alwaysHide
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [
                    for (var index = 0; index < _items.length; index++)
                      NavigationDestination(
                        icon: _icon(index),
                        label: _items[index].$3,
                        tooltip: _items[index].$3,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
