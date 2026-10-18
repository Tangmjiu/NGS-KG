// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../../utils/navigation.dart';
import '../app_ui.dart';
import '../components/mini_player.dart';
import 'app_background.dart';
import 'app_startup_overlays.dart';

/// 页面、常驻播放栏与启动提示的统一宿主。
class AppShell extends StatelessWidget {
  final Widget? child;
  const AppShell({super.key, this.child});

  @override
  Widget build(BuildContext context) => _ShellOverlay(
          child: ValueListenableBuilder<String?>(
        valueListenable: AppRouteObserver.instance.currentRouteNotifier,
        builder: (context, route, _) {
          final showMini = context.select<PlayerProvider, bool>((player) =>
                  player.currentSong != null &&
                  !player.isMiniPlayerDismissed &&
                  !player.isPlayerScreenVisible) &&
              route != '/player' &&
              route != '/login';
          final media = MediaQuery.of(context);
          final isHome = route == null || route.isEmpty || route == '/';
          final rail = isHome && AppChrome.usesRail(media.size.width);
          final bottom = isHome && !rail
              ? AppChrome.navigationExtent + media.padding.bottom
              : media.padding.bottom + 8;
          final extra = showMini && !isHome
              ? AppChrome.miniPlayerExtent(context) + 8
              : 0.0;
          return Stack(
            children: [
              const Positioned.fill(child: AppBackground()),
              MediaQuery(
                data: media.copyWith(
                  padding: media.padding
                      .copyWith(bottom: media.padding.bottom + extra),
                  viewPadding: media.viewPadding
                      .copyWith(bottom: media.viewPadding.bottom + extra),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
              AnimatedPositioned(
                duration: AppMotion.duration(context, AppMotion.dMedium2),
                curve: AppMotion.emphasizedDecelerate,
                left: rail ? AppChrome.railExtent + media.padding.left : 0,
                right: 0,
                bottom: bottom,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: AnimatedSwitcher(
                      duration: AppMotion.duration(context, AppMotion.dShort4),
                      child: showMini
                          ? const MiniPlayer()
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              const AppStartupOverlays(),
            ],
          );
        },
      ));
}

/// 常驻播放栏位于页面导航器之外，也需要完整屏幕的浮层来显示按钮提示。
class _ShellOverlay extends StatefulWidget {
  final Widget child;
  const _ShellOverlay({required this.child});

  @override
  State<_ShellOverlay> createState() => _ShellOverlayState();
}

class _ShellOverlayState extends State<_ShellOverlay> {
  late final OverlayEntry _content = OverlayEntry(
    opaque: true,
    builder: (_) => widget.child,
  );

  @override
  void didUpdateWidget(_ShellOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _content.markNeedsBuild();
  }

  @override
  void dispose() {
    _content.remove();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_content]);
}
