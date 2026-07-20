import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/navigation.dart' as app;
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/song.dart';
import '../services/api_client.dart';
import '../services/update_checker.dart';
import '../widgets/support_me_dialog.dart';
import '../widgets/update_dialog.dart';
import '../services/announcement_service.dart';
import '../widgets/announcement_dialog.dart';
import '../utils/theme.dart';
import 'm3_expressive_mini_player.dart';

/// 移动端外壳，嵌套在 MaterialApp.builder 中
///
/// Stack(child + MiniPlayer + overlays)
class AppShell extends StatefulWidget {
  final Widget? child;
  const AppShell({super.key, this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    return _mobileShell();
  }

  // ══════════════════════════════════════════════�?
  //  移动�?
  // ══════════════════════════════════════════════�?

  Widget _mobileShell() {
    return ValueListenableBuilder<String?>(
      valueListenable: app.AppRouteObserver.instance.currentRouteNotifier,
      builder: (context, currentRoute, _) {
        // 精确选择：只订阅 MiniPlayer 显隐条件，不随播放进度/歌词变化重建全局 Shell
        final currentSongId =
            context.select<PlayerProvider, int?>((p) => p.currentSong?.id);
        final isMiniDismissed = context
            .select<PlayerProvider, bool>((p) => p.isMiniPlayerDismissed);

        // 判定 Minibar 出现条件：
        // 1. 当前有播放歌曲；
        // 2. 且非核心专注/全屏播放等隐藏页面（登录页 '/login'、全屏播放页 '/player'）
        // 3. 且用户没有手动关闭它
        final isHiddenRoute =
            currentRoute == '/login' || currentRoute == '/player';
        final showMini =
            currentSongId != null && !isHiddenRoute && !isMiniDismissed;

        final mq = MediaQuery.of(context);
        final isHome =
            currentRoute == null || currentRoute == '/' || currentRoute == '';

        final double miniPlayerBottom;
        if (isHome) {
          // Material Design 3 NavigationBar 标准高度为 80.0dp。
          // 定位在 80.0 + mq.padding.bottom 处，正好悬浮于 NavigationBar 正上方，零重叠且不会顶高底栏！
          miniPlayerBottom = 80.0 + mq.padding.bottom;
        } else {
          // 在没有 NavigationBar 的二级子屏幕中，悬浮在系统底部手势栏/黑条正上方
          miniPlayerBottom =
              mq.padding.bottom > 0 ? mq.padding.bottom + 8.0 : 12.0;
        }

        // 注入包含 MiniBar 高度的自适应 MediaQuery 避让区域：
        // 仅在非首页（二级子页面，即无底部 NavigationBar）且 MiniBar 显示时，使主界面的 padding.bottom 追加 MiniBar 物理高（76.0dp）。
        // 首页 Tab 页面内的避让将在 HomeScreen 级别的 body 内部局部注入，以防止全局污染导致 Scaffold 将底部 NavigationBar 错误抬高并与 MiniBar 重叠。
        final double extraPadding = (showMini && !isHome) ? 76.0 : 0.0;
        final childMediaQuery = mq.copyWith(
          padding: mq.padding.copyWith(
            bottom: mq.padding.bottom + extraPadding,
          ),
          viewPadding: mq.viewPadding.copyWith(
            bottom: mq.viewPadding.bottom + extraPadding,
          ),
        );

        return Stack(
          children: [
            MediaQuery(
              data: childMediaQuery,
              child: widget.child ?? const SizedBox.shrink(),
            ),
            // Render M3ExpressiveMiniPlayer with smooth position & opacity transition
            AnimatedPositioned(
              duration: AppMotion.dMedium2,
              curve: AppMotion.emphasizedDecelerate,
              left: 0,
              right: 0,
              bottom: miniPlayerBottom,
              child: AnimatedSwitcher(
                duration: AppMotion.dMedium1,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: showMini
                    ? const M3ExpressiveMiniPlayer()
                    : const SizedBox.shrink(),
              ),
            ),
            const _ContinuePlayOverlay(),
            const _SupportPopupHandler(),
            const _UpdateCheckHandler(),
            const _LoginPromptOverlay(),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════�?
//  跨设备继续播放检�?
// ══════════════════════════════════════════════�?

class _ContinuePlayOverlay extends StatefulWidget {
  const _ContinuePlayOverlay();
  @override
  State<_ContinuePlayOverlay> createState() => _ContinuePlayOverlayState();
}

class _ContinuePlayOverlayState extends State<_ContinuePlayOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 延迟到 Overlay 就绪后再执行
      Future.delayed(const Duration(milliseconds: 500), _check);
    });
  }

  Future<void> _check() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    try {
      final client = ApiClient.instance;
      final res =
          await client.get('/lastest/songs/listen', params: {'pagesize': 1});
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>? ?? {};
      final body = data['data'] as Map<String, dynamic>? ?? data;
      final devInfo = body['dev_info'] as Map<String, dynamic>?;
      final wording = devInfo?['wording'] as String? ?? '其他设备';
      Map<String, dynamic>? songInfo;
      final currSong = body['curr_song'] as Map?;
      if (currSong is Map) {
        songInfo = (currSong['info'] as Map<String, dynamic>?) ??
            currSong.cast<String, dynamic>();
      }
      if (songInfo == null) {
        final songs = body['songs'] as List<dynamic>? ?? [];
        if (songs.isNotEmpty && songs[0] is Map<String, dynamic>) {
          songInfo = songs[0] as Map<String, dynamic>;
        }
      }
      if (songInfo != null && mounted) {
        final info = songInfo;
        final songName =
            (info['name'] as String? ?? info['songname'] as String? ?? '未知歌曲')
                .replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
        final singer = info['singername'] as String?;
        if (!context.mounted) return;
        // 用 Navigator 的 overlay context 保证 Dialog 能正常路由
        final navCtx = Navigator.of(context).context;
        if (!mounted) return;
        showDialog(
            context: navCtx,
            builder: (_) => AlertDialog(
                  title: const Text('继续播放'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('检测到 $wording'),
                      const SizedBox(height: 8),
                      Text(songName,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (singer != null)
                        Text(singer,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(navCtx),
                        child: const Text('取消')),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(navCtx);
                        final hash = info['hash'] as String?;
                        final songId = (info['mixsongid'] as num?)?.toInt() ??
                            (info['id'] as num?)?.toInt() ??
                            0;
                        final song = Song(
                          id: songId,
                          name: songName,
                          artists: singer != null ? [singer] : [],
                          albumCoverUrl: (info['cover'] as String?)
                              ?.replaceAll('{size}', '480'),
                          duration: (info['timelen'] as num?)?.toInt() ?? 0,
                          hash: hash,
                        );
                        if (mounted)
                          context.read<PlayerProvider>().playSong(song);
                      },
                      child: const Text('继续'),
                    ),
                  ],
                ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ══════════════════════════════════════════════�?
//  支持作者弹�?
// ══════════════════════════════════════════════�?

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
  }

  Future<void> _maybeShow() async {
    if (!mounted) return;
    final tp = context.read<ThemeProvider>();
    if (!tp.shouldShowSupportPopup) return;

    final navContext = app.navKey.currentContext ?? context;
    final dismissed = await showSupportMeDialog(navContext, autoPopup: true);
    if (dismissed && mounted) {
      tp.dismissSupportPopup();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ══════════════════════════════════════════════�?
//  启动时检�?GitHub Release 更新
// ══════════════════════════════════════════════�?

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    if (!mounted) return;

    final navContext = app.navKey.currentContext ?? context;

    // 1. 检查更新
    final release = await UpdateChecker.check();
    if (release != null && mounted) {
      await showUpdateDialog(navContext, release);
    }

    // 2. 检查公告
    if (!mounted) return;
    final announcement = await AnnouncementService.fetchLatest();
    if (announcement != null && mounted) {
      await showAnnouncementDialog(navContext, announcement);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 启动时未登录 �?风控提示弹窗（延迟显示，等其他弹窗先弹出�?
class _LoginPromptOverlay extends StatefulWidget {
  const _LoginPromptOverlay();
  @override
  State<_LoginPromptOverlay> createState() => _LoginPromptOverlayState();
}

class _LoginPromptOverlayState extends State<_LoginPromptOverlay> {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _maybeShow();
        });
      });
    }
  }

  Future<void> _maybeShow() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) return;

    final navCtx = app.navKey.currentContext;
    if (navCtx == null || !mounted) return;
    showDialog(
      context: navCtx,
      builder: (ctx) => AlertDialog(
        title: const Text('风控提示'),
        content: const Text('由于酷狗风控机制，建议您登录后再使用'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(navCtx, '/login');
            },
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
