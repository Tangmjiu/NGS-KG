import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../widgets/cover_art.dart';
import '../widgets/lyrics_view.dart' as lv;
import '../widgets/song_info_progress.dart';
import '../widgets/playback_controls.dart';
import '../utils/logger.dart';
import 'audio_effects_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final MusicService _musicService = MusicService();
  final ScrollController _lyricScrollController = ScrollController();
  List<lv.LyricLine> _lyrics = [];
  int _currentLine = 0;
  bool _lyricLoading = false;
  bool _lyricAutoScroll = true;
  String? _lastLoadedHash;
  bool _rotationPlaying = false;

  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachPlayerListener());
  }

  void _attachPlayerListener() {
    if (!mounted) return;
    final player = context.read<PlayerProvider>();
    player.addListener(_onPlayerTick);
  }

  void _onPlayerTick() {
    if (!mounted) return;
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return;

    // 歌词滚动
    if (_lyrics.isNotEmpty) {
      _updateCurrentLine(player.position);
    }
    // 封面旋转
    _syncRotation(player.isPlaying);
  }

  @override
  void dispose() {
    try {
      // ignore: invalid_use_of_protected_member
      context.read<PlayerProvider>().removeListener(_onPlayerTick);
    } catch (_) {}
    _rotationController.dispose();
    _pageController.dispose();
    _lyricScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final song = player.currentSong;
        if (song == null) {
          return const Scaffold(body: Center(child: Text('暂无播放')));
        }

        // 切歌检测（仅触发一次）
        if (song.hash != null && song.hash != _lastLoadedHash) {
          _loadLyricsForSong(song.hash!, songName: song.name);
        }

        return Scaffold(
          body: Stack(
            children: [
              _buildBackground(song),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      flex: 5,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (_) => setState(() {}),
                        children: [
                          CoverArt(
                            song: song,
                            rotationController: _rotationController,
                          ),
                          lv.LyricsView(
                            lyrics: _lyrics,
                            currentLine: _currentLine,
                            isLoading: _lyricLoading,
                            autoScroll: _lyricAutoScroll,
                            scrollController: _lyricScrollController,
                            onTapLine: (d) => player.seek(d),
                            onResumeAutoScroll: _resumeAutoScroll,
                          ),
                        ],
                      ),
                    ),
                    SongInfoProgress(song: song),
                    const SizedBox(height: 4),
                    const PlaybackControls(),
                    const SizedBox(height: 12),
                    _buildBottomActions(),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _loadLyricsForSong(String hash, {String? songName}) {
    _lastLoadedHash = hash;
    _rotationController.reset();
    setState(() {
      _lyrics = [];
      _currentLine = 0;
      _lyricAutoScroll = true;
      _lyricLoading = true;
    });
    _loadLyrics(hash, songName: songName);
  }

  void _resumeAutoScroll() {
    setState(() => _lyricAutoScroll = true);
    _scrollToCurrentLine();
  }

  // ───── 背景 ─────
  Widget _buildBackground(Song song) {
    return ExcludeSemantics(
      child: Stack(
        children: [
          Container(color: Colors.black),
          if (song.albumCoverUrl != null && song.albumCoverUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: song.albumCoverUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 28),
            tooltip: '收起',
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionButton(
            icon: Icons.tune_outlined,
            label: '音效',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioEffectsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // ───── 旋转同步 ─────
  void _syncRotation(bool isPlaying) {
    if (isPlaying == _rotationPlaying) return;
    _rotationPlaying = isPlaying;
    if (isPlaying) {
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      if (_rotationController.isAnimating) _rotationController.stop();
    }
  }

  // ───── 歌词 ─────
  void _updateCurrentLine(Duration pos) {
    final ms = pos.inMilliseconds;
    int found = _currentLine;
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (_lyrics[i].time.inMilliseconds <= ms) {
        found = i;
        break;
      }
    }
    if (found != _currentLine) {
      setState(() => _currentLine = found);
      if (_lyricAutoScroll) _scrollToCurrentLine();
    }
  }

  void _scrollToCurrentLine() {
    if (!_lyricAutoScroll || !_lyricScrollController.hasClients) return;
    const itemHeight = 56.0;
    final offset = _currentLine * itemHeight -
        (_lyricScrollController.position.viewportDimension / 2 - itemHeight);
    _lyricScrollController.animateTo(
      offset.clamp(0, _lyricScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
    );
  }

  Future<void> _loadLyrics(String hash, {String? songName}) async {
    try {
      final searchRes =
          await _musicService.searchLyricByHash(hash, keywords: songName);
      final data = searchRes['data'] as Map<String, dynamic>? ?? searchRes;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = c['id'] as int;
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
            _lyrics = lv.parseLyrics(decoded);
          } catch (e, s) {
            Log.e('player_screen', 'parse error', e, s);
          }
        }
      }
    } catch (e, s) {
      Log.e('player_screen', 'lyric load error', e, s);
    }
    if (mounted) setState(() => _lyricLoading = false);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: cs.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
