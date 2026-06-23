import 'package:flutter/material.dart';
import 'desktop_route_wrapper.dart';

/// InheritedWidget that provides shell-level navigation to content pages.
///
/// When a screen is rendered inside [DesktopShell], it can use this scope
/// to push detail pages (playlist, album, artist, etc.) **within** the shell,
/// keeping the sidebar and bottom player bar visible.
///
/// On mobile (no shell ancestor) these methods are unavailable, and screens
/// fall back to [Navigator.pushNamed].
class ShellNavigationScope extends InheritedWidget {
  /// Push a full-content page inside the shell (replaces content area).
  final void Function(Widget page) openInShell;

  /// Pop the topmost shell page.
  final VoidCallback pop;

  /// Whether there are shell pages to pop.
  final bool canPop;

  /// Switch to a sidebar navigation tab (home/discover/profile/ranking/recent).
  final void Function(String navId) navigateToSidebar;

  /// Open the full-screen player (replaces DesktopShell entirely).
  final VoidCallback openPlayer;

  const ShellNavigationScope({
    super.key,
    required this.openInShell,
    required this.pop,
    required this.canPop,
    required this.navigateToSidebar,
    required this.openPlayer,
    required super.child,
  });

  static ShellNavigationScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellNavigationScope>();
  }

  /// Navigate to a route, preferring shell navigation when available.
  ///
  /// [routeName] and [arguments] are used as fallback via [Navigator.pushNamed]
  /// when not inside a shell. [shellPageBuilder] constructs the actual page
  /// widget to push inside the shell.
  static void navigate(
    BuildContext context, {
    required String routeName,
    Object? arguments,
    required Widget Function() shellPageBuilder,
  }) {
    final scope = ShellNavigationScope.of(context);
    if (scope != null) {
      scope.openInShell(shellPageBuilder());
    } else {
      Navigator.pushNamed(context, routeName, arguments: arguments);
    }
  }

  /// Push a widget-based page, preferring shell navigation when available.
  ///
  /// Used for pages that are pushed via [Navigator.push] with a [Route] builder
  /// (e.g. [MaterialPageRoute]). In shell the [page] is wrapped with a
  /// [DesktopRouteWrapper] (with optional [title]) so it has a back button.
  /// Outside shell the [routeBuilder] is used directly.
  static void push(
    BuildContext context, {
    required Widget page,
    String? title,
    required Route Function() routeBuilder,
  }) {
    final scope = ShellNavigationScope.of(context);
    if (scope != null) {
      // Wrap with DesktopRouteWrapper to ensure a back button on desktop
      scope.openInShell(
        title != null
            ? DesktopRouteWrapper(title: title, child: page)
            : page,
      );
    } else {
      Navigator.push(context, routeBuilder());
    }
  }

  /// Switch to a sidebar tab by ID (e.g. 'home', 'discover', 'profile', 'recent').
  static void switchToSidebarTab(BuildContext context, String navId) {
    final scope = ShellNavigationScope.of(context);
    if (scope != null) {
      scope.navigateToSidebar(navId);
    }
  }

  /// Open the full-screen player.
  static void openFullScreenPlayer(BuildContext context) {
    final scope = ShellNavigationScope.of(context);
    if (scope != null) {
      scope.openPlayer();
    }
  }

  @override
  bool updateShouldNotify(ShellNavigationScope oldWidget) {
    return oldWidget.canPop != canPop ||
        oldWidget.openInShell != openInShell ||
        oldWidget.pop != pop ||
        oldWidget.navigateToSidebar != navigateToSidebar ||
        oldWidget.openPlayer != openPlayer;
  }
}
