// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/navigation.dart' as app;
import '../routes/app_routes.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/theme.dart';
import '../providers/player_provider.dart';
import 'desktop_player_bar.dart';
import 'desktop_fullscreen_player.dart';
import 'playlist_queue_panel.dart';
import 'desktop_title_bar.dart';

/// 桌面端 Material 3 响应式 Shell 外壳 (`DesktopShell`)
///
/// 参考 Music You (Material You) 桌面端布局:
/// 1. 左侧可收缩侧边栏 (256px 展开 / 72px 折叠),顶部折叠按钮,胶囊选中态。
/// 2. 顶部毛玻璃控制栏:圆形前进/后退按钮、胶囊搜索框、右侧账户头像。
/// 3. 底部常驻 `DesktopPlayerBar` 播放控制栏。
class DesktopShell extends StatefulWidget {
  final Widget? child;
  const DesktopShell({super.key, this.child});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  bool isRailExpanded = true;
  bool _queuePanelVisible = false;
  VoidCallback? _routeListenerRemover;

  @override
  void initState() {
    super.initState();
    final routeNotifier = app.AppRouteObserver.instance.currentRouteNotifier;
    void listener() {
      if (mounted) {
        setState(() {}); // 路由变化时刷新高亮
      }
    }

    routeNotifier.addListener(listener);
    _routeListenerRemover = () => routeNotifier.removeListener(listener);
  }

  @override
  void dispose() {
    _routeListenerRemover?.call();
    super.dispose();
  }

  int _getCurrentSidebarIndex(String? route, int homeTab) {
    if (route == null) return -1;

    // 设置及子页面
    if (route == AppRoutes.settings ||
        route.startsWith('${AppRoutes.settings}/') ||
        route == AppRoutes.about ||
        route == AppRoutes.themeSettings ||
        route == AppRoutes.themeMarket) {
      return 7;
    }

    // 播放历史
    if (route == AppRoutes.history) {
      return 5;
    }

    // 下载管理
    if (route == AppRoutes.downloads) {
      return 4;
    }

    // 云盘
    if (route == AppRoutes.cloud) {
      return 6;
    }

    // 本地音乐
    if (route == AppRoutes.localMusic) {
      return 3;
    }

    // 个人中心及消息/视频子路由
    if (route == AppRoutes.userProfile ||
        route == AppRoutes.messages ||
        route.startsWith('/videos/')) {
      return 2;
    }

    // 详情/歌单分类/电台等，关联到“发现音乐”
    if (route.contains('/detail') ||
        route == AppRoutes.recommendedPlaylists ||
        route == AppRoutes.fm) {
      return 1;
    }

    // 主页及相应Tab
    if (route == '/' || route == AppRoutes.home) {
      if (homeTab == 0) return 0;
      if (homeTab == 1) return 1;
      if (homeTab == 2) return 2;
    }

    return -1;
  }

  void _onSidebarTap(int index) {
    final navState = app.navKey.currentState;
    final navProvider = context.read<NavigationProvider>();
    final currentRoute =
        app.AppRouteObserver.instance.currentRouteNotifier.value;

    // 顶层栏目切换时清空前进栈，避免跨层级导航混乱
    app.AppRouteObserver.instance.clearForward();

    switch (index) {
      case 0: // 首页
        navProvider.setHomeTab(0);
        if (currentRoute != AppRoutes.home) {
          navState?.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        }
        break;
      case 1: // 发现
        navProvider.setHomeTab(1);
        if (currentRoute != AppRoutes.home) {
          navState?.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        }
        break;
      case 2: // 我的
        navProvider.setHomeTab(2);
        if (currentRoute != AppRoutes.home) {
          navState?.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        }
        break;
      case 3: // 本地音乐
        if (currentRoute != AppRoutes.localMusic) {
          navState?.pushNamed(AppRoutes.localMusic);
        }
        break;
      case 4: // 下载管理
        if (currentRoute != AppRoutes.downloads) {
          navState?.pushNamed(AppRoutes.downloads);
        }
        break;
      case 5: // 播放历史
        if (currentRoute != AppRoutes.history) {
          navState?.pushNamed(AppRoutes.history);
        }
        break;
      case 6: // 云盘
        if (currentRoute != AppRoutes.cloud) {
          navState?.pushNamed(AppRoutes.cloud);
        }
        break;
      case 7: // 设置
        if (currentRoute != AppRoutes.settings) {
          navState?.pushNamed(AppRoutes.settings);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navProvider = context.watch<NavigationProvider>();
    final currentRoute =
        app.AppRouteObserver.instance.currentRouteNotifier.value;
    final selectedIndex =
        _getCurrentSidebarIndex(currentRoute, navProvider.currentHomeTab);

    // 注意: DesktopShell 位于 MaterialApp.builder (Navigator 之外),
    // Tooltip 等需要 Overlay 祖先, 因此这里自建一个稳定 Overlay。
    // 自建 Navigator 用于承载桌面 UI 内的弹窗（showM3Dialog /
    // showM3ModalBottomSheet: 播放队列、播放选项、歌词设置等），
    // 否则弹窗 API 依赖的 Navigator.of(context) 会找不到 Navigator 而失效。
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (overlayContext) => Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              settings: settings,
              builder: (_) => Scaffold(
                body: Stack(
                  children: [
                    Column(
                      children: [
                        // 自绘标题栏（应用图标 + 当前播放信息 + 窗口按钮）
                        const DesktopTitleBar(),
                        Expanded(
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  // ─── 左侧导航侧边栏 (Music You 风格) ───
                                  AnimatedContainer(
                                    duration: AppMotion.dMedium1,
                                    curve: Curves.easeInOutCubic,
                                    width: isRailExpanded ? 256.0 : 72.0,
                                    color: colorScheme.surface,
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: [
                                        _buildRailTopBar(context),
                                        Expanded(
                                          child: ListView(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            children: [
                                              if (isRailExpanded)
                                                _buildSectionHeader(
                                                    context, '发现音乐'),
                                              _buildSidebarItem(
                                                icon: Icons.home_outlined,
                                                selectedIcon:
                                                    Icons.home_rounded,
                                                label: '推荐首页',
                                                isSelected: selectedIndex == 0,
                                                onTap: () => _onSidebarTap(0),
                                              ),
                                              _buildSidebarItem(
                                                icon: Icons.explore_outlined,
                                                selectedIcon:
                                                    Icons.explore_rounded,
                                                label: '发现音乐',
                                                isSelected: selectedIndex == 1,
                                                onTap: () => _onSidebarTap(1),
                                              ),
                                              const SizedBox(height: 12),
                                              if (isRailExpanded)
                                                _buildSectionHeader(
                                                    context, '我的音乐'),
                                              _buildSidebarItem(
                                                icon: Icons
                                                    .person_outline_rounded,
                                                selectedIcon:
                                                    Icons.person_rounded,
                                                label: '个人中心',
                                                isSelected: selectedIndex == 2,
                                                onTap: () => _onSidebarTap(2),
                                              ),
                                              _buildSidebarItem(
                                                icon: Icons.music_note_outlined,
                                                selectedIcon:
                                                    Icons.music_note_rounded,
                                                label: '本地音乐',
                                                isSelected: selectedIndex == 3,
                                                onTap: () => _onSidebarTap(3),
                                              ),
                                              _buildSidebarItem(
                                                icon: Icons
                                                    .download_for_offline_outlined,
                                                selectedIcon: Icons
                                                    .download_for_offline_rounded,
                                                label: '下载管理',
                                                isSelected: selectedIndex == 4,
                                                onTap: () => _onSidebarTap(4),
                                              ),
                                              _buildSidebarItem(
                                                icon: Icons.history_rounded,
                                                selectedIcon:
                                                    Icons.history_rounded,
                                                label: '播放历史',
                                                isSelected: selectedIndex == 5,
                                                onTap: () => _onSidebarTap(5),
                                              ),
                                              _buildSidebarItem(
                                                icon: Icons.cloud_outlined,
                                                selectedIcon:
                                                    Icons.cloud_queue_rounded,
                                                label: '云盘歌曲',
                                                isSelected: selectedIndex == 6,
                                                onTap: () => _onSidebarTap(6),
                                              ),
                                              const SizedBox(height: 12),
                                              if (isRailExpanded)
                                                _buildSectionHeader(
                                                    context, '设置'),
                                              _buildSidebarItem(
                                                icon: Icons.settings_outlined,
                                                selectedIcon:
                                                    Icons.settings_rounded,
                                                label: '设置中心',
                                                isSelected: selectedIndex == 7,
                                                onTap: () => _onSidebarTap(7),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 垂直分割线
                                  VerticalDivider(
                                    thickness: 1,
                                    width: 1,
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.3),
                                  ),

                                  // ─── 桌面端主视图区域 ───
                                  Expanded(
                                    child: Column(
                                      children: [
                                        // 统一的桌面端顶部栏
                                        _DesktopHeader(
                                            currentRoute: currentRoute,
                                            cs: colorScheme),
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: widget.child ??
                                                    const SizedBox.shrink(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 播放队列常驻侧栏（主流播放器方式，位于主区域右侧）
                                  AnimatedContainer(
                                    duration: AppMotion.dMedium2,
                                    curve: AppMotion.emphasizedDecelerate,
                                    width: _queuePanelVisible ? 340 : 0,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: _queuePanelVisible
                                          ? colorScheme.surfaceContainerLow
                                          : Colors.transparent,
                                    ),
                                    child: _queuePanelVisible
                                        ? SafeArea(
                                            child: Consumer<PlayerProvider>(
                                              builder: (_, player, __) =>
                                                  PlaylistQueuePanel(
                                                player: player,
                                                onClose: () => setState(() =>
                                                    _queuePanelVisible = false),
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                              // 桌面端底部悬浮常驻 PlayBar
                              // 横跨主区域+队列侧栏（侧栏展开时播放条不变窄，避免溢出）
                              Positioned(
                                left: (isRailExpanded ? 256.0 : 72.0) + 33,
                                right: 32,
                                bottom: 24,
                                height: 72,
                                child: DesktopPlayerBar(
                                  queueVisible: _queuePanelVisible,
                                  onToggleQueue: () => setState(() =>
                                      _queuePanelVisible = !_queuePanelVisible),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 桌面端全屏播放界面 (覆盖侧边栏)
                    Positioned.fill(
                      child: Consumer<PlayerProvider>(
                        builder: (context, player, _) {
                          return AnimatedSwitcher(
                            duration: AppMotion.dMedium2,
                            switchInCurve: AppMotion.emphasizedDecelerate,
                            switchOutCurve: AppMotion.emphasizedAccelerate,
                            transitionBuilder: (child, animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.15),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(
                                    opacity: animation, child: child),
                              );
                            },
                            child: player.isPlayerScreenVisible
                                ? DesktopFullscreenPlayer(
                                    key: const ValueKey(
                                        'DesktopFullscreenPlayer'),
                                    onClose: () =>
                                        player.setPlayerScreenVisible(false),
                                  )
                                : const SizedBox.shrink(key: ValueKey('Empty')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 侧边栏顶部折叠按钮 ──
  Widget _buildRailTopBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: isRailExpanded ? '收起导航栏' : '展开导航栏',
        child: IconButton(
          onPressed: () => setState(() => isRailExpanded = !isRailExpanded),
          style: IconButton.styleFrom(
            foregroundColor: cs.onSurfaceVariant,
            minimumSize: const Size(36, 36),
            maximumSize: const Size(36, 36),
          ),
          icon: Icon(
            isRailExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: _SidebarItem(
        icon: icon,
        selectedIcon: selectedIcon,
        label: label,
        isSelected: isSelected,
        isRailExpanded: isRailExpanded,
        onTap: onTap,
      ),
    );
  }
}

/// 侧边栏单项: Material 透明层包裹, 涟漪/悬停反馈可见
class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final bool isRailExpanded;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.isRailExpanded,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AppMotion.dShort4,
        curve: AppMotion.emphasized,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.35)
              : (_isHovered
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                  : Colors.transparent),
          borderRadius: AppShape.md,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppShape.md,
          child: InkWell(
            onTap: widget.onTap,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: widget.isRailExpanded
                    ? Row(
                        children: [
                          Icon(
                            isSelected ? widget.selectedIcon : widget.icon,
                            size: 20,
                            color:
                                isSelected ? cs.primary : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected ? cs.primary : cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Icon(
                          isSelected ? widget.selectedIcon : widget.icon,
                          size: 20,
                          color: isSelected ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 统一的桌面端顶部栏 (Music You 风格: 毛玻璃 + 圆形导航按钮 + 真实搜索栏)
class _DesktopHeader extends StatefulWidget {
  final String? currentRoute;
  final ColorScheme cs;

  const _DesktopHeader({required this.currentRoute, required this.cs});

  @override
  State<_DesktopHeader> createState() => _DesktopHeaderState();
}

class _DesktopHeaderState extends State<_DesktopHeader> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final navState = app.navKey.currentState;
    final observer = app.AppRouteObserver.instance;
    final cs = widget.cs;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.72),
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // 圆形前进/后退按钮 (实时监听 Navigator 状态)
              ValueListenableBuilder<bool>(
                valueListenable: observer.canPopNotifier,
                builder: (_, canPop, __) => _circleNavButton(
                  context,
                  icon: Icons.arrow_back_ios_new_rounded,
                  enabled: canPop,
                  tooltip: '后退',
                  onPressed: canPop ? () => navState?.pop() : null,
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: observer.canForwardNotifier,
                builder: (_, canForward, __) => _circleNavButton(
                  context,
                  icon: Icons.arrow_forward_ios_rounded,
                  enabled: canForward,
                  tooltip: '前进',
                  onPressed: canForward ? () => observer.forward() : null,
                ),
              ),
              const SizedBox(width: 20),

              // MD3 Search bar: 真实输入, Enter 跳转搜索页并携带关键词
              _M3SearchBar(
                controller: _searchCtrl,
                focusNode: _focusNode,
                onSubmitted: (kw) {
                  final keyword = kw.trim();
                  if (keyword.isEmpty) return;
                  _searchCtrl.clear();
                  _focusNode.unfocus();
                  if (widget.currentRoute != AppRoutes.search) {
                    app.navKey.currentState
                        ?.pushNamed(AppRoutes.search, arguments: keyword);
                  } else {
                    // 已在搜索页: 通过已存在的页面实例重搜
                    app.SearchRestarter.restart(keyword);
                  }
                },
              ),
              const Spacer(),

              // 右侧账户头像区
              if (auth.isLoggedIn && auth.user != null)
                InkWell(
                  onTap: () =>
                      app.navKey.currentState?.pushNamed(AppRoutes.userProfile),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: auth.user!.avatarUrl != null &&
                                  auth.user!.avatarUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  auth.user!.avatarUrl!)
                              : null,
                          child: auth.user!.avatarUrl == null ||
                                  auth.user!.avatarUrl!.isEmpty
                              ? Icon(Icons.person,
                                  size: 18, color: cs.onSurfaceVariant)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          auth.user!.nickname ?? '',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                TextButton.icon(
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('未登录'),
                  onPressed: () =>
                      app.navKey.currentState?.pushNamed(AppRoutes.login),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleNavButton(
    BuildContext context, {
    required IconData icon,
    required bool enabled,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    final cs = widget.cs;
    return IconButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor:
            enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.3),
        disabledForegroundColor: cs.onSurface.withValues(alpha: 0.3),
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        disabledBackgroundColor: Colors.transparent,
        fixedSize: const Size(42, 42),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

/// MD3 Search bar: 圆角 16, 悬停/聚焦状态反馈
class _M3SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  const _M3SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  @override
  State<_M3SearchBar> createState() => _M3SearchBarState();
}

class _M3SearchBarState extends State<_M3SearchBar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFocused = widget.focusNode.hasFocus;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AppMotion.dShort4,
        curve: AppMotion.emphasized,
        width: 240,
        height: 44,
        decoration: BoxDecoration(
          color: isFocused || _isHovered
              ? cs.surfaceContainerHigh
              : cs.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFocused
                ? cs.primary.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20,
              color: isFocused ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
                cursorColor: cs.primary,
                decoration: InputDecoration(
                  hintText: '搜索歌曲、歌单、歌手',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: widget.onSubmitted,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (_, value, __) => value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      color: cs.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.controller.clear(),
                    )
                  : const SizedBox(width: 40),
            ),
          ],
        ),
      ),
    );
  }
}
