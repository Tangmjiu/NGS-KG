import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';
import '../screens/player_screen.dart';
import '../screens/search_screen.dart';
import '../widgets/player_desktop_view.dart';

/// 内容区模式
enum ContentMode { browse, player }

/// 自适应外壳，嵌套在 MaterialApp.builder 中。
///
/// 桌面（≥880px）:
///   browse: Row(NavigationRail + Expanded(Stack(child + MiniPlayer)))
///   player: PlayerDesktopView（全宽沉浸，NavRail/MiniPlayer 隐藏）
///
/// 移动（<880px）:
///   Stack(child + MiniPlayer + overlays)
///   与原有 main.dart 行为一致。
class AppShell extends StatefulWidget {
  final Widget? child;
  const AppShell({super.key, this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentTab = 0;
  ContentMode _mode = ContentMode.browse;

  void openPlayer() => setState(() => _mode = ContentMode.player);
  void closePlayer() => setState(() => _mode = ContentMode.browse);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 880) return _desktopShell();
        return _mobileShell();
      },
    );
  }

  // ═══════════════════════════════════════════════
  //  移动端
  // ═══════════════════════════════════════════════

  Widget _mobileShell() {
    return Stack(
      children: [
        widget.child ?? const SizedBox.shrink(),
        // MiniPlayer — 覆盖在底部导航栏上方
        Positioned(
          left: 0,
          right: 0,
          bottom: kBottomNavigationBarHeight +
              MediaQuery.of(context).padding.bottom,
          child: const _MobileMiniPlayer(),
        ),
        const _ContinuePlayOverlay(),
        const _SupportPopupHandler(),
        const _UpdateCheckHandler(),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  //  桌面端
  // ═══════════════════════════════════════════════

  Widget _desktopShell() {
    // Player 模式：全宽沉浸，无 NavRail，无 MiniPlayer
    if (_mode == ContentMode.player) {
      return PlayerDesktopView(onClose: closePlayer);
    }

    return Row(
      children: [
        NavigationRail(
          selectedIndex: _currentTab,
          onDestinationSelected: (i) {
            setState(() => _currentTab = i);
            if (i == 0) {
              Navigator.of(context)
                  .popUntil((route) => route.settings.name == '/');
            }
          },
          labelType: NavigationRailLabelType.all,
          backgroundColor: Colors.transparent,
          indicatorColor:
              Theme.of(context).colorScheme.secondaryContainer,
          leading: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
          ),
          trailing: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '设置',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: Text('首页'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: Text('发现'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: Text('我的'),
            ),
          ],
        ),
        Expanded(
          child: Stack(
            children: [
              widget.child ?? const SizedBox.shrink(),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _DesktopMiniPlayer(onTap: openPlayer),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  桌面版 MiniPlayer — 跟随主题
// ═══════════════════════════════════════════════

class _DesktopMiniPlayer extends StatelessWidget {
  final VoidCallback? onTap;
  const _DesktopMiniPlayer({this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: cs.outlineVariant, width: 0.5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _cover(song, cs),
                    const SizedBox(width: 12),
                    Expanded(child: _info(song, cs)),
                    _controls(player, cs),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cover(Song song, ColorScheme cs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 44,
        height: 44,
        child: song.albumCoverUrl != null
            ? CachedNetworkImage(
                imageUrl: song.albumCoverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                      color: cs.surfaceContainerHigh,
                      child: Icon(Icons.music_note, size: 22, color: cs.onSurfaceVariant),
                    ),
              )
            : Container(
                color: cs.surfaceContainerHigh,
                child: Icon(Icons.music_note, size: 22, color: cs.onSurfaceVariant),
              ),
      ),
    );
  }

  Widget _info(Song song, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                fontSize: 14)),
        const SizedBox(height: 1),
        Text(song.artistDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: cs.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }

  Widget _controls(PlayerProvider player, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniBtn(Icons.skip_previous, player.playPrevious, cs),
        const SizedBox(width: 4),
        Container(
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              player.isPlaying ? Icons.pause : Icons.play_arrow,
              color: cs.onPrimary,
              size: 20,
            ),
            onPressed: player.togglePlayPause,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
        const SizedBox(width: 4),
        _miniBtn(Icons.skip_next, player.playNext, cs),
      ],
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback? onTap, ColorScheme cs) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 20, color: cs.onSurfaceVariant),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  移动版 MiniPlayer — 精简版（移除 BackdropFilter 避免 Windows 渲染崩溃）
// ═══════════════════════════════════════════════

class _MobileMiniPlayer extends StatelessWidget {
  const _MobileMiniPlayer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final song = player.currentSong;
        if (song == null || player.isPlayerScreenVisible)
          return const SizedBox.shrink();
        final tt = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (player.duration.inMilliseconds > 0)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: LinearProgressIndicator(
                        value: player.progress.isFinite ? player.progress : 0.0,
                        backgroundColor: cs.surfaceContainerHigh,
                        color: cs.primary,
                        minHeight: 2,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 8, right: 12, top: 6,
                      bottom: MediaQuery.of(context).padding.bottom + 4,
                    ),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'album_art_${song.hash ?? song.id}',
                          child: _miniCover(song, cs),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(song.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                              const SizedBox(height: 2),
                              Text(song.artistDisplay,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (player.isLoading)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(width: 28, height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: cs.primary)),
                          )
                        else ...[
                          _mobileBtn(Icons.skip_previous, player.playPrevious, cs),
                          const SizedBox(width: 4),
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: cs.primary, shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                player.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: cs.onPrimary, size: 22,
                              ),
                              onPressed: player.togglePlayPause,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _mobileBtn(Icons.skip_next, player.playNext, cs),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniCover(Song song, ColorScheme cs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 44, height: 44,
        child: song.albumCoverUrl != null && song.albumCoverUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: song.albumCoverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: cs.surfaceContainerHigh,
                  child: Icon(Icons.music_note, size: 22, color: cs.onSurfaceVariant),
                ),
              )
            : Container(
                color: cs.surfaceContainerHigh,
                child: Icon(Icons.music_note, size: 22, color: cs.onSurfaceVariant),
              ),
      ),
    );
  }

  Widget _mobileBtn(IconData icon, VoidCallback? onTap, ColorScheme cs) {
    return SizedBox(
      width: 36, height: 36,
      child: IconButton(
        icon: Icon(icon, size: 22, color: cs.onSurfaceVariant),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Overlay handlers（简化版）
// ═══════════════════════════════════════════════

class _ContinuePlayOverlay extends StatefulWidget {
  const _ContinuePlayOverlay();
  @override
  State<_ContinuePlayOverlay> createState() => _ContinuePlayOverlayState();
}

class _ContinuePlayOverlayState extends State<_ContinuePlayOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SupportPopupHandler extends StatefulWidget {
  const _SupportPopupHandler();
  @override
  State<_SupportPopupHandler> createState() => _SupportPopupHandlerState();
}

class _SupportPopupHandlerState extends State<_SupportPopupHandler> {
  bool _shown = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _UpdateCheckHandler extends StatefulWidget {
  const _UpdateCheckHandler();
  @override
  State<_UpdateCheckHandler> createState() => _UpdateCheckHandlerState();
}

class _UpdateCheckHandlerState extends State<_UpdateCheckHandler> {
  bool _checked = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
