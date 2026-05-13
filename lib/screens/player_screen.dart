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
  bool _showLyrics = false;
  final MusicService _musicService = MusicService();
  List<_LyricLine> _lyrics = [];
  int _currentLine = 0;
  bool _lyricLoading = false;
  String? _lastLoadedHash;
  final ScrollController _lyricScrollController = ScrollController();
  bool _lyricAutoScroll = true;
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
    _lyricScrollController.dispose();
    super.dispose();
  }

  // ────────────────────────────── build ──────────────────────────────

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
        _syncRotation(player.isPlaying);

        return Scaffold(
          appBar: _buildAppBar(song, player),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _showLyrics ? _buildLyricsView(player, song) : _buildCoverView(player, song)),
                _buildLyricPreview(player),
                _buildBottomActionBar(player),
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────── top bar ──────────────────────────────

  PreferredSizeWidget _buildAppBar(Song song, PlayerProvider player) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回',
        onPressed: () => Navigator.pop(context),
      ),
      title: _MarqueeText(
        text: song.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      actions: [
        IconButton(
          icon: Icon(_showLyrics ? Icons.library_music_outlined : Icons.lyrics_outlined),
          tooltip: _showLyrics ? '显示封面' : '显示歌词',
          onPressed: () => setState(() => _showLyrics = !_showLyrics),
        ),
        PopupMenuButton<_MenuAction>(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多',
          onSelected: (action) => _handleMenuAction(action, player, song),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _MenuAction.share, child: ListTile(leading: Icon(Icons.share), title: Text('分享'), dense: true, contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: _MenuAction.download, child: ListTile(leading: Icon(Icons.download), title: Text('下载'), dense: true, contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: _MenuAction.artist, child: ListTile(leading: Icon(Icons.person), title: Text('查看歌手'), dense: true, contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: _MenuAction.quality, child: ListTile(leading: Icon(Icons.tune), title: Text('音质选择'), dense: true, contentPadding: EdgeInsets.zero)),
          ],
        ),
      ],
    );
  }

  void _handleMenuAction(_MenuAction action, PlayerProvider player, Song song) {
    switch (action) {
      case _MenuAction.share:
        break;
      case _MenuAction.download:
        break;
      case _MenuAction.artist:
        break;
      case _MenuAction.quality:
        _showQualitySelector(player);
        break;
    }
  }

  // ────────────────────────────── cover view ──────────────────────────────

  Widget _buildCoverView(PlayerProvider player, Song song) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final coverSize = MediaQuery.of(context).size.width > 600 ? 320.0 : (MediaQuery.of(context).size.width - 64).clamp(200.0, 300.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Album cover with rotation
          Hero(
            tag: 'album_art_${song.hash ?? song.id}',
            child: RotationTransition(
              turns: _rotationController,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Semantics(
                  image: true,
                  label: '${song.name} 专辑封面',
                  child: CachedNetworkImage(
                    imageUrl: song.albumCoverUrl ?? '',
                    width: coverSize,
                    height: coverSize,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: coverSize,
                      height: coverSize,
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.music_note, size: coverSize * 0.25),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: coverSize,
                      height: coverSize,
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.music_note, size: coverSize * 0.25),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Song name
          Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // Artist · Album
          Text(
            '${song.artistDisplay}${song.albumName != null ? ' · ${song.albumName}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          // Progress bar
          _buildProgressSection(player, song, cs, tt),
          const SizedBox(height: 24),
          // Controls
          _buildControls(player, cs),
          const SizedBox(height: 16),
          // Quality chips
          _buildQualityChips(player),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ────────────────────────────── progress ──────────────────────────────

  Widget _buildProgressSection(PlayerProvider player, Song song, ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        Row(
          children: [
            Text(_formatDuration(player.position), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: cs.primary,
                    inactiveTrackColor: cs.surfaceContainerHighest,
                    thumbColor: cs.primary,
                    overlayColor: cs.primary.withAlpha(25),
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
                      player.seek(
                        Duration(milliseconds: (v * player.duration.inMilliseconds).round()),
                      );
                      _syncRotation(player.isPlaying);
                    },
                    onChanged: (v) {
                      setState(() => _dragProgress = v);
                    },
                  ),
                ),
              ),
            ),
            Text(_formatDuration(player.duration), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Consumer<LikedSongsProvider>(
            builder: (_, liked, __) => IconButton(
              icon: Icon(
                liked.likedIds.contains(song.id) ? Icons.favorite : Icons.favorite_border,
                size: 22,
              ),
              tooltip: liked.likedIds.contains(song.id) ? '取消收藏' : '收藏',
              color: liked.likedIds.contains(song.id) ? cs.error : cs.onSurfaceVariant,
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
    );
  }

  // ────────────────────────────── controls ──────────────────────────────

  Widget _buildControls(PlayerProvider player, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Play mode
        IconButton(
          icon: Icon(_playModeIcon(player.playMode), size: 22),
          tooltip: '播放模式',
          color: cs.onSurfaceVariant,
          onPressed: () {
            final modes = [PlayMode.sequential, PlayMode.shuffle, PlayMode.repeatOne];
            final next = modes[(modes.indexOf(player.playMode) + 1) % modes.length];
            player.setPlayMode(next);
          },
        ),
        const SizedBox(width: 8),
        // Previous
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 32),
          tooltip: '上一首',
          onPressed: player.playPrevious,
        ),
        const SizedBox(width: 16),
        // Play/Pause FAB
        SizedBox(
          width: 64,
          height: 64,
          child: FloatingActionButton.large(
            heroTag: 'playPause',
            onPressed: player.togglePlayPause,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(
                key: ValueKey(player.isPlaying),
                player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Next
        IconButton(
          icon: const Icon(Icons.skip_next, size: 32),
          tooltip: '下一首',
          onPressed: player.playNext,
        ),
        const SizedBox(width: 8),
        // Playlist quick access
        IconButton(
          icon: const Icon(Icons.playlist_play, size: 22),
          tooltip: '播放列表',
          color: cs.onSurfaceVariant,
          onPressed: () => _showPlaylist(player),
        ),
      ],
    );
  }

  Widget _buildQualityChips(PlayerProvider player) {
    if (player.currentSong?.isLocal == true) return const SizedBox.shrink();
    final q = player.currentSong?.qualities;
    if (q == null || q.isEmpty) return const SizedBox.shrink();

    const labels = ['标准', 'HQ', '无损'];
    const keys = ['128', '320', 'high'];
    final chips = <Widget>[];
    for (int i = 0; i < keys.length; i++) {
      if (q.containsKey(keys[i])) {
        chips.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(labels[i], style: const TextStyle(fontSize: 11)),
            selected: player.isCurrentQuality(keys[i]),
            onSelected: (_) => player.setQualityIndex(i),
            visualDensity: VisualDensity.compact,
          ),
        ));
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: chips,
    );
  }

  // ────────────────────────────── lyric preview ──────────────────────────────

  Widget _buildLyricPreview(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    final lyricText = _lyrics.isNotEmpty && _currentLine < _lyrics.length
        ? _lyrics[_currentLine].text
        : (_lyricLoading ? '加载歌词中...' : _lyrics.isEmpty && _lastLoadedHash != null ? '暂无歌词' : '');

    return GestureDetector(
      onTap: () => setState(() => _showLyrics = !_showLyrics),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.lyrics_outlined, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lyricText.isEmpty ? '查看完整歌词' : lyricText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            Icon(Icons.keyboard_arrow_up, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────── bottom action bar ──────────────────────────────

  Widget _buildBottomActionBar(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(icon: Icons.queue_music_outlined, label: '播放列表', onTap: () => _showPlaylist(player)),
          _ActionButton(icon: Icons.timer_outlined, label: '定时关闭', onTap: () => _showSleepTimerDialog(player)),
          _ActionButton(icon: Icons.tune_outlined, label: '音效', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioEffectsScreen()))),
        ],
      ),
    );
  }

  // ────────────────────────────── full lyrics view ──────────────────────────────

  Widget _buildLyricsView(PlayerProvider player, Song song) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // Mini header with cover + song info
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CachedNetworkImage(
                    imageUrl: song.albumCoverUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note, size: 24)),
                    errorWidget: (_, __, ___) => Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note, size: 24)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
                    Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Lyrics scroll area
        Expanded(
          child: _lyricLoading
              ? const Center(child: CircularProgressIndicator())
              : _lyrics.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lyrics_outlined, size: 48, color: cs.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text('暂无歌词', style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollStartNotification && n.dragDetails != null) {
                              if (_lyricAutoScroll) setState(() => _lyricAutoScroll = false);
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _lyricScrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _lyrics.length,
                            itemBuilder: (_, i) {
                              final line = _lyrics[i];
                              final isCurrent = i == _currentLine;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: GestureDetector(
                                  onTap: () => player.seek(line.time),
                                  child: Text(
                                    line.text,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isCurrent ? 17 : 14,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                                    ),
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
                                setState(() => _lyricAutoScroll = true);
                                _scrollToCurrentLine();
                              },
                              child: const Icon(Icons.skip_next, size: 20),
                            ),
                          ),
                      ],
                    ),
        ),
        // Progress + controls in lyrics view
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: _buildProgressSection(player, song, cs, tt),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: _buildControls(player, cs),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ────────────────────────────── rotation sync ──────────────────────────────

  void _syncRotation(bool isPlaying) {
    if (isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  // ────────────────────────────── dialogs & overlays ──────────────────────────────

  void _showSleepTimerDialog(PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('睡眠定时', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...[15, 30, 45, 60].map((m) => ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text('$m 分钟'),
              trailing: player.sleepTimerRemaining?.inMinutes == m ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                player.setSleepTimer(Duration(minutes: m));
                Navigator.pop(ctx);
              },
            )),
            if (player.sleepTimerRemaining != null)
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error),
                title: Text('取消定时', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  player.cancelSleepTimer();
                  Navigator.pop(ctx);
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
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('播放列表', style: Theme.of(context).textTheme.titleSmall),
              trailing: Text('${player.playlist.length} 首', style: Theme.of(context).textTheme.bodySmall),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            if (player.playlist.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Text('列表为空'))
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
                        backgroundColor: i == player.currentIndex ? cs.primaryContainer : Colors.transparent,
                        child: Text('${i + 1}', style: TextStyle(
                          fontSize: 12,
                          color: i == player.currentIndex ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                        )),
                      ),
                      title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      selected: i == player.currentIndex,
                      selectedTileColor: cs.primaryContainer.withAlpha(40),
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
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      FilledButton(onPressed: () { Navigator.pop(ctx); player.setPlaylist([]); },
                        child: Text('清空', style: TextStyle(color: cs.onError)),
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
              return const Padding(padding: EdgeInsets.all(24), child: Text('暂无歌单'));
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('收藏到歌单', style: Theme.of(context).textTheme.titleSmall),
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
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
              child: Text('音质选择', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...available.map((i) => ListTile(
              leading: Icon(
                i == 0 ? Icons.sd : i == 1 ? Icons.hd : Icons.album,
                color: player.isCurrentQuality(keys[i]) ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(labels[i]),
              trailing: player.isCurrentQuality(keys[i]) ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
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
          _scrollToCurrentLine();
          if (mounted) setState(() {});
        }
        return;
      }
    }
  }

  void _scrollToCurrentLine() {
    if (!_lyricAutoScroll || !_lyricScrollController.hasClients) return;
    final offset = _currentLine * 56.0 - 200;
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
      final searchRes = await _musicService.searchLyricByHash(hash, keywords: songName);
      final data = searchRes['data'] as Map<String, dynamic>? ?? searchRes;
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

  // ────────────────────────────── helpers ──────────────────────────────

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
}

// ────────────────────────────── helper widgets ──────────────────────────────

enum _MenuAction { share, download, artist, quality }

class _LyricLine {
  final Duration time;
  final String text;
  const _LyricLine({required this.time, required this.text});
}

/// Marquee text that scrolls horizontally when its content overflows.
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _MarqueeText({required this.text, this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _overflow = false;

  @override
  void didUpdateWidget(_MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _stop();
      _overflow = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
  }

  void _startIfNeeded() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      if (_overflow) setState(() => _overflow = false);
      return;
    }
    setState(() => _overflow = true);
    const step = 1.0;
    const interval = Duration(milliseconds: 30);
    const pause = Duration(seconds: 2);

    _timer = Timer.periodic(interval, (timer) {
      if (!mounted) { timer.cancel(); return; }
      final next = _scrollController.offset + step;
      if (next >= maxScroll) {
        timer.cancel();
        Future.delayed(pause, () {
          if (!mounted) return;
          _scrollController.jumpTo(0);
          _timer = Timer.periodic(interval, (t) {
            if (!mounted) { t.cancel(); return; }
            final n = _scrollController.offset + step;
            if (n >= maxScroll) {
              t.cancel();
              Future.delayed(pause, () {
                if (mounted) { _scrollController.jumpTo(0); _startIfNeeded(); }
              });
            } else {
              _scrollController.jumpTo(n);
            }
          });
        });
      } else {
        _scrollController.jumpTo(next);
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  void dispose() {
    _stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: cs.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
