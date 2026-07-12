import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:provider/provider.dart';
import 'local_cover_art.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/core/lyric_model.dart' show LyricLine, LyricWord, LyricModel;
import 'package:ym_lyric/model/krc_language_model.dart';
import 'package:ym_lyric/model/krc_lyric_line_model.dart';
import 'package:ym_lyric/utils/krc_lyric_util.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../models/song.dart';
import '../constants/quality.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../widgets/player_background.dart';
import '../widgets/hi_res_badge.dart';
import '../widgets/lyric_settings_panel.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/playlist_side_sheet.dart';
import '../screens/album_detail_screen.dart' show AlbumDetailScreen;
import '../screens/artist_detail_screen.dart' show ArtistDetailScreen;
import '../screens/login_screen.dart';
import 'shell_navigation_scope.dart';

/// 桌面全宽沉浸播放器（双栏：左封面 + 右歌词）。
///
/// 全屏覆盖，不嵌入 DesktopShell。
class PlayerDesktopView extends StatefulWidget {
  final VoidCallback? onClose;
  /// 从播放器导航到内嵌页面时触发（由 DesktopShell 提供，往 _detailStack 推页面）。
  final void Function(Widget page)? onNavigate;

  const PlayerDesktopView({super.key, this.onClose, this.onNavigate});

  @override
  State<PlayerDesktopView> createState() => _PlayerDesktopViewState();
}

class _PlayerDesktopViewState extends State<PlayerDesktopView> {
  bool? _prevIsDragging;
  double? _prevDragValue;

  // ── Focus node for mouse wheel capture on desktop ──
  final FocusNode _lyricsFocusNode = FocusNode();

  // ── Lyrics state ──
  final MusicService _musicService = MusicService();
  String? _lastLoadedHash;
  int? _lastLoadedSongId;
  bool _lyricLoading = false;

  // ── KRC multi-language lyrics ──
  Map<int, List<String>> _lyricLangMap = {};
  List<KrcLyricLineModel>? _krcLines;
  int _selectedLyricLang = 0;
  bool _showTranslation = true;
  bool get _hasLangData => _lyricLangMap.isNotEmpty;

  // ── Drag state (progress bar) ──
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _attachPlayerListener();
    });
    // 点击歌词行 → 跳转到对应时间（鼠标适配触摸点击）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlayerProvider>().lyricController.setOnTapLineCallback(
          (duration) {
            context.read<PlayerProvider>().seek(duration);
          },
        );
      }
    });
  }

  void _attachPlayerListener() {
    if (!mounted) return;
    context.read<PlayerProvider>().addListener(_onPlayerTick);
  }

  @override
  void dispose() {
    _lyricsFocusNode.dispose();
    try {
      context.read<PlayerProvider>().removeListener(_onPlayerTick);
    } catch (_) {}
    super.dispose();
  }

  // ── Player tick — load lyrics & sync drag progress ──

  void _onPlayerTick() {
    if (!mounted) return;
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return;

    // 拖拽进度条时同步歌词滚动
    if (_isDraggingProgress) {
      final dragPos = Duration(
        milliseconds: (_dragProgressValue * player.duration.inMilliseconds).round(),
      );
      player.lyricController.setProgress(dragPos);
    }

    final songChanged = (song.hash != null && song.hash != _lastLoadedHash) ||
        (song.hash == null && song.id != _lastLoadedSongId);
    final currentLines = player.lyricController.lyricNotifier.value?.lines ?? [];
    final lyricsCleared = currentLines.isEmpty &&
        _lastLoadedHash != null &&
        song.hash == _lastLoadedHash;
    if (songChanged || lyricsCleared) {
      if (song.hash != null) _lastLoadedHash = song.hash;
      _lastLoadedSongId = song.id;
      _loadLyricsForSong(song);
    }
  }

  // ── Lyric loading (with KRC multi-language) ──

  void _loadLyricsForSong(Song song) {
    _lyricLangMap = {};
    _krcLines = null;
    _selectedLyricLang = 0;
    _dragProgressValue = 0.0;

    if (song.lyrics != null && song.lyrics!.isNotEmpty) {
      return;
    }

    if (song.hash != null) {
      setState(() => _lyricLoading = true);
      _loadLyrics(song.hash!, songName: song.name);
    } else {
      if (mounted) context.read<PlayerProvider>().clearLyrics();
    }
  }

  Future<void> _loadLyrics(String hash, {String? songName}) async {
    try {
      final searchRes = await _musicService.searchLyricByHash(hash, keywords: songName);
      final data = searchRes['data'] as Map<String, dynamic>? ?? searchRes;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = int.parse(c['id'].toString());
        final key = c['accesskey'] as String? ?? '';

        // Try KRC first (with translations & transliterations)
        final krcBytes = await _musicService.fetchKrcContent(id, key);
        if (krcBytes.isNotEmpty) {
          try {
            final krcModel = KrcLyricUtil.parseLyrics(krcBytes);
            if (krcModel.krcLyricList.isEmpty) throw 'empty krc';

            _lyricLangMap = {};
            if (krcModel.lyricTag.language != null && krcModel.lyricTag.language!.isNotEmpty) {
              try {
                final langJson = jsonDecode(
                  utf8.decode(base64Decode(krcModel.lyricTag.language!)),
                );
                final krcLang = KrcLanguage.fromJson(langJson);
                for (final c in krcLang.content) {
                  _lyricLangMap[c.language] = c.lyricContent
                      .map((words) => words.join())
                      .toList();
                }
              } catch (e, s) {
                Log.e('player_desktop', 'krc lang parse error', e, s);
              }
            }

            _krcLines = krcModel.krcLyricList;
            _selectedLyricLang = _lyricLangMap.keys
                .contains(0) ? 0 : (_lyricLangMap.keys.firstOrNull ?? 0);

            final transMap = _buildTransMap(_selectedLyricLang);
            final lines = _buildLyricLines(krcModel.krcLyricList, transMap);

            if (mounted) {
              if (hash != _lastLoadedHash) return;
              context.read<PlayerProvider>().loadLyricModel(LyricModel(lines: lines));
            }
            if (mounted) setState(() => _lyricLoading = false);
            return;
          } catch (e, s) {
            Log.e('player_desktop', 'krc parse error', e, s);
          }
        }

        // Fallback to LRC
        final rawContent = await _musicService.fetchLyricContent(id, key);
        if (rawContent.isNotEmpty) {
          try {
            final decoded = utf8.decode(base64Decode(rawContent));
            if (mounted) {
              if (hash != _lastLoadedHash) return;
              context.read<PlayerProvider>().lyricController.loadLyric(decoded);
            }
          } catch (e, s) {
            Log.e('player_desktop', 'lrc parse error', e, s);
          }
        }
      } else if (mounted) {
        context.read<PlayerProvider>().clearLyrics();
      }
    } catch (e, s) {
      Log.e('player_desktop', 'lyric load error', e, s);
    }
    if (mounted) setState(() => _lyricLoading = false);
  }

  // ─── KRC multi-language helpers ───

  Map<int, String> _buildTransMap(int lang) {
    final map = <int, String>{};
    final lines = _lyricLangMap[lang];
    if (lines == null || _krcLines == null) return map;
    for (int i = 0; i < _krcLines!.length && i < lines.length; i++) {
      if (lines[i].isNotEmpty) {
        map[_krcLines![i].startTime] = lines[i];
      }
    }
    return map;
  }

  List<LyricLine> _buildLyricLines(
    List<KrcLyricLineModel> krcLines,
    Map<int, String> transMap,
  ) {
    final result = <LyricLine>[];
    for (final line in krcLines) {
      String text;
      try { text = line.getWordLine(); } catch (_) { continue; }
      if (text.trim().isEmpty) continue;

      final words = <LyricWord>[];
      if (line.line != null) {
        final lineStart = line.startTime;
        for (final w in line.line!) {
          if (w.word == null || w.word!.isEmpty) continue;
          final ws = (w.startTime ?? 0) + lineStart;
          final we = ws + (w.duration ?? 0);
          words.add(LyricWord(
            text: w.word!,
            start: Duration(milliseconds: ws),
            end: Duration(milliseconds: we),
          ));
        }
      }

      result.add(LyricLine(
        start: Duration(milliseconds: line.startTime),
        end: Duration(milliseconds: line.startTime + line.duration),
        text: text,
        words: words.isNotEmpty ? words : null,
        translation: _showTranslation ? transMap[line.startTime] : null,
      ));
    }
    return result;
  }

  void _applyLyricLang(int lang) {
    if (_krcLines == null || !_lyricLangMap.containsKey(lang)) return;
    _selectedLyricLang = lang;
    _showTranslation = true;
    final transMap = _buildTransMap(lang);
    final lines = _buildLyricLines(_krcLines!, transMap);
    if (mounted) {
      context.read<PlayerProvider>().loadLyricModel(LyricModel(lines: lines));
    }
  }

  // ─── Dynamic lyric style from ThemeProvider settings ───

  LyricStyle _buildLyricStyle() {
    final ls = context.read<ThemeProvider>().lyricSettings;
    final int activeWeightIdx = ((ls.fontWeight / 100).round() + 2).clamp(3, 8);
    final activeWeight = FontWeight.values[activeWeightIdx];
    return LyricStyle(
      textStyle: TextStyle(
        fontSize: ls.fontSize,
        fontWeight: ls.resolvedWeight,
        height: 1.8,
        color: const Color(0xFFCDCDCD),
      ),
      activeStyle: TextStyle(
        fontSize: ls.fontSize + 6,
        fontWeight: activeWeight,
        height: 1.8,
        color: Colors.white,
        shadows: const [
          Shadow(color: Colors.white24, blurRadius: 8, offset: Offset(0, 0)),
        ],
      ),
      translationStyle: TextStyle(
        fontSize: ls.translationFontSize,
        fontWeight: ls.resolvedWeight,
        height: 1.8,
        color: const Color(0xFF999999),
      ),
      translationActiveColor: Colors.white70,
      lineGap: 16,
      translationLineGap: 8,
      lineTextAlign: ls.centerAlign ? TextAlign.center : TextAlign.left,
      contentAlignment: ls.centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      selectionAnchorPosition: 0.5,
      selectionAlignment: MainAxisAlignment.center,
      activeAnchorPosition: 0.5,
      activeAlignment: MainAxisAlignment.center,
      activeHighlightColor: Colors.white,
      activeHighlightExtraFadeWidth: 24,
      selectedColor: const Color(0xFFCDCDCD),
      selectedTranslationColor: const Color(0xFF999999),
      scrollDuration: const Duration(milliseconds: 400),
      scrollCurve: Curves.easeInOutCubic,
      scrollDurations: {
        50.0: const Duration(milliseconds: 150),
        200.0: const Duration(milliseconds: 300),
      },
      enableSwitchAnimation: true,
      switchEnterDuration: const Duration(milliseconds: 200),
      switchExitDuration: const Duration(milliseconds: 200),
      switchEnterCurve: Curves.easeIn,
      switchExitCurve: Curves.easeOut,
      selectionAutoResumeMode: SelectionAutoResumeMode.selecting,
      selectionAutoResumeDuration: const Duration(milliseconds: 500),
      activeAutoResumeDuration: const Duration(seconds: 8),
      fadeRange: ls.blurEffect
          ? FadeRange(top: 0.12, bottom: 0.12)
          : null,
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<PlayerProvider>(
      builder: (ctx, player, _) {
        final song = player.currentSong;
        if (song == null) {
          return Scaffold(
            backgroundColor: cs.surface,
            body: SafeArea(
              child: Column(
                children: [
                  _buildCloseButton(),
                  const Spacer(),
                  const Text('暂无播放',
                      style: TextStyle(color: Colors.white38, fontSize: 18)),
                  const Spacer(),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: cs.surface,
          body: Stack(
            children: [
              PlayerBackground(
                albumCoverUrl: song.albumCoverUrl,
                paletteColor: player.backgroundColor,
                paletteColors: player.paletteColors,
                scrollOffset: 0,
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(song, player),
                    Expanded(child: _buildDualPane(song, player)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _closePlayer() {
    final scope = ShellNavigationScope.of(context);
    if (scope != null && scope.canPop) {
      scope.pop();
    } else if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  /// 关闭全屏播放器 → 回到 DesktopShell → 将目标页嵌入 shell 内容区
  void _closePlayerAndNavigate({
    required String routeName,
    Object? arguments,
    required Widget Function() shellPageBuilder,
  }) {
    _closePlayer();
    if (widget.onNavigate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onNavigate!(shellPageBuilder());
      });
    }
  }

  Widget _buildCloseButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.white),
            tooltip: '收起',
            onPressed: _closePlayer,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Top bar: close only ──

  Widget _buildTopBar(Song song, PlayerProvider player) {
    return _buildCloseButton();
  }

  // ── Dual pane: left controls + right lyrics ──

  Widget _buildDualPane(Song song, PlayerProvider player) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 700;
        if (narrow) return _buildNarrowLayout(song, player);
        return Row(
          children: [
            Expanded(
              flex: 4,
              child: _buildLeftPane(song, player),
            ),
            Expanded(
              flex: 5,
              child: _buildRightPane(player),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNarrowLayout(Song song, PlayerProvider player) {
    final qualityOptions = player.qualityOptions;
    final highestAvailable = qualityOptions.isNotEmpty
        ? qualityOptions.last.value
        : null;
    final showKey = player.resolvedQuality ?? highestAvailable ??
        Quality.levels[player.qualityLevel % Quality.levels.length];
    final qualityLabel = Quality.label(showKey);
    final showHiRes = player.resolvedQuality == 'high';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.bottomLeft,
            children: [
              _buildAlbumArt(song, min(MediaQuery.of(context).size.width * 0.5, 200)),
              if (showHiRes)
                const Padding(
                  padding: EdgeInsets.only(left: 6, bottom: 6),
                  child: HiResBadge(height: 24),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            qualityLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: Colors.white60, letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildSongTitle(song),
          const SizedBox(height: 16),
          _buildSeekSlider(player),
          const SizedBox(height: 12),
          _buildPlayControls(player),
          const SizedBox(height: 24),
          SizedBox(height: 300, child: _buildLyricsView(player)),
        ],
      ),
    );
  }

  Widget _buildLeftPane(Song song, PlayerProvider player) {
    final qualityOptions = player.qualityOptions;
    final highestAvailable = qualityOptions.isNotEmpty
        ? qualityOptions.last.value
        : null;
    final showKey = player.resolvedQuality ?? highestAvailable ??
        Quality.levels[player.qualityLevel % Quality.levels.length];
    final qualityLabel = Quality.label(showKey);
    final showHiRes = player.resolvedQuality == 'high';

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 8, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final coverSize = min(constraints.maxWidth * 0.7, 420.0);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Album art with Hi-Res badge
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        _buildAlbumArt(song, coverSize),
                        if (showHiRes)
                          const Padding(
                            padding: EdgeInsets.only(left: 8, bottom: 8),
                            child: HiResBadge(height: 28),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quality label
                  Text(
                    qualityLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white60,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSongTitle(song),
                  const SizedBox(height: 16),
                  _buildSeekSlider(player),
                  const SizedBox(height: 8),
                  _buildPlayControls(player),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightPane(PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 24, 0),
      child: _buildLyricsView(player),
    );
  }

  Widget _buildAlbumArt(Song song, double size) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LocalCoverArt(
            url: song.albumCoverUrl,
            size: size,
            fit: BoxFit.cover,
            coverData: song.coverData,
          ),
        ),
      ),
    );
  }

  Widget _buildSongTitle(Song song) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          song.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          song.artistDisplay,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  // ── Seek slider ──

  Widget _buildSeekSlider(PlayerProvider player) {
    return Row(
      children: [
        _timeText(player.position),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _isDraggingProgress
                  ? _dragProgressValue
                  : (player.progress.isFinite ? player.progress : 0.0),
              onChangeStart: (_) {
                setState(() => _isDraggingProgress = true);
                final pos = Duration(
                  milliseconds: (_dragProgressValue * player.duration.inMilliseconds).round(),
                );
                player.lyricController.setProgress(pos);
              },
              onChangeEnd: (v) async {
                _dragProgressValue = v;
                await player.seek(Duration(
                  milliseconds: (v * player.duration.inMilliseconds).round(),
                ));
                if (mounted) setState(() => _isDraggingProgress = false);
              },
              onChanged: (v) {
                _dragProgressValue = v;
                if (_isDraggingProgress) {
                  final pos = Duration(
                    milliseconds: (v * player.duration.inMilliseconds).round(),
                  );
                  player.lyricController.setProgress(pos);
                }
              },
            ),
          ),
        ),
        _timeText(player.duration),
      ],
    );
  }

  Widget _timeText(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return SizedBox(
      width: 36,
      child: Text(
        '$m:$s',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontFamily: 'monospace',
            color: Colors.white.withValues(alpha: 0.6)),
      ),
    );
  }

  IconData _playModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle: return Icons.shuffle;
      case PlayMode.repeatOne: return Icons.repeat_one;
      case PlayMode.radio: return Icons.radio;
      default: return Icons.repeat;
    }
  }

  void _cyclePlayMode(PlayerProvider player) {
    const modes = [PlayMode.sequential, PlayMode.shuffle, PlayMode.repeatOne];
    final next = modes[(modes.indexOf(player.playMode) + 1) % modes.length];
    player.setPlayMode(next);
  }

  // ── Play controls ──

  Widget _buildPlayControls(PlayerProvider player) {
    final song = player.currentSong;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Play mode
          IconButton(
            icon: Icon(_playModeIcon(player.playMode), size: 20, color: Colors.white54),
            tooltip: '播放模式',
            onPressed: () => _cyclePlayMode(player),
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
          // Previous
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 30, color: Colors.white),
            tooltip: '上一首',
            onPressed: player.playPrevious,
            splashRadius: 22,
          ),
          const SizedBox(width: 12),
          // Play / Pause
          InkWell(
            onTap: player.togglePlayPause,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: Icon(
                player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 30, color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Next
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 30, color: Colors.white),
            tooltip: '下一首',
            onPressed: player.playNext,
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          // Favorite
          if (song != null)
            Consumer<LikedSongsProvider>(
              builder: (_, lp, __) {
                final liked = lp.likedIds.contains(song.id);
                return IconButton(
                  icon: Icon(Icons.favorite, size: 20,
                      color: liked ? Colors.redAccent : Colors.white54),
                  tooltip: liked ? '取消收藏' : '收藏',
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    if (!auth.isLoggedIn) {
                      final goLogin = await showLoginRequiredDialog(context);
                      if (goLogin && mounted) {
                        _closePlayerAndNavigate(
                          routeName: '/login',
                          shellPageBuilder: () => const LoginScreen(),
                        );
                      }
                      return;
                    }
                    lp.toggle(SongInfo(
                      id: song.id, name: song.name, hash: song.hash ?? '',
                      albumId: song.albumId, audioId: song.id,
                    ));
                  },
                  splashRadius: 20,
                );
              },
            ),
          // More options (MD3 Dialog with chips)
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 20, color: Colors.white54),
            tooltip: '更多',
            onPressed: () => _showDesktopMoreDialog(context, player, song),
            splashRadius: 20,
          ),
          // Playlist
          IconButton(
            icon: const Icon(Icons.playlist_play, size: 20, color: Colors.white54),
            tooltip: '播放列表',
            onPressed: () => showPlaylistSideSheet(context),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  // ── "更多" MD3 Dialog（全屏播放器版）──

  void _showDesktopMoreDialog(BuildContext ctx, PlayerProvider player, Song? song) {
    final cs = Theme.of(ctx).colorScheme;
    final tt = Theme.of(ctx).textTheme;
    final currentQ = Quality.levels[player.qualityLevel % Quality.levels.length];
    final availableQualities = player.getAvailableQualities();

    String qualitySubtitle(String key) {
      switch (key) {
        case '128': return '128kbps';
        case '320': return '320kbps';
        case 'high':
        case 'flac': return 'FLAC';
        default: return '';
      }
    }

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: cs.surfaceContainerHighest,
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 24, 8),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('更多操作', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 16),

                // ── 倍速 ──
                Text('倍速', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _desktopChipRow(cs, player.currentSpeed.toStringAsFixed(1),
                    ['0.5x', '0.75x', '1.0x', '1.25x', '1.5x', '2.0x'],
                    (label) {
                  final speed = double.tryParse(label.replaceAll('x', '')) ?? 1.0;
                  player.setSpeed(speed);
                  Navigator.pop(dialogCtx);
                }, null, null),
                const SizedBox(height: 12),

                // ── 音质 ──
                Text('音质', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _desktopChipRow(
                  cs, Quality.label(currentQ),
                  Quality.levels.map((k) => Quality.label(k)).toList(),
                  (label) {
                    final idx = Quality.labels.values.toList().indexOf(label);
                    if (idx >= 0) player.setQuality(Quality.levels[idx]);
                    Navigator.pop(dialogCtx);
                  },
                  (label) {
                    final idx = Quality.labels.values.toList().indexOf(label);
                    if (idx >= 0) return player.isQualityAvailable(Quality.levels[idx]);
                    return true;
                  },
                  (label) {
                    final idx = Quality.labels.values.toList().indexOf(label);
                    if (idx >= 0) return qualitySubtitle(Quality.levels[idx]);
                    return '';
                  },
                ),
                if (availableQualities.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '当前歌曲最高支持: ${Quality.label(availableQualities.last)}',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    ),
                  ),
                const SizedBox(height: 12),

                // ── 音效 ──
                Text('音效', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _desktopChipRow(cs, Quality.effectLabel(player.effectKey),
                    ['关闭', ...Quality.effects.map((k) => Quality.effectLabel(k))],
                    (label) {
                  if (label == '关闭') {
                    player.setEffect('none');
                  } else {
                    final effectLabels = Quality.effects.map((k) => Quality.effectLabel(k)).toList();
                    final idx = effectLabels.indexOf(label);
                    if (idx >= 0) player.setEffect(Quality.effects[idx]);
                  }
                  Navigator.pop(dialogCtx);
                }, null, null),
                const SizedBox(height: 12),

                Divider(height: 1, color: cs.outlineVariant),
                const SizedBox(height: 4),

                // ── 操作列表 ──
                _desktopActionTile(cs, Icons.timer_outlined, '定时关闭',
                    subtitle: player.sleepTimerRemaining != null
                        ? '剩余 ${player.sleepTimerRemaining!.inMinutes} 分钟'
                        : null,
                    onTap: () {
                  Navigator.pop(dialogCtx);
                  _showSleepTimerDialog(player);
                }),
                _desktopActionTile(cs, Icons.lyrics_outlined, '歌词设置', onTap: () {
                  Navigator.pop(dialogCtx);
                  _showLyricSettingsDialog();
                }),
                if (song != null && song.albumId > 0)
                  _desktopActionTile(cs, Icons.album, '查看专辑', onTap: () {
                    Navigator.pop(dialogCtx);
                    _closePlayerAndNavigate(
                      routeName: '/album/detail',
                      arguments: {'id': song.albumId, 'name': song.albumName},
                      shellPageBuilder: () => AlbumDetailScreen(
                        albumId: song.albumId,
                        albumName: song.albumName,
                      ),
                    );
                  }),
                if (song != null && song.artistId != null && song.artistId! > 0)
                  _desktopActionTile(cs, Icons.person, '查看歌手：${song.artistDisplay}', onTap: () {
                    Navigator.pop(dialogCtx);
                    _closePlayerAndNavigate(
                      routeName: '/artist/detail',
                      arguments: {
                        'id': song.artistId,
                        'name': song.artists.isNotEmpty ? song.artists.first : '',
                      },
                      shellPageBuilder: () => ArtistDetailScreen(
                        artistId: song.artistId!,
                        artistName: song.artists.isNotEmpty ? song.artists.first : '',
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopChipRow(
    ColorScheme cs,
    String currentLabel,
    List<String> labels,
    void Function(String) onTap,
    bool Function(String)? isAvailable,
    String Function(String)? subtitle,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.map((label) {
        final selected = label == currentLabel;
        final available = isAvailable?.call(label) ?? true;
        return Tooltip(
          message: !available ? '当前歌曲不支持' : '',
          child: InkWell(
            onTap: available ? () => onTap(label) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primaryContainer
                    : (available ? Colors.transparent : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant,
                  width: selected ? 0 : 1,
                ),
              ),
              child: Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? cs.onPrimaryContainer
                        : (available ? cs.onSurfaceVariant : cs.onSurfaceVariant.withValues(alpha: 0.35)),
                  )),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _desktopActionTile(ColorScheme cs, IconData icon, String text,
      {String? subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 14, color: cs.onSurface)),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── Lyrics view —— dynamic style + footer ──

  Widget _buildLyricsView(PlayerProvider player) {
    if (_lyricLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    final model = player.lyricController.lyricNotifier.value;
    final hasLyrics = model != null && model.lines.isNotEmpty;

    Widget lyricsContent;
    if (!hasLyrics) {
      lyricsContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lyrics_outlined, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            const Text('暂无歌词', style: TextStyle(color: Colors.white38, fontSize: 16)),
          ],
        ),
      );
    } else {
      lyricsContent = Stack(
        children: [
          Focus(
            focusNode: _lyricsFocusNode,
            child: MouseRegion(
              onEnter: (_) => _lyricsFocusNode.requestFocus(),
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _onLyricsMouseWheel(event, player);
                  }
                },
                child: LyricView(
                  key: ValueKey('desktop_lyrics_${_selectedLyricLang}_${player.currentSong?.hash ?? player.currentSong?.id}'),
                  controller: player.lyricController,
                  style: _buildLyricStyle(),
                ),
              ),
            ),
          ),
          // "回到当前行"按钮
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: player.lyricController.isSelectingNotifier,
              builder: (_, isSelecting, __) {
                if (!isSelecting) return const SizedBox.shrink();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: () => player.lyricController.stopSelection(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.vertical_align_top, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('回到当前行',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: lyricsContent),
        _buildLyricsFooter(),
      ],
    );
  }

  // ── Lyrics footer: source badge + language toggle + settings ──

  Widget _buildLyricsFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Row(
        children: [
          // [词] source badge → open lyric settings
          GestureDetector(
            onTap: _showLyricSettingsDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('词',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.white54, height: 1.2)),
                  SizedBox(width: 4),
                  Text('KUGOU',
                      style: TextStyle(fontSize: 10, color: Colors.white38, height: 1.2)),
                ],
              ),
            ),
          ),
          // Lyric settings gear
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _showLyricSettingsDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.settings, size: 12, color: Colors.white38),
            ),
          ),
          const Spacer(),
          // Language toggle (only when KRC has lang data)
          if (_hasLangData)
            GestureDetector(
              onTap: () {
                setState(() => _showTranslation = !_showTranslation);
                if (_showTranslation) {
                  _applyLyricLang(0);
                } else {
                  final lines = _buildLyricLines(_krcLines!, {});
                  if (mounted) {
                    context.read<PlayerProvider>()
                        .loadLyricModel(LyricModel(lines: lines));
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showTranslation ? '翻译' : '歌词',
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _showTranslation ? Icons.visibility : Icons.visibility_off,
                      size: 10, color: Colors.white38,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLyricSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        contentPadding: EdgeInsets.zero,
        content: const SizedBox(
          width: 360,
          child: LyricSettingsPanel(),
        ),
      ),
    );
  }

  void _showSleepTimerDialog(PlayerProvider player) {
    if (player.sleepTimerRemaining != null) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('定时关闭', style: TextStyle(color: Colors.white)),
          content: Text(
            '剩余 ${player.sleepTimerRemaining!.inMinutes} 分钟',
            style: const TextStyle(color: Colors.white60),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('继续', style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: () { player.cancelSleepTimer(); Navigator.pop(c); },
              child: const Text('关闭定时', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('定时关闭', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('15 分钟'), onTap: () { player.setSleepTimer(const Duration(minutes: 15)); Navigator.pop(c); }),
            ListTile(title: const Text('30 分钟'), onTap: () { player.setSleepTimer(const Duration(minutes: 30)); Navigator.pop(c); }),
            ListTile(title: const Text('45 分钟'), onTap: () { player.setSleepTimer(const Duration(minutes: 45)); Navigator.pop(c); }),
            ListTile(title: const Text('60 分钟'), onTap: () { player.setSleepTimer(const Duration(minutes: 60)); Navigator.pop(c); }),
          ],
        ),
      ),
    );
  }

  /// 鼠标滚轮滚动歌词（每格 ≈ 2 行）
  void _onLyricsMouseWheel(PointerScrollEvent event, PlayerProvider player) {
    const double linesPerNotch = 2.0;
    final dir = event.scrollDelta.dy > 0 ? 1 : -1;
    final lineStep = (event.scrollDelta.dy.abs() / 120 * linesPerNotch).round().clamp(1, 10);
    final model = player.lyricController.lyricNotifier.value;
    if (model == null || model.lines.isEmpty) return;
    final currentIdx = player.lyricController.activeIndexNotifiter.value;
    final targetIdx = (currentIdx + dir * lineStep).clamp(0, model.lines.length - 1);
    if (targetIdx == currentIdx) return;
    final newPos = model.lines[targetIdx].start;
    player.lyricController.setProgress(newPos);
  }
}
