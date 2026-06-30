import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/navigation.dart' as app;
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/song.dart';
import '../services/api_client.dart';
import '../services/update_checker.dart';
import '../screens/player_screen.dart';
import '../widgets/support_me_dialog.dart';
import '../widgets/update_dialog.dart';

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
    return Stack(
      children: [
        widget.child ?? const SizedBox.shrink(),
        // MiniPlayer �?覆盖在底部导航栏上方
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
        const _LoginPromptOverlay(),
      ],
    );
  }
}

// ══════════════════════════════════════════════�?
//  移动�?MiniPlayer �?精简版（移除 BackdropFilter 避免 Windows 渲染崩溃�?
// ══════════════════════════════════════════════�?

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
          child: GestureDetector(
            onTap: () {
              player.setPlayerScreenVisible(true);
              app.navKey.currentState
                  ?.push(PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const PlayerScreen(),
                    transitionsBuilder: (_, animation, __, child) {
                      return FadeTransition(
                          opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ))
                  .then((_) => player.setPlayerScreenVisible(false));
            },
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
      final res = await client.get('/lastest/songs/listen',
          params: {'pagesize': 1});
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>? ?? {};
      final body = data['data'] as Map<String, dynamic>? ?? data;
      final devInfo = body['dev_info'] as Map<String, dynamic>?;
      final wording = devInfo?['wording'] as String? ?? '其他设备';
      Map<String, dynamic>? songInfo;
      final currSong = body['curr_song'] as Map?;
      if (currSong is Map) {
        songInfo = (currSong['info'] as Map<String, dynamic>?)
            ?? currSong.cast<String, dynamic>();
      }
      if (songInfo == null) {
        final songs = body['songs'] as List<dynamic>? ?? [];
        if (songs.isNotEmpty && songs[0] is Map<String, dynamic>) {
          songInfo = songs[0] as Map<String, dynamic>;
        }
      }
      if (songInfo != null && mounted) {
        final info = songInfo;
        final songName = (info['name'] as String?
            ?? info['songname'] as String? ?? '未知歌曲')
            .replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
        final singer = info['singername'] as String?;
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
                      if (singer != null) Text(singer, style: Theme.of(context).textTheme.bodySmall),
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
                        final songId = (info['mixsongid'] as num?)?.toInt()
                            ?? (info['id'] as num?)?.toInt() ?? 0;
                        final song = Song(
                          id: songId,
                          name: songName,
                          artists: singer != null ? [singer] : [],
                          albumCoverUrl: (info['cover'] as String?)
                              ?.replaceAll('{size}', '480'),
                          duration: (info['timelen'] as num?)?.toInt() ?? 0,
                          hash: hash,
                        );
                        if (mounted) context.read<PlayerProvider>().playSong(song);
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

    final dismissed = await showSupportMeDialog(context, autoPopup: true);
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
    final release = await UpdateChecker.check();
    if (release != null && mounted) {
      showUpdateDialog(context, release);
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

    final navCtx = Navigator.of(context).context;
    if (!mounted) return;
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
              Navigator.pushNamed(context, '/login');
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
