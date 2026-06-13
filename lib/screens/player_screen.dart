import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:provider/provider.dart';
import 'package:ym_lyric/model/krc_language_model.dart';
import 'package:ym_lyric/utils/krc_lyric_util.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/auth_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../constants/quality.dart';
import '../widgets/player_background.dart';
import '../widgets/player_cover_art.dart';
import '../widgets/player_controls_bar.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/playback_controls.dart' as legacy;
import '../widgets/login_required_dialog.dart';
import 'audio_effects_screen.dart';

/// Apple Music-style full player screen with dynamic background,
/// cover-art / lyrics PageView, and smooth transitions.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // ─── LyricView 样式（Apple Music 风格） ───
  static final _lyricStyle = LyricStyle(
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: Colors.white54,
    ),
    activeStyle: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: Colors.white,
    ),
    translationStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w300,
      height: 1.2,
      color: Colors.white38,
    ),
    translationActiveColor: Colors.white60,
    lineGap: 8,
    translationLineGap: 2,
    lineTextAlign: TextAlign.center,
    contentAlignment: CrossAxisAlignment.center,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    selectionAnchorPosition: 0.5,
    selectionAlignment: MainAxisAlignment.center,
    activeAnchorPosition: 0.5,
    activeAlignment: MainAxisAlignment.center,
    activeHighlightColor: Colors.white,
    activeHighlightExtraFadeWidth: 14,
    selectedColor: Colors.white38,
    selectedTranslationColor: Colors.white38,
    scrollDuration: const Duration(milliseconds: 400),
    scrollCurve: Curves.easeInOutCubic,
    scrollDurations: {},
    enableSwitchAnimation: true,
    switchEnterDuration: const Duration(milliseconds: 200),
    switchExitDuration: const Duration(milliseconds: 200),
    switchEnterCurve: Curves.easeIn,
    switchExitCurve: Curves.easeOut,
    selectionAutoResumeMode: SelectionAutoResumeMode.selecting,
    selectionAutoResumeDuration: const Duration(milliseconds: 500),
    activeAutoResumeDuration: const Duration(milliseconds: 3000),
  );

  // ─── PageView ───
  final PageController _pageController = PageController();
  double _pageOffset = 0.0; // 0 = cover, 1 = lyrics

  // ─── Lyrics ───
  final MusicService _musicService = MusicService();
  String? _lastLoadedHash;
  int? _lastLoadedSongId; // for local songs without hash
  bool _lyricLoading = false;

  // ─── Drag state (progress bar) ───
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScroll);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _attachPlayerListener());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final player = context.read<PlayerProvider>();
        player.lyricController.setOnTapLineCallback((duration) {
          player.seek(duration);
        });
      }
    });
  }

  void _attachPlayerListener() {
    if (!mounted) return;
    context.read<PlayerProvider>().addListener(_onPlayerTick);
  }

  void _onPlayerTick() {
    if (!mounted) return;
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return;

    // 拖拽中时同步歌词滚动
    if (_isDraggingProgress) {
      final dragPos = Duration(
        milliseconds: (_dragProgressValue * player.duration.inMilliseconds)
            .round(),
      );
      player.lyricController.setProgress(dragPos);
    }

    // Load lyrics when song changes or lyrics were cleared (e.g. quality switch)
    final songChanged = (song.hash != null && song.hash != _lastLoadedHash) ||
        (song.hash == null && song.id != _lastLoadedSongId);
    final currentLines = player.lyricController.lyricNotifier.value?.lines ?? [];
    final lyricsCleared = currentLines.isEmpty &&
        _lastLoadedHash != null &&
        song.hash == _lastLoadedHash;
    if (songChanged || lyricsCleared) {
      if (song.hash != null) {
        _lastLoadedHash = song.hash;
      }
      _lastLoadedSongId = song.id;
      _loadLyricsForSong(song);
    }
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    setState(() {
      _pageOffset = _pageController.page?.clamp(0.0, 1.0) ?? 0.0;
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    try {
      context.read<PlayerProvider>().removeListener(_onPlayerTick);
    } catch (_) {}
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  //  Lyric loading (same API as original)
  // ────────────────────────────────────────────────────────────

  void _loadLyricsForSong(Song song) {
    _dragProgressValue = 0.0;

    // Embedded lyrics from local files (companion .lrc or metadata)
    if (song.lyrics != null && song.lyrics!.isNotEmpty) {
      setState(() => _lyricLoading = false);
      if (mounted) {
        context.read<PlayerProvider>().lyricController.loadLyric(song.lyrics!);
      }
      return;
    }

    // Online lyrics via API (hash-based)
    if (song.hash != null) {
      setState(() => _lyricLoading = true);
      _loadLyrics(song.hash!, songName: song.name);
    } else {
      if (mounted) {
        context.read<PlayerProvider>().clearLyrics();
      }
    }
  }

  Future<void> _loadLyrics(String hash, {String? songName}) async {
    try {
      final searchRes =
          await _musicService.searchLyricByHash(hash, keywords: songName);
      final data = searchRes['data'] as Map<String, dynamic>? ?? searchRes;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = int.parse(c['id'].toString());
        final key = c['accesskey'] as String? ?? '';

        // ── Try KRC first (with translations) ──
        final krcBytes = await _musicService.fetchKrcContent(id, key);
        if (krcBytes.isNotEmpty) {
          try {
            final krcModel = KrcLyricUtil.parseLyrics(krcBytes);
            if (krcModel.krcLyricList.isEmpty) throw 'empty krc';

            // Parse translations from lyricTag.language (base64 JSON)
            List<String>? translations;
            if (krcModel.lyricTag.language != null &&
                krcModel.lyricTag.language!.isNotEmpty) {
              try {
                final langJson = jsonDecode(
                  utf8.decode(base64Decode(krcModel.lyricTag.language!)),
                );
                final krcLang = KrcLanguage.fromJson(langJson);
                if (krcLang.content.isNotEmpty) {
                  // language: 0 = translation (意译), 1 = transliteration (音译)
                  final langContent = krcLang.content.first.lyricContent;
                  translations = langContent
                      .map((words) => words.join())
                      .toList();
                }
              } catch (_) {}
            }

            // 构建翻译时间戳映射 (ms → translation text)
            final transMap = <int, String>{};
            if (translations != null) {
              for (int i = 0; i < krcModel.krcLyricList.length && i < translations.length; i++) {
                transMap[krcModel.krcLyricList[i].startTime] = translations[i];
              }
            }

            // 直接构造 flutter_lyric 的 LyricWord / LyricLine / LyricModel
            final lines = <LyricLine>[];
            for (int i = 0; i < krcModel.krcLyricList.length; i++) {
              final line = krcModel.krcLyricList[i];
              String text;
              try {
                text = line.getWordLine();
              } catch (_) {
                continue; // 跳过解析失败的行（ym_lyric 空值问题）
              }
              if (text.trim().isEmpty) continue;

              // 构造逐字时间信息 LyricWord
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

              lines.add(LyricLine(
                start: Duration(milliseconds: line.startTime),
                end: Duration(milliseconds: line.startTime + line.duration),
                text: text,
                words: words.isNotEmpty ? words : null,
                translation: transMap[line.startTime],
              ));
            }

            if (mounted) {
              if (hash != _lastLoadedHash) return;
              context.read<PlayerProvider>().loadLyricModel(
                LyricModel(lines: lines),
              );
            }
            if (mounted) setState(() => _lyricLoading = false);
            return;
          } catch (e, s) {
            Log.e('player_screen', 'krc parse error', e, s);
          }
        }

        // ── Fallback to LRC ──
        final rawContent = await _musicService.fetchLyricContent(id, key);
        if (rawContent.isNotEmpty) {
          try {
            String decoded;
            try {
              decoded = utf8.decode(base64Decode(rawContent));
            } catch (e, s) {
              Log.e('player_screen', 'base64 error', e, s);
              decoded = rawContent;
            }
            if (mounted) {
              if (hash != _lastLoadedHash) return;
              context.read<PlayerProvider>().lyricController.loadLyric(decoded);
            }
          } catch (e, s) {
            Log.e('player_screen', 'parse error', e, s);
          }
        }
      } else if (mounted) {
        context.read<PlayerProvider>().clearLyrics();
      }
    } catch (e, s) {
      Log.e('player_screen', 'lyric load error', e, s);
    }
    if (mounted) setState(() => _lyricLoading = false);
  }

  Widget _buildLyricsPage(PlayerProvider player) {
    if (_lyricLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    final model = player.lyricController.lyricNotifier.value;
    final hasLyrics = model != null && model.lines.isNotEmpty;

    if (!hasLyrics) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lyrics_outlined, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            const Text('暂无歌词',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return LyricView(
      controller: player.lyricController,
      style: _lyricStyle,
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (ctx, player, _) {
        final song = player.currentSong;
        if (song == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text('暂无播放', style: TextStyle(color: Colors.white70)),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // ── Dynamic background ──
              PlayerBackground(
                albumCoverUrl: song.albumCoverUrl,
                paletteColor: player.backgroundColor,
                scrollOffset: _pageOffset,
              ),

              // ── Content ──
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        children: [
                          // Page 0: Cover art
                          PlayerCoverArt(
                            song: song,
                            scrollOffset: _pageOffset,
                          ),
                          // Page 1: Lyrics
                          _buildLyricsPage(player),
                        ],
                      ),
                    ),

                    // ── Song info ──
                    _buildSongInfo(song),

                    // ── Progress bar ──
                    PlayerProgressBar(
                      position: player.position,
                      duration: player.duration,
                      progress: _isDraggingProgress
                          ? _dragProgressValue
                          : (player.progress.isFinite ? player.progress : 0.0),
                      climaxPosition: player.climaxMs,
                      onDragStart: () {
                        setState(() => _isDraggingProgress = true);
                        // 拖拽开始时同步歌词进度
                        final pos = Duration(
                          milliseconds:
                              (_dragProgressValue * player.duration.inMilliseconds)
                                  .round(),
                        );
                        player.lyricController.setProgress(pos);
                      },
                      onDragEnd: () async {
                        await player.seek(Duration(
                          milliseconds: (_dragProgressValue *
                                  player.duration.inMilliseconds)
                              .round(),
                        ));
                        if (mounted) {
                          setState(() => _isDraggingProgress = false);
                        }
                      },
                      onSeek: (v) {
                        _dragProgressValue = v;
                        if (_isDraggingProgress) {
                          final pos = Duration(
                            milliseconds:
                                (v * player.duration.inMilliseconds).round(),
                          );
                          player.lyricController.setProgress(pos);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── Playback controls ──
                    PlayerControlsBar(
                      isPlaying: player.isPlaying,
                      isLoading: player.isLoading,
                      onPlayPause: player.togglePlayPause,
                      onPrevious: player.playPrevious,
                      onNext: player.playNext,
                      playMode: player.playMode,
                      onModeToggle: () {
                        const modes = [
                          PlayMode.sequential,
                          PlayMode.shuffle,
                          PlayMode.repeatOne,
                        ];
                        final next = modes[
                            (modes.indexOf(player.playMode) + 1) %
                                modes.length];
                        player.setPlayMode(next);
                      },
                      onShowPlaylist: () =>
                          legacy.PlaybackControls.showPlaylistStatic(
                              context, player),
                    ),
                    const SizedBox(height: 8),

                    // ── Bottom actions ──
                    _buildBottomActions(),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Top bar ──

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            tooltip: '收起',
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          // Page indicator dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PageDot(active: _pageOffset < 0.5),
              const SizedBox(width: 6),
              _PageDot(active: _pageOffset >= 0.5),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  // ── Song info ──

  Widget _buildSongInfo(Song song) {
    final player = context.watch<PlayerProvider>();
    final resolved = player.resolvedQuality;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 歌名行 + 解析音质徽章（MoeKoeMusic 风格）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (resolved != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    Quality.label(resolved),
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            song.artistDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom actions ──

  Widget _buildBottomActions() {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    final selectedKey =
        Quality.levels[player.qualityLevel % Quality.levels.length];
    final showLabel = player.resolvedQuality ?? selectedKey;
    final qualityLabel = Quality.label(showLabel);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 收藏按钮
        if (song != null)
          Consumer<LikedSongsProvider>(
            builder: (_, lp, __) {
              final liked = lp.likedIds.contains(song.id);
              return _ActionChip(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                label: liked ? '已收藏' : '收藏',
                iconColor: liked ? Colors.redAccent : null,
                onTap: () async {
                  final auth = context.read<AuthProvider>();
                  if (!auth.isLoggedIn) {
                    final goLogin = await showLoginRequiredDialog(context);
                    if (goLogin && mounted) {
                      Navigator.pushNamed(context, '/login');
                    }
                    return;
                  }
                  lp.toggle(SongInfo(
                    id: song.id,
                    name: song.name,
                    hash: song.hash ?? '',
                    albumId: song.albumId,
                    audioId: song.id,
                  ));
                },
              );
            },
          ),
        if (song != null) const SizedBox(width: 12),
        _ActionChip(
          icon: Icons.tune_rounded,
          label: '音效',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AudioEffectsScreen()),
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          onSelected: (key) => player.setQuality(key),
          itemBuilder: (ctx) {
            final available = Quality.levels;
            return available.map((key) {
              final label = Quality.label(key);
              return PopupMenuItem<String>(
                value: key,
                child: Row(
                  children: [
                    if (key == selectedKey)
                      Icon(Icons.check, size: 18, color: Theme.of(ctx).colorScheme.primary),
                    SizedBox(width: key == selectedKey ? 8 : 26),
                    Text(label),
                  ],
                ),
              );
            }).toList();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed, size: 20, color: Colors.white60),
                const SizedBox(height: 4),
                Text(qualityLabel,
                    style: const TextStyle(fontSize: 10, color: Colors.white60)),
              ],
            ),
          ),
        ),
      ],
    );
  }


}

/// Small page-indicator dot in the top bar.
class _PageDot extends StatelessWidget {
  final bool active;
  const _PageDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.white : Colors.white38,
      ),
    );
  }
}

/// Small icon+label action button used in the bottom bar.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor ?? Colors.white60),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}
