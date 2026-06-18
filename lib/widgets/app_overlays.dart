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
import '../widgets/support_me_dialog.dart';
import '../widgets/update_dialog.dart';

// ═══════════════════════════════════════════════
//  跨设备继续播放检测
// ═══════════════════════════════════════════════

class ContinuePlayOverlay extends StatefulWidget {
  const ContinuePlayOverlay();
  @override
  State<ContinuePlayOverlay> createState() => _ContinuePlayOverlayState();
}

class _ContinuePlayOverlayState extends State<ContinuePlayOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), _check);
    });
  }

  Future<void> _check() async {
    final authCtx = app.navKey.currentContext;
    if (authCtx == null) return;
    final auth = authCtx.read<AuthProvider>();
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
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: const Text('继续播放'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('检测到在 '),
                      const SizedBox(height: 8),
                      Text(songName,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (singer != null) Text(singer, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消')),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
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

// ═══════════════════════════════════════════════
//  支持作者弹窗
// ═══════════════════════════════════════════════

class SupportPopupHandler extends StatefulWidget {
  const SupportPopupHandler();
  @override
  State<SupportPopupHandler> createState() => _SupportPopupHandlerState();
}

class _SupportPopupHandlerState extends State<SupportPopupHandler> {
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

// ═══════════════════════════════════════════════
//  启动时检查 GitHub Release 更新
// ═══════════════════════════════════════════════

class UpdateCheckHandler extends StatefulWidget {
  const UpdateCheckHandler();
  @override
  State<UpdateCheckHandler> createState() => _UpdateCheckHandlerState();
}

class _UpdateCheckHandlerState extends State<UpdateCheckHandler> {
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

/// 启动时未登录 → 风控提示弹窗（延迟显示，等其他弹窗先弹出）
class LoginPromptOverlay extends StatefulWidget {
  const LoginPromptOverlay();
  @override
  State<LoginPromptOverlay> createState() => _LoginPromptOverlayState();
}

class _LoginPromptOverlayState extends State<LoginPromptOverlay> {
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
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) return;
    if (!mounted) return;

    showDialog(
      context: context,
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
