// SPDX-License-Identifier: MIT
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/navigation.dart' as app;
import '../../providers/player_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/song.dart';
import '../../services/api_client.dart';
import '../../services/update_checker.dart';
import '../../widgets/support_me_dialog.dart';
import '../../widgets/update_dialog.dart';
import '../../services/announcement_service.dart';
import '../../widgets/announcement_dialog.dart';

class AppStartupOverlays extends StatelessWidget {
  const AppStartupOverlays({super.key});

  @override
  Widget build(BuildContext context) => const Stack(children: [
        _ContinuePlayOverlay(),
        _SupportPopupHandler(),
        _UpdateCheckHandler(),
        _LoginPromptOverlay(),
      ]);
}

class _ContinuePlayOverlay extends StatefulWidget {
  const _ContinuePlayOverlay();
  @override
  State<_ContinuePlayOverlay> createState() => _ContinuePlayOverlayState();
}

class _ContinuePlayOverlayState extends State<_ContinuePlayOverlay> {
  Timer? _continueTimer;

  @override
  void dispose() {
    _continueTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 延迟到 Overlay 就绪后再执行
      if (!mounted) return;
      _continueTimer = Timer(const Duration(milliseconds: 500), _check);
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
        final navCtx = app.navKey.currentState?.overlay?.context ??
            app.navKey.currentContext;
        if (navCtx == null) return;
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
                        if (mounted) {
                          context.read<PlayerProvider>().playSong(song);
                        }
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

    // 1. 检查更新
    final release = await UpdateChecker.check();
    if (release != null && mounted) {
      final navContext = app.navKey.currentState?.overlay?.context ?? context;
      if (!navContext.mounted) return;
      await showUpdateDialog(navContext, release);
    }

    // 2. 检查公告
    if (!mounted) return;
    final announcement = await AnnouncementService.fetchLatest();
    if (announcement != null && mounted) {
      final navContext = app.navKey.currentState?.overlay?.context ?? context;
      if (!navContext.mounted) return;
      await showAnnouncementDialog(navContext, announcement);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _LoginPromptOverlay extends StatefulWidget {
  const _LoginPromptOverlay();
  @override
  State<_LoginPromptOverlay> createState() => _LoginPromptOverlayState();
}

class _LoginPromptOverlayState extends State<_LoginPromptOverlay> {
  bool _shown = false;
  Timer? _promptTimer;

  @override
  void dispose() {
    _promptTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _promptTimer = Timer(const Duration(seconds: 3), () {
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
