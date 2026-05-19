import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';
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
  List<_LyricLine> _lyrics = [];
  int _currentLine = 0;
  bool _lyricLoading = false;
  bool _lyricAutoScroll = true;
  String? _lastLoadedHash;
  bool _isDragging = false;
  double _dragProgress = 0;

  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pageController.dispose();
    _lyricScrollController.dispose();
    super.dispose();
  }

  // ────────────────────────────── build ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        if (player.currentSong == null) {
          return const Scaffold(
            body: Center(child: Text('暂无播放')),
          );
        }
        final song = player.currentSong!;

        // Trigger lyric load when song changes (once, not on every build)
        if (song.hash != null && song.hash != _lastLoadedHash) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _resetForNewSong(song.hash!, songName: song.name);
          });
        }

        // Compute current lyric line from position (no setState call)
        if (_lyrics.isNotEmpty && player.position.inMilliseconds > 0) {
          _updateCurrentLine(player.position);
        }

        _scheduleRotationSync(player.isPlaying);

        return _phoneLayout(player, song);
      },
    );
  }

  void _resetForNewSong(String hash, {String? songName}) {
    setState(() {
      _lyrics = [];
      _currentLine = 0;
      _lyricAutoScroll = true;
    });
    _loadLyrics(hash, songName: songName);
  }

  // ────────────────────────────── phone layout ──────────────────────────────

  Widget _phoneLayout(PlayerProvider player, Song song) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(song),
          SafeArea(
            child: Column(
              children: [
                // AppBar spacer with back button
                _buildTopBar(),
                // PageView: cover or lyrics
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (_) => setState(() {}),
                    children: [
                      _buildCover(song),
                      _buildLyricsView(player, song),
                    ],
                  ),
                ),
                // Song info + quality badge
                _buildSongInfo(song, player),
                const SizedBox(height: 8),
                // Progress
                _buildProgressSection(player, song),
                const SizedBox(height: 12),
                // Controls
                _buildControls(player),
                const SizedBox(height: 8),
                // Bottom actions
                _buildBottomActions(player),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────── blurred background ──────────────────────────────

  Widget _buildBackground(Song song) {
    return Stack(
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
    );
  }

  // ────────────────────────────── top bar (back only) ──────────────────────────────

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

  // ────────────────────────────── album cover ──────────────────────────────

  Widget _buildCover(Song song) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = (constraints.maxWidth > constraints.maxHeight
                ? constraints.maxHeight
                : constraints.maxWidth) *
            0.7;
        return Center(
          child: Hero(
            tag: 'album_art_${song.hash ?? song.id}',
            child: RotationTransition(
              turns: _rotationController,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Semantics(
                  image: true,
                  label: '${song.name} 专辑封面',
                  child: CachedNetworkImage(
                    imageUrl: song.albumCoverUrl ?? '',
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.music_note, size: size * 0.25),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.music_note, size: size * 0.25),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────── song info + quality badge ──────────────────────────────

  Widget _buildSongInfo(Song song, PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final label = Song.qualityLabels[player.qualityLevel % Song.qualityLabels.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  song.artistDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildQualityBadge(label, () => _showQualitySelector(player)),
        ],
      ),
    );
  }

  Widget _buildQualityBadge(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white38),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── progress ──────────────────────────────

  Widget _buildProgressSection(PlayerProvider player, Song song) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Text(_formatDuration(player.position),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: cs.primary,
                      inactiveTrackColor: cs.surfaceContainerHighest,
                      thumbColor: cs.primary,
                      overlayColor: cs.primary.withValues(alpha: 25/255),
                    ),
                    child: Slider(
                      value: _isDragging
                          ? _dragProgress
                          : (player.progress.isFinite ? player.progress : 0),
                      onChangeStart: (_) {
                        setState(() => _isDragging = true);
                        _rotationController.stop();
                      },
                      onChangeEnd: (v) {
                        _isDragging = false;
                        player.seek(Duration(
                            milliseconds:
                                (v * player.duration.inMilliseconds).round()));
                        _syncRotation(player.isPlaying);
                      },
                      onChanged: (v) {
                        setState(() => _dragProgress = v);
                      },
                    ),
                  ),
                ),
              ),
              Text(_formatDuration(player.duration),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Consumer<LikedSongsProvider>(
              builder: (_, liked, __) => IconButton(
                icon: Icon(
                  liked.likedIds.contains(song.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: 22,
                ),
                tooltip: liked.likedIds.contains(song.id) ? '取消收藏' : '收藏',
                color: liked.likedIds.contains(song.id)
                    ? cs.error
                    : cs.onSurfaceVariant,
                onPressed: () => liked.toggle(SongInfo(
                  id: song.id,
                  name: song.name,
                  hash: song.hash ?? '',
                  albumId: song.albumId,
                  audioId: song.id,
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────── controls ──────────────────────────────

  Widget _buildControls(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (_, constraints) {
        final isWide = constraints.maxWidth > 400;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_playModeIcon(player.playMode), size: 22),
              tooltip: '播放模式',
              color: cs.onSurfaceVariant,
              onPressed: () {
                const modes = [
                  PlayMode.sequential,
                  PlayMode.shuffle,
                  PlayMode.repeatOne,
                ];
                final next =
                    modes[(modes.indexOf(player.playMode) + 1) % modes.length];
                player.setPlayMode(next);
              },
            ),
            SizedBox(width: isWide ? 8 : 4),
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 32),
              tooltip: '上一首',
              onPressed: player.playPrevious,
            ),
            SizedBox(width: isWide ? 16 : 8),
            SizedBox(
              width: 56,
              height: 56,
              child: FloatingActionButton(
                heroTag: 'playPause',
                onPressed: player.togglePlayPause,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    key: ValueKey(player.isPlaying),
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 32,
                  ),
                ),
              ),
            ),
            SizedBox(width: isWide ? 16 : 8),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 32),
              tooltip: '下一首',
              onPressed: player.playNext,
            ),
            SizedBox(width: isWide ? 8 : 4),
            IconButton(
              icon: const Icon(Icons.playlist_play, size: 22),
              tooltip: '播放列表',
              color: cs.onSurfaceVariant,
              onPressed: () => _showPlaylist(player),
            ),
          ],
        );
      },
    );
  }

  // ────────────────────────────── bottom actions ──────────────────────────────

  Widget _buildBottomActions(PlayerProvider player) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 4),
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
          const SizedBox(width: 48),
          _ActionButton(
            icon: Icons.queue_music_outlined,
            label: '队列',
            onTap: () => _showPlaylist(player),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────── full lyrics view ──────────────────────────────

  Widget _buildLyricsView(PlayerProvider player, Song song) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_lyricLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('暂无歌词',
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification && n.dragDetails != null) {
          if (_lyricAutoScroll) setState(() => _lyricAutoScroll = false);
        }
        return false;
      },
      child: Stack(
        children: [
          ListView.builder(
            controller: _lyricScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            itemCount: _lyrics.length,
            itemBuilder: (_, i) {
              final line = _lyrics[i];
              final isCurrent = i == _currentLine;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GestureDetector(
                  onTap: () {
                    player.seek(line.time);
                    setState(() => _lyricAutoScroll = true);
                  },
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isCurrent ? 17 : 14,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
          if (!_lyricAutoScroll)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                heroTag: 'scrollToCurrent',
                onPressed: () {
                  setState(() => _lyricAutoScroll = true);
                  _scrollToCurrentLine();
                },
                child: const Icon(Icons.skip_next, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────── rotation sync ──────────────────────────────

  /// Safe to call from callbacks (not build).
  void _syncRotation(bool isPlaying) {
    if (isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  bool _lastPlayingState = false;

  /// Safe to call from build — defers animation ops to post-frame.
  void _scheduleRotationSync(bool isPlaying) {
    if (isPlaying == _lastPlayingState) return;
    _lastPlayingState = isPlaying;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isPlaying && !_rotationController.isAnimating) {
        _rotationController.repeat();
      } else if (!isPlaying && _rotationController.isAnimating) {
        _rotationController.stop();
      }
    });
  }

  // ────────────────────────────── dialogs & overlays ──────────────────────────────

  void _showPlaylist(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('播放列表',
                  style: Theme.of(context).textTheme.titleSmall),
              trailing: Text('${player.playlist.length} 首',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            if (player.playlist.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(32), child: Text('列表为空'))
            else
              SizedBox(
                height: 320,
                child: ListView.builder(
                  itemCount: player.playlist.length,
                  itemBuilder: (_, i) {
                    final s = player.playlist[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: i == player.currentIndex
                            ? cs.primaryContainer
                            : Colors.transparent,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: i == player.currentIndex
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(s.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        s.artistDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                      selected: i == player.currentIndex,
                      selectedTileColor: cs.primaryContainer.withValues(alpha: 40/255),
                      onTap: () {
                        Navigator.pop(context);
                        player.playIndex(i);
                      },
                    );
                  },
                ),
              ),
            Divider(height: 1, color: cs.outlineVariant),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('收藏到歌单'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(player);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_sweep, color: cs.error),
              title: Text('清空列表', style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认清空'),
                    content: const Text('确定要清空播放列表吗？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消')),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          player.setPlaylist([]);
                        },
                        child: Text('清空',
                            style: TextStyle(color: cs.onError)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylist(PlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Consumer<PlaylistProvider>(
          builder: (_, pp, __) {
            final playlists = pp.userPlaylists;
            if (playlists.isEmpty) {
              return const Padding(
                  padding: EdgeInsets.all(24), child: Text('暂无歌单'));
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('收藏到歌单',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (_, i) {
                      final pl = playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(pl.name),
                        onTap: () async {
                          Navigator.pop(context);
                          await _addSongToPlaylist(player, pl.id, song);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addSongToPlaylist(
      PlayerProvider player, int playlistId, Song song) async {
    try {
      final data = (song.hash?.isNotEmpty ?? false)
          ? '${song.name}|${song.hash}|0|${song.id}'
          : song.name;
      await MusicService().addTracksToPlaylist(playlistId, data);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已收藏到歌单')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('收藏失败: $e')));
      }
    }
  }

  void _showQualitySelector(PlayerProvider player) {
    final q = player.currentSong?.qualities;
    if (q == null || q.isEmpty) return;
    const labels = ['标准 (128k)', 'HQ (320k)', '无损 (FLAC)'];
    const keys = ['128', '320', 'high'];
    final available = <int>[];
    for (int i = 0; i < keys.length; i++) {
      if (q.containsKey(keys[i])) available.add(i);
    }
    if (available.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('音质选择',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ...available.map((i) => ListTile(
                  leading: Icon(
                    i == 0
                        ? Icons.sd
                        : i == 1
                            ? Icons.hd
                            : Icons.album,
                    color: player.isCurrentQuality(keys[i])
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(labels[i]),
                  trailing: player.isCurrentQuality(keys[i])
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    player.setQualityIndex(i);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────── lyrics logic ──────────────────────────────

  void _updateCurrentLine(Duration pos) {
    final ms = pos.inMilliseconds;
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (_lyrics[i].time.inMilliseconds <= ms) {
        if (_currentLine != i) {
          _currentLine = i;
          if (_lyricAutoScroll) _scrollToCurrentLine();
        }
        return;
      }
    }
  }

  void _scrollToCurrentLine() {
    if (!_lyricAutoScroll || !_lyricScrollController.hasClients) return;
    // Estimate item height at 56px (8 padding top + 8 padding bottom + ~40 line)
    const itemHeight = 56.0;
    final offset = _currentLine * itemHeight -
        (_lyricScrollController.position.viewportDimension / 2 - itemHeight);
    _lyricScrollController.animateTo(
      offset.clamp(0, _lyricScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadLyrics(String hash, {String? songName}) async {
    _lyricLoading = true;
    _lastLoadedHash = hash;
    if (mounted) setState(() {});
    try {
      final searchRes =
          await _musicService.searchLyricByHash(hash, keywords: songName);
      final data =
          searchRes['data'] as Map<String, dynamic>? ?? searchRes;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = c['id'] as int;
        final key = c['accesskey'] as String? ?? '';
        final rawContent = await _musicService.fetchLyricContent(id, key);
        final content = rawContent.isNotEmpty ? rawContent : '';
        if (content.isNotEmpty) {
          try {
            String decoded;
            try {
              decoded = utf8.decode(base64Decode(content));
            } catch (_) {
              decoded = content;
            }
            _lyrics = _parseLyrics(decoded);
          } catch (_) {}
        }
      }
    } catch (_) {}
    _lyricLoading = false;
    if (mounted) setState(() {});
  }

  List<_LyricLine> _parseLyrics(String raw) {
    final lines = <_LyricLine>[];
    for (final line in raw.split('\n')) {
      final match =
          RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)').firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final ms = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          lines.add(_LyricLine(
            time: Duration(milliseconds: min * 60000 + sec * 1000 + ms),
            text: text,
          ));
        }
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  // ────────────────────────────── helpers ──────────────────────────────

  IconData _playModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.repeatOne:
        return Icons.repeat_one;
      default:
        return Icons.repeat;
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00';
    final totalSec = d.inSeconds.clamp(0, 359999); // max 99:59:59
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ────────────────────────────── helper widgets ──────────────────────────────

class _LyricLine {
  final Duration time;
  final String text;
  const _LyricLine({required this.time, required this.text});
}

/// Bottom action bar button with icon and label.
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
