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

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showLyrics = false;
  final MusicService _musicService = MusicService();
  List<_LyricLine> _lyrics = [];
  int _currentLine = 0;
  bool _lyricLoading = false;
  String? _lastLoadedHash;
  final ScrollController _lyricScrollController = ScrollController();
  bool _lyricAutoScroll = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        if (player.currentSong == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('暂无播放')),
          );
        }
        final song = player.currentSong!;
        if (song.hash != null && song.hash != _lastLoadedHash) {
          _loadLyrics(song.hash!, songName: song.name);
        }
        if (_lyrics.isNotEmpty && player.position.inMilliseconds > 0) {
          _updateCurrentLine(player.position);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(song.name),
            actions: [
              IconButton(
                icon: Icon(_showLyrics ? Icons.library_music : Icons.lyrics),
                tooltip: _showLyrics ? '显示封面' : '显示歌词',
                onPressed: () => setState(() => _showLyrics = !_showLyrics),
              ),
              IconButton(
                icon: const Icon(Icons.comment, size: 20),
                tooltip: '评论',
                onPressed: () => Navigator.pushNamed(context, '/comments',
                    arguments: {'type': 'music', 'id': song.id}),
              ),
              Consumer<LikedSongsProvider>(
                builder: (_, liked, __) => IconButton(
                  icon: Icon(liked.likedIds.contains(song.id) ? Icons.favorite : Icons.favorite_border, size: 20),
                  tooltip: liked.likedIds.contains(song.id) ? '取消收藏' : '收藏',
                  color: liked.likedIds.contains(song.id) ? Theme.of(context).colorScheme.error : null,
                  onPressed: () => liked.toggle(SongInfo(
                    id: song.id,
                    name: song.name,
                    hash: song.hash ?? '',
                    albumId: 0,
                    audioId: song.id,
                  )),
                ),
              ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) {
              if (MediaQuery.disableAnimationsOf(context)) {
                return child;
              }
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_showLyrics),
              child: _showLyrics ? _buildLyricsView(player, song) : _buildPlayerView(player, song),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerView(PlayerProvider player, Song song) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          Hero(
            tag: 'album_art_${song.hash ?? song.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: song.albumCoverUrl != null
                  ? Semantics(
                    image: true,
                    label: '${song.name} 专辑封面',
                    child: CachedNetworkImage(
                      imageUrl: song.albumCoverUrl!,
                      width: 280, height: 280,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 280, height: 280,
                        color: cs.surfaceContainerHighest,
                        child: const Icon(Icons.music_note, size: 80),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 280, height: 280,
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.music_note, size: 80,
                            semanticLabel: '${song.name} 专辑封面'),
                      ),
                    ),
                  )
                : Semantics(
                    image: true,
                    label: '${song.name} 专辑封面',
                    child: Container(
                      width: 280, height: 280,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.music_note, size: 80),
                    ),
                  ),
          ),
          ),
          const Spacer(flex: 1),
          Text(song.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: tt.headlineSmall),
          const SizedBox(height: 8),
          Text(song.artistDisplay,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          _buildProgress(player),
          const SizedBox(height: 16),
          _buildControls(player),
          const SizedBox(height: 24),
          _buildQualityLabel(player),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildLyricsView(PlayerProvider player, Song song) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lyricWidgets = <Widget>[];
    lyricWidgets.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: song.albumCoverUrl != null
                ? Semantics(
                    image: true,
                    label: '${song.name} 专辑封面',
                    child: CachedNetworkImage(
                      imageUrl: song.albumCoverUrl!, width: 100, height: 100, fit: BoxFit.cover))
                : Semantics(
                    image: true,
                    label: '${song.name} 专辑封面',
                    child: Container(width: 100, height: 100, color: cs.surfaceContainerHighest)),
          ),
          const SizedBox(height: 8),
          Text(song.name, style: tt.titleMedium),
          Text(song.artistDisplay, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    ));
    if (_lyricLoading) {
      lyricWidgets.add(const Expanded(child: Center(child: CircularProgressIndicator())));
    } else if (_lyrics.isEmpty) {
      lyricWidgets.add(Expanded(child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lyrics_outlined, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('暂无歌词', style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('歌曲: ${song.name}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ))));
    } else {
      lyricWidgets.add(Expanded(
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _lyricAutoScroll = false;
                  setState(() {});
                }
                return false;
              },
              child: ListView.builder(
                controller: _lyricScrollController,
                itemCount: _lyrics.length,
                itemBuilder: (_, i) {
                  final line = _lyrics[i];
                  final isCurrent = i == _currentLine;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                    child: Text(
                      line.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isCurrent ? 17 : 14,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (!_lyricAutoScroll)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  heroTag: 'scrollToCurrent',
                  onPressed: () {
                    _lyricAutoScroll = true;
                    _scrollToCurrentLine();
                    setState(() {});
                  },
                  child: const Icon(Icons.skip_next, size: 20),
                ),
              ),
          ],
        ),
      ));
    }
    lyricWidgets.add(Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: _buildProgress(player),
    ));
    lyricWidgets.add(Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: _buildControls(player),
    ));
    return Column(children: lyricWidgets);
  }

  Widget _buildProgress(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(_formatDuration(player.position),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        Expanded(
          child: Slider(
            value: player.progress.isFinite ? player.progress : 0,
            onChanged: (v) => player.seek(
              Duration(milliseconds: (v * player.duration.inMilliseconds).round()),
            ),
          ),
        ),
        Text(_formatDuration(player.duration),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildControls(PlayerProvider player) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(_playModeIcon(player.playMode), size: 24),
          tooltip: '播放模式',
          onPressed: () {
            final modes = [PlayMode.sequential, PlayMode.shuffle, PlayMode.repeatOne];
            final next = modes[(modes.indexOf(player.playMode) + 1) % modes.length];
            player.setPlayMode(next);
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 32),
          tooltip: '上一首',
          onPressed: player.playPrevious,
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                if (MediaQuery.disableAnimationsOf(context)) return child;
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                key: ValueKey(player.isPlaying),
                player.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36, color: Theme.of(context).colorScheme.onPrimary),
            ),
            tooltip: player.isPlaying ? '暂停' : '播放',
            onPressed: player.togglePlayPause,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 32),
          tooltip: '下一首',
          onPressed: player.playNext,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.playlist_play, size: 24),
          tooltip: '播放列表',
          onPressed: () => _showPlaylist(player),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.timer, size: 24),
          tooltip: '睡眠定时',
          onPressed: () => _showSleepTimerDialog(context, player),
        ),
        IconButton(
          icon: Icon(player.isKeepScreenOn ? Icons.directions_run : Icons.directions_run_outlined, size: 24),
          tooltip: player.isKeepScreenOn ? '禁止屏幕常亮' : '保持屏幕常亮',
          onPressed: () => player.setKeepScreenOn(!player.isKeepScreenOn),
        ),
        IconButton(
          icon: const Icon(Icons.equalizer, size: 24),
          tooltip: '音效',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioEffectsScreen())),
        ),
      ],
    );
  }

  void _showSleepTimerDialog(BuildContext ctx, PlayerProvider player) {
    showModalBottomSheet(
      context: ctx,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('睡眠定时', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...[15, 30, 45, 60].map((m) => ListTile(
              title: Text('$m 分钟'),
              onTap: () {
                player.setSleepTimer(Duration(minutes: m));
                Navigator.pop(c);
              },
            )),
            if (player.sleepTimerRemaining != null)
              ListTile(
                title: const Text('取消定时'),
                onTap: () {
                  player.cancelSleepTimer();
                  Navigator.pop(c);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showPlaylist(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('播放列表'),
            trailing: Text('${player.playlist.length} 首'),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          if (player.playlist.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('列表为空'),
            )
          else
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: player.playlist.length,
                itemBuilder: (_, i) {
                  final s = player.playlist[i];
                  return ListTile(
                    leading: Text('${i + 1}',
                        style: TextStyle(
                            color: i == player.currentIndex
                                ? cs.primary
                                : cs.outline)),
                    title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(s.artistDisplay,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    selected: i == player.currentIndex,
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
            leading: const Icon(Icons.delete_sweep),
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
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        player.setPlaylist([]);
                      },
                      child: Text('清空', style: TextStyle(color: cs.error)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylist(PlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer<PlaylistProvider>(
        builder: (_, pp, __) {
          final playlists = pp.userPlaylists;
          if (playlists.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('暂无歌单'),
            );
          }
          return ListView.builder(
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
          );
        },
      ),
    );
  }

  Future<void> _addSongToPlaylist(PlayerProvider player, int playlistId, Song song) async {
    try {
      final data = (song.hash?.isNotEmpty ?? false)
          ? '${song.name}|${song.hash}|0|${song.id}'
          : song.name;
      await MusicService().addTracksToPlaylist(playlistId, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已收藏到歌单')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('收藏失败: $e')));
      }
    }
  }

  Widget _buildQualityLabel(PlayerProvider player) {
    if (player.currentSong?.isLocal == true) return const SizedBox.shrink();
    final q = player.currentSong?.qualities;
    if (q == null || q.isEmpty) return const SizedBox.shrink();
    final label = ['标准', 'HQ', '无损'];
    final keys = ['128', '320', 'high'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < keys.length; i++)
            if (q.containsKey(keys[i]))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(label[i], style: const TextStyle(fontSize: 11)),
                  selected: player.isCurrentQuality(keys[i]),
                  onSelected: (_) {
                    player.setQualityIndex(i);
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ),
        ],
      ),
    );
  }

  void _updateCurrentLine(Duration pos) {
    final ms = pos.inMilliseconds;
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (_lyrics[i].time.inMilliseconds <= ms) {
        if (_currentLine != i) {
          _currentLine = i;
          _scrollToCurrentLine();
          if (mounted) setState(() {});
        }
        return;
      }
    }
  }

  void _scrollToCurrentLine() {
    if (!_lyricAutoScroll) return;
    final offset = _currentLine * 56.0 - 200;
    if (_lyricScrollController.hasClients) {
      _lyricScrollController.animateTo(
        offset.clamp(0, _lyricScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadLyrics(String hash, {String? songName}) async {
    _lyricLoading = true;
    _lastLoadedHash = hash;
    if (mounted) setState(() {});
    try {
      final searchRes = await _musicService.searchLyricByHash(hash, keywords: songName);
      debugPrint('[PlayerScreen] searchLyricByHash response: $searchRes');
      final data = searchRes['data'] as Map<String, dynamic>? ?? searchRes;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      debugPrint('[PlayerScreen] candidates: $candidates');
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = c['id'] as int;
        final key = c['accesskey'] as String? ?? '';
        debugPrint('[PlayerScreen] fetching lyric id=$id key=$key');
        final rawContent = await _musicService.fetchLyricContent(id, key);
        final content = rawContent.isNotEmpty ? rawContent : '';
        debugPrint('[PlayerScreen] lyric content length: ${content.length}');
        if (content.isNotEmpty) {
          try {
            String decoded;
            try {
              decoded = utf8.decode(base64Decode(content));
            } catch (_) {
              decoded = content;
            }
            _lyrics = _parseLyrics(decoded);
            debugPrint('[PlayerScreen] parsed ${_lyrics.length} lyric lines');
          } catch (e) {
            debugPrint('[PlayerScreen] lyrics decode failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[PlayerScreen] _loadLyrics error: $e');
    }
    _lyricLoading = false;
    if (mounted) setState(() {});
  }

  List<_LyricLine> _parseLyrics(String raw) {
    final lines = <_LyricLine>[];
    for (final line in raw.split('\n')) {
      final match = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)').firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final ms = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          lines.add(_LyricLine(
            time: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: text,
          ));
        }
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  IconData _playModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle: return Icons.shuffle;
      case PlayMode.repeatOne: return Icons.repeat_one;
      default: return Icons.repeat;
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _lyricScrollController.dispose();
    super.dispose();
  }
}

class _LyricLine {
  final Duration time;
  final String text;
  const _LyricLine({required this.time, required this.text});
}
