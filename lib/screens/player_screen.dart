import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../services/music_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showLyrics = false;
  int _qualityLevel = 0;
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
          _loadLyrics(song.hash!);
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
                onPressed: () => setState(() => _showLyrics = !_showLyrics),
              ),
              IconButton(
                icon: const Icon(Icons.comment, size: 20),
                onPressed: () => Navigator.pushNamed(context, '/comments',
                    arguments: {'type': 'music', 'id': song.id}),
              ),
              Consumer<LikedSongsProvider>(
                builder: (_, liked, __) => IconButton(
                  icon: Icon(liked.likedIds.contains(song.id) ? Icons.favorite : Icons.favorite_border, size: 20),
                  color: liked.likedIds.contains(song.id) ? Colors.red : null,
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
          body: _showLyrics ? _buildLyricsView(player, song) : _buildPlayerView(player, song),
        );
      },
    );
  }

  Widget _buildPlayerView(PlayerProvider player, Song song) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: song.albumCoverUrl != null
                ? CachedNetworkImage(
                    imageUrl: song.albumCoverUrl!,
                    width: 280, height: 280,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 280, height: 280,
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, size: 80),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 280, height: 280,
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, size: 80),
                    ),
                  )
                : Container(
                    width: 280, height: 280,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.music_note, size: 80),
                  ),
          ),
          const Spacer(flex: 1),
          Text(song.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(song.artistDisplay,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: Colors.grey[400])),
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
    final lyricWidgets = <Widget>[];
    lyricWidgets.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: song.albumCoverUrl != null
                ? CachedNetworkImage(
                    imageUrl: song.albumCoverUrl!, width: 100, height: 100, fit: BoxFit.cover)
                : Container(width: 100, height: 100, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(song.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(song.artistDisplay, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    ));
    if (_lyricLoading) {
      lyricWidgets.add(const Expanded(child: Center(child: CircularProgressIndicator())));
    } else if (_lyrics.isEmpty) {
      lyricWidgets.add(const Expanded(child: Center(child: Text('暂无歌词'))));
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
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[400],
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
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400],
                ),
              ),
            );
          },
        ),
      ));
      if (!_lyricAutoScroll) {
        lyricWidgets.add(Positioned(
          right: 16,
          bottom: 120,
          child: FloatingActionButton.small(
            heroTag: 'scrollToCurrent',
            onPressed: () {
              _lyricAutoScroll = true;
              _scrollToCurrentLine();
              setState(() {});
            },
            child: const Icon(Icons.skip_next, size: 20),
          ),
        ));
      }
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
    return Row(
      children: [
        Text(_formatDuration(player.position),
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        Expanded(
          child: Slider(
            value: player.progress.isFinite ? player.progress : 0,
            onChanged: (v) => player.seek(
              Duration(milliseconds: (v * player.duration.inMilliseconds).round()),
            ),
          ),
        ),
        Text(_formatDuration(player.duration),
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildControls(PlayerProvider player) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(_playModeIcon(player.playMode), size: 24),
          onPressed: () {
            final modes = [PlayMode.sequential, PlayMode.shuffle, PlayMode.repeatOne];
            final next = modes[(modes.indexOf(player.playMode) + 1) % modes.length];
            player.setPlayMode(next);
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 32),
          onPressed: player.playPrevious,
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36, color: Colors.black),
            onPressed: player.togglePlayPause,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 32),
          onPressed: player.playNext,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.playlist_play, size: 24),
          onPressed: () => _showPlaylist(player),
        ),
      ],
    );
  }

  void _showPlaylist(PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('播放列表'),
            trailing: Text('${player.playlist.length} 首'),
          ),
          const Divider(height: 1),
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
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey)),
                    title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(s.artistDisplay,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    selected: i == player.currentIndex,
                    onTap: () {
                      Navigator.pop(context);
                      player.playIndex(i);
                    },
                  );
                },
              ),
            ),
          const Divider(height: 1),
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
            title: const Text('清空列表'),
            onTap: () {
              player.setPlaylist([]);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylist(PlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('收藏到歌单'),
        content: const Text('输入歌单ID:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () {
            Navigator.pop(context);
          }, child: const Text('确定')),
        ],
      ),
    );
  }

  Widget _buildQualityLabel(PlayerProvider player) {
    if (player.currentSong?.isLocal == true) return const SizedBox.shrink();
    final q = player.currentSong?.qualities;
    if (q == null || q.isEmpty) return const SizedBox.shrink();
    final label = ['128K', '320K', 'Hi-Res'];
    final keys = ['128', '320', 'high'];
    final current = _qualityLevel % label.length;
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
                  selected: i == current,
                  onSelected: (_) {
                    _qualityLevel = i;
                    player.switchQuality();
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ),
        ],
      ),
    );
  }

  int _currentLine = 0;
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

  Future<void> _loadLyrics(String hash) async {
    _lyricLoading = true;
    _lastLoadedHash = hash;
    if (mounted) setState(() {});
    try {
      final searchRes = await _musicService.searchLyricByHash(hash);
      final candidates = searchRes['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = c['id'] as int;
        final key = c['accesskey'] as String? ?? '';
        final content = await _musicService.fetchLyricContent(id, key);
        if (content.isNotEmpty) {
          try {
            final decoded = utf8.decode(base64Decode(content));
            _lyrics = _parseLyrics(decoded);
          } catch (e) {
            debugPrint('[PlayerScreen] lyrics decode failed: $e');
          }
        }
      }
    } catch (_) {}
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
