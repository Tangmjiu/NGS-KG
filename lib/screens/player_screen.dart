import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/lyric_line.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../widgets/player_background.dart';
import '../widgets/player_cover_art.dart';
import '../widgets/am_lyrics_view.dart';
import '../widgets/player_controls_bar.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/playback_controls.dart' as legacy;
import 'audio_effects_screen.dart';

/// Apple Music-style full player screen with dynamic background,
/// cover-art / lyrics PageView, and smooth transitions.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
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

    // Lyric progress
    player.updateLyricProgress(player.position);

    // Load lyrics when song changes or lyrics were cleared (e.g. quality switch)
    final songChanged = (song.hash != null && song.hash != _lastLoadedHash) ||
        (song.hash == null && song.id != _lastLoadedSongId);
    final lyricsCleared = player.lyrics.isEmpty &&
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
      final parsed = parseLyrics(song.lyrics!);
      if (mounted) {
        context.read<PlayerProvider>().setLyrics(parsed);
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
            final lyrics = parseLyrics(decoded);
            if (mounted) {
              if (hash != _lastLoadedHash) return;
              context.read<PlayerProvider>().setLyrics(lyrics);
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
                          AMLyricsView(
                            lyrics: player.lyrics,
                            currentLineIndex: player.currentLyricLine,
                            currentLineProgress: player.lyricLineProgress,
                            isLoading: _lyricLoading,
                            onSeek: (duration) => player.seek(duration),
                          ),
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
                      onDragStart: () =>
                          setState(() => _isDraggingProgress = true),
                      onDragEnd: () {
                        setState(() => _isDraggingProgress = false);
                        player.seek(Duration(
                          milliseconds: (_dragProgressValue *
                                  player.duration.inMilliseconds)
                              .round(),
                        ));
                      },
                      onSeek: (v) {
                        _dragProgressValue = v;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
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

  static const _qualityLabels = {
    '128': '标准',
    '320': 'HQ',
    'high': 'Hi-Res',
    'viper_clear': '蝰蛇超清',
    'super': 'DSD',
    'flac': 'FLAC 无损',
  };

  Widget _buildBottomActions() {
    final player = context.watch<PlayerProvider>();
    final currentKey = Song.qualityKeys[player.qualityLevel % Song.qualityKeys.length];
    final qualityLabel = _qualityLabels[currentKey] ?? currentKey;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
            final available = player.getAvailableQualities();
            return available.map((key) {
              final label = Song.qualityLabelMap[key] ?? key;
              return PopupMenuItem<String>(
                value: key,
                child: Row(
                  children: [
                    if (key == currentKey)
                      Icon(Icons.check, size: 18, color: Theme.of(ctx).colorScheme.primary),
                    SizedBox(width: key == currentKey ? 8 : 26),
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

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
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
            Icon(icon, size: 20, color: Colors.white60),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}
