import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'local_cover_art.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/core/lyric_model.dart' show LyricLine, LyricWord, LyricModel;
import 'package:ym_lyric/model/krc_language_model.dart';
import 'package:ym_lyric/utils/krc_lyric_util.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../models/song.dart';
import '../constants/quality.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../widgets/player_background.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/player_controls_bar.dart';
import '../screens/audio_effects_screen.dart';
import '../widgets/playlist_side_sheet.dart';
import 'shell_navigation_scope.dart';

/// LyricView 样式——左对齐，宽松行高，焦点行居中+发光。
final _desktopLyricStyle = LyricStyle(
  textStyle: const TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w400,
    height: 1.8,
    color: Color(0xFFCDCDCD),
  ),
  activeStyle: const TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.8,
    color: Colors.white,
    shadows: [
      Shadow(
        color: Colors.white24,
        blurRadius: 8,
        offset: Offset(0, 0),
      ),
    ],
  ),
  translationStyle: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w300,
    height: 1.8,
    color: Color(0xFF999999),
  ),
  translationActiveColor: Colors.white70,
  lineGap: 16,
  translationLineGap: 8,
  lineTextAlign: TextAlign.left,
  contentAlignment: CrossAxisAlignment.start,
  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
  selectionAnchorPosition: 0.5,
  selectionAlignment: MainAxisAlignment.center,
  activeAnchorPosition: 0.5,
  activeAlignment: MainAxisAlignment.center,
  activeHighlightColor: Colors.white,
  activeHighlightExtraFadeWidth: 24,
  selectedColor: Color(0xFFCDCDCD),
  selectedTranslationColor: Color(0xFF999999),
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

/// 桌面全宽沉浸播放器（双栏：左封面 + 右歌词）。
///
/// 全屏覆盖，不嵌入 DesktopShell。
class PlayerDesktopView extends StatefulWidget {
  final VoidCallback? onClose;

  const PlayerDesktopView({super.key, this.onClose});

  @override
  State<PlayerDesktopView> createState() => _PlayerDesktopViewState();
}

class _PlayerDesktopViewState extends State<PlayerDesktopView> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _showLyrics = true;

  // ── Lyrics state ──
  final MusicService _musicService = MusicService();
  String? _lastLoadedHash;
  int? _lastLoadedSongId;
  bool _lyricLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _attachPlayerListener();
    });
  }

  void _attachPlayerListener() {
    if (!mounted) return;
    context.read<PlayerProvider>().addListener(_onPlayerTick);
  }

  @override
  void dispose() {
    try {
      context.read<PlayerProvider>().removeListener(_onPlayerTick);
    } catch (_) {}
    super.dispose();
  }

  // ── Player tick — load lyrics on song change ──

  void _onPlayerTick() {
    if (!mounted) return;
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return;

    final songChanged = (song.hash != null && song.hash != _lastLoadedHash) ||
        (song.hash == null && song.id != _lastLoadedSongId);
    if (songChanged) {
      if (song.hash != null) _lastLoadedHash = song.hash;
      _lastLoadedSongId = song.id;
      _loadLyricsForSong(song);
    }
  }

  // ── Lyric loading (same logic as PlayerScreen) ──

  void _loadLyricsForSong(Song song) {
    // 嵌入歌词已在 playIndex 中加载，此处仅处理网络歌词
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

        // Try KRC first (with translations)
        final krcBytes = await _musicService.fetchKrcContent(id, key);
        if (krcBytes.isNotEmpty) {
          try {
            final krcModel = KrcLyricUtil.parseLyrics(krcBytes);
            if (krcModel.krcLyricList.isEmpty) throw 'empty krc';

            List<String>? translations;
            if (krcModel.lyricTag.language != null && krcModel.lyricTag.language!.isNotEmpty) {
              try {
                final langJson = jsonDecode(
                  utf8.decode(base64Decode(krcModel.lyricTag.language!)),
                );
                final krcLang = KrcLanguage.fromJson(langJson);
                if (krcLang.content.isNotEmpty) {
                  final langContent = krcLang.content.first.lyricContent;
                  translations = langContent.map((words) => words.join()).toList();
                }
              } catch (_) {}
            }

            final transMap = <int, String>{};
            if (translations != null) {
              for (int i = 0; i < krcModel.krcLyricList.length && i < translations.length; i++) {
                transMap[krcModel.krcLyricList[i].startTime] = translations[i];
              }
            }

            final lines = <LyricLine>[];
            for (int i = 0; i < krcModel.krcLyricList.length; i++) {
              final line = krcModel.krcLyricList[i];
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
            // Left: album art + controls
            Expanded(
              flex: 4,
              child: _buildLeftPane(song, player),
            ),
            // Right: lyrics (left-aligned)
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          _buildAlbumArt(song, min(MediaQuery.of(context).size.width * 0.5, 200)),
          const SizedBox(height: 16),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 8, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAlbumArt(song, 240),
          const SizedBox(height: 12),
          _buildSongTitle(song),
          const SizedBox(height: 16),
          _buildSeekSlider(player),
          const SizedBox(height: 8),
          _buildPlayControls(player),
        ],
      ),
    );
  }

  Widget _buildRightPane(PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 40, 24, 40),
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

  Widget _artPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: 64, color: cs.onSurfaceVariant),
    );
  }

  Widget _buildSongTitle(Song song) {
    final cs = Theme.of(context).colorScheme;
    return Column(
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
              value: _isDragging
                  ? _dragValue
                  : (player.progress.isFinite ? player.progress : 0.0),
              onChangeStart: (_) => setState(() => _isDragging = true),
              onChangeEnd: (v) async {
                await player.seek(Duration(
                  milliseconds: (v * player.duration.inMilliseconds).round(),
                ));
                if (mounted) setState(() => _isDragging = false);
              },
              onChanged: (v) {
                setState(() => _dragValue = v);
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
    final cs = Theme.of(context).colorScheme;
    final song = player.currentSong;

    return Row(
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
                onPressed: () => lp.toggle(SongInfo(
                  id: song.id, name: song.name, hash: song.hash ?? '',
                  albumId: song.albumId, audioId: song.id,
                )),
                splashRadius: 20,
              );
            },
          ),
        // Quality
        PopupMenuButton<String>(
          icon: Icon(Icons.speed, size: 20, color: Colors.white54),
          tooltip: '音质',
          onSelected: (key) => player.setQuality(key),
          splashRadius: 20,
          itemBuilder: (ctx) {
            final selectedKey = Quality.levels[player.qualityLevel % Quality.levels.length];
            return Quality.levels.map((key) {
              return PopupMenuItem<String>(
                value: key,
                child: Row(
                  children: [
                    if (key == selectedKey)
                      Icon(Icons.check, size: 18, color: Theme.of(ctx).colorScheme.primary),
                    SizedBox(width: key == selectedKey ? 8 : 26),
                    Text(Quality.label(key)),
                  ],
                ),
              );
            }).toList();
          },
        ),
        // Playlist
        IconButton(
          icon: const Icon(Icons.playlist_play, size: 20, color: Colors.white54),
          tooltip: '播放列表',
          onPressed: () => showPlaylistSideSheet(context),
          splashRadius: 20,
        ),
      ],
    );
  }

  // ── Right pane removed — lyrics now in left column above ──

  Widget _buildLyricsView(PlayerProvider player) {
    if (_lyricLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    final model = player.lyricController.lyricNotifier.value;
    final hasLyrics = model != null && model.lines.isNotEmpty;

    if (!hasLyrics) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lyrics_outlined, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            const Text('暂无歌词', style: TextStyle(color: Colors.white38, fontSize: 16)),
          ],
        ),
      );
    }

    return LyricView(
      key: ValueKey('desktop_lyrics_${player.currentSong?.hash ?? player.currentSong?.id}'),
      controller: player.lyricController,
      style: _desktopLyricStyle,
    );
  }
}

// ── Small action button ──

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor ?? cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
