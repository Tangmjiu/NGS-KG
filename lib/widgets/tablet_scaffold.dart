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
    return Row(
      children: [
        NavigationRail(
          selectedIndex: currentIndex,
          onDestinationSelected: onTabChanged,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('NGS-KG+',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
          ),
          destinations: tabs
              .map((t) => NavigationRailDestination(
                    icon: t.icon,
                    selectedIcon: t.activeIcon,
                    label: Text(t.label ?? ''),
                  ))
              .toList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: pages[currentIndex]),
      ],
    );
  }
}
