import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class TabletScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final List<Widget> pages;
  final List<BottomNavigationBarItem> tabs;

  const TabletScaffold({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.pages,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isTabletLandscape(context)) {
      return _phoneLayout(context);
    }
    return _tabletLayout(context);
  }

  Widget _phoneBottomNav() {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTabChanged,
      items: tabs,
    );
  }

  Widget _phoneLayout(BuildContext context) {
    final page = pages[currentIndex];
    return Scaffold(
      body: page,
      bottomNavigationBar: _phoneBottomNav(),
    );
  }

  Widget _tabletLayout(BuildContext context) {
    final theme = Theme.of(context);
    final currentPage = pages[currentIndex];
    return Row(
      children: [
        Container(
          width: 80,
          color: theme.colorScheme.surfaceContainerLow,
          child: NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onTabChanged,
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(
                Icons.music_note,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            destinations: tabs
                .map((t) => NavigationRailDestination(
                      icon: t.icon,
                      selectedIcon: t.activeIcon,
                      label: Text(t.label ?? ''),
                    ))
                .toList(),
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant,
        ),
        Expanded(child: currentPage),
      ],
    );
  }
}
