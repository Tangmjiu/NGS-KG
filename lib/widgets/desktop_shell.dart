import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import 'app_overlays.dart';
import '../services/music_service.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../models/rank_entry.dart';
import '../models/song_mapper.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/desktop_song_table.dart';
import '../widgets/player_desktop_view.dart';
import '../screens/home_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';

// ---------------------------------------------------------------------------
// Content mode enum — controls what the content area renders.
// ---------------------------------------------------------------------------

enum _ContentMode { nav, playlist, search, player }

// ---------------------------------------------------------------------------
// DesktopShell — top-level desktop shell orchestration widget.
// ---------------------------------------------------------------------------

class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  final MusicService _musicService = MusicService();

  // ── Navigation state ──

  String _currentNavId = 'home';
  String _searchQuery = '';
  _ContentMode _mode = _ContentMode.nav;

  // ── Playlist detail state ──

  List<Song> _playlistSongs = [];
  String _playlistTitle = '';
  bool _isLoadingPlaylist = false;
  bool _playlistLoaded = false;
  String? _playlistId;

  // ── Ranking state ──

  List<RankEntry> _rankEntries = [];
  bool _isLoadingRankEntries = true;
  RankEntry? _selectedRank;
  List<Song> _rankSongs = [];
  bool _isLoadingRankSongs = false;

  // ── Recent history state ──

  List<Song> _historySongs = [];
  bool _isLoadingHistory = false;
  bool _historyLoaded = false;

  // ── Player bar volume ──

  double _playerVolume = 0.8;

  // ==========================================================================
  // Lifecycle
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _loadRankEntries();
  }

  // ==========================================================================
  // Data loading
  // ==========================================================================

  Future<void> _loadRankEntries() async {
    setState(() => _isLoadingRankEntries = true);
    try {
      final entries = await _musicService.getRankList();
      if (mounted) {
        setState(() {
          _rankEntries = entries;
          _isLoadingRankEntries = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRankEntries = false);
    }
  }

  Future<void> _loadHistory() async {
    if (_historyLoaded || _isLoadingHistory) return;
    setState(() => _isLoadingHistory = true);
    try {
      final raw = await _musicService.getUserHistory();
      if (mounted) {
        setState(() {
          _historySongs = raw
              .map((e) => SongMapper.fromTrackJson(e))
              .whereType<Song>()
              .map((s) => Song(
                    id: s.id,
                    name: s.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                    artists: s.artists,
                    albumName: s.albumName,
                    albumCoverUrl: s.albumCoverUrl,
                    duration: s.duration,
                    lyricUrl: s.lyricUrl,
                    filePath: s.filePath,
                    hash: s.hash,
                    qualities: s.qualities,
                    albumId: s.albumId,
                    fileId: s.fileId,
                    lyrics: s.lyrics,
                  ))
              .toList();
          _historyLoaded = true;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadPlaylistSongs(Playlist pl) async {
    setState(() {
      _isLoadingPlaylist = true;
      _playlistTitle = pl.name;
      _playlistId = pl.globalCollectionId ?? pl.id.toString();
    });
    try {
      final detail = await _musicService.getPlaylistDetail(
        pl.globalCollectionId ?? pl.id.toString(),
      );
      if (mounted) {
        setState(() {
          _playlistSongs = detail.songs;
          _isLoadingPlaylist = false;
          _playlistLoaded = true;
        });
      }
    } catch (_) {
      // Fallback: try fetching tracks directly
      try {
        final songs = await _musicService.getPlaylistTracks(
          pl.globalCollectionId ?? pl.id.toString(),
        );
        if (mounted) {
          setState(() {
            _playlistSongs = songs;
            _isLoadingPlaylist = false;
            _playlistLoaded = true;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingPlaylist = false);
      }
    }
  }

  Future<void> _loadRankSongs(RankEntry rank) async {
    setState(() {
      _selectedRank = rank;
      _isLoadingRankSongs = true;
      _rankSongs = [];
    });
    try {
      final songs = await _musicService.getRankAudios(rank.id);
      if (mounted) {
        setState(() {
          _rankSongs = songs;
          _isLoadingRankSongs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRankSongs = false);
    }
  }

  // ==========================================================================
  // Navigation callbacks (wired to DesktopSidebar)
  // ==========================================================================

  void _onNavSelected(String id) {
    setState(() {
      _currentNavId = id;
      _mode = _ContentMode.nav;
      _searchQuery = '';
      _selectedRank = null;
    });
    if (id == 'recent') _loadHistory();
    if (id == 'ranking' && _rankEntries.isEmpty) _loadRankEntries();
  }

  void _onPlaylistSelected(Playlist pl) {
    setState(() {
      _mode = _ContentMode.playlist;
      _searchQuery = '';
      _selectedRank = null;
    });
    _loadPlaylistSongs(pl);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _mode = query.isNotEmpty ? _ContentMode.search : _ContentMode.nav;
    });
  }

  void _openPlayer() {
    setState(() => _mode = _ContentMode.player);
  }

  void _closePlayer() {
    setState(() => _mode = _ContentMode.nav);
  }

  // ==========================================================================
  // Content area builders
  // ==========================================================================

  Widget _buildContent() {
    switch (_mode) {
      case _ContentMode.player:
        return PlayerDesktopView(onClose: _closePlayer);

      case _ContentMode.playlist:
        return _buildPlaylistDetailView();

      case _ContentMode.search:
        return const SearchScreen();

      case _ContentMode.nav:
        return _buildNavContent();
    }
  }

  Widget _buildNavContent() {
    switch (_currentNavId) {
      case 'home':
        return const HomeScreen();

      case 'discover':
        return const DiscoverScreen();

      case 'profile':
        return const ProfileScreen();

      case 'ranking':
        if (_selectedRank != null) return _buildRankDetailView();
        return _buildRankGridView();

      case 'recent':
        return _buildRecentHistoryView();

      default:
        return const HomeScreen();
    }
  }

  // -------------------------------------------------------------------------
  // Playlist detail
  // -------------------------------------------------------------------------

  Widget _buildPlaylistDetailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_playlistTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              _playlistTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        Expanded(
          child: DesktopSongTable(
            songs: _playlistSongs,
            isLoading: _isLoadingPlaylist,
            emptyMessage: '歌单暂无歌曲',
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Ranking – grid
  // -------------------------------------------------------------------------

  Widget _buildRankGridView() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isLoadingRankEntries) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rankEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('暂无排行榜', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('听歌排行', style: tt.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: _rankEntries.length,
              itemBuilder: (_, i) => _buildRankCard(_rankEntries[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard(RankEntry rank) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _loadRankSongs(rank),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  width: double.infinity,
                  color: cs.surfaceContainerHighest,
                  child: rank.coverUrl != null
                      ? Image.network(rank.coverUrl!, fit: BoxFit.cover)
                      : Icon(Icons.trending_up, size: 40, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(
                rank.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Ranking – detail (song table)
  // -------------------------------------------------------------------------

  Widget _buildRankDetailView() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: cs.onSurface),
                onPressed: () => setState(() => _selectedRank = null),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedRank?.name ?? '',
                style: tt.titleLarge,
              ),
            ],
          ),
        ),
        Expanded(
          child: DesktopSongTable(
            songs: _rankSongs,
            isLoading: _isLoadingRankSongs,
            emptyMessage: '暂无排行歌曲',
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Recent history
  // -------------------------------------------------------------------------

  Widget _buildRecentHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text('最近播放', style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: DesktopSongTable(
            songs: _historySongs,
            isLoading: _isLoadingHistory,
            emptyMessage: '暂无播放记录',
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Build
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_mode == _ContentMode.player) {
      return PlayerDesktopView(onClose: _closePlayer);
    }

    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: cs.surface,
          body: Column(
            children: [
              // ── Main content: sidebar + content area ──
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopSidebar(
                      activeNavId: _currentNavId,
                      activePlaylistId: _playlistLoaded && _playlistId != null
                          ? int.tryParse(_playlistId!)
                          : null,
                      onNavSelected: _onNavSelected,
                      onPlaylistSelected: _onPlaylistSelected,
                      onSearchChanged: _onSearchChanged,
                      searchQuery: _searchQuery,
                    ),
                    // ── Content area ──
                    Expanded(
                      child: _buildContent(),
                    ),
                  ],
                ),
              ),

              // ── Bottom player bar ──
              _DesktopPlayerBar(
                volume: _playerVolume,
                onVolumeChanged: (v) {
                  setState(() => _playerVolume = v);
                  context.read<PlayerProvider>().setVolume(v);
                },
                onOpenPlayer: _openPlayer,
              ),
            ],
          ),
        ),

        // ── 全局覆盖层弹窗 ──
        const ContinuePlayOverlay(),
        const SupportPopupHandler(),
        const UpdateCheckHandler(),
        const LoginPromptOverlay(),
      ],
    );
  }
}

// ============================================================================
// _DesktopPlayerBar — bottom playback bar (~72px height)
// ============================================================================

class _DesktopPlayerBar extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onOpenPlayer;

  const _DesktopPlayerBar({
    required this.volume,
    required this.onVolumeChanged,
    required this.onOpenPlayer,
  });

  String _formatDuration(Duration d) {
    if (d.isNegative) return '0:00';
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequential:
        return Icons.repeat;
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.repeatOne:
        return Icons.repeat_one;
      case PlayMode.radio:
        return Icons.repeat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        final hasSong = song != null;

        return Container(
          height: 72,
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            border: Border(
              top: BorderSide(color: cs.outlineVariant, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Playback progress indicator ──
              SizedBox(
                height: 3,
                child: hasSong
                    ? LinearProgressIndicator(
                        value: player.progress.isFinite ? player.progress : 0.0,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: cs.primary,
                      )
                    : LinearProgressIndicator(
                        backgroundColor: cs.surfaceContainerHighest,
                        color: cs.surfaceContainerHighest,
                      ),
              ),

              // ── Controls row ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // ── Left: Album art + song info ──
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: hasSong ? onOpenPlayer : null,
                          child: Row(
                            children: [
                              // Album art
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: hasSong && song.albumCoverUrl != null
                                      ? Image.network(
                                          song.albumCoverUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _coverPlaceholder(cs),
                                        )
                                      : _coverPlaceholder(cs),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Song name + artist
                              Expanded(
                                child: hasSong
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                             song.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            song.artistDisplay,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: cs.onSurfaceVariant),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        '未在播放',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: cs.onSurfaceVariant),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Center: Transport controls ──
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Play mode
                            _IconBtn(
                              icon: _modeIcon(player.playMode),
                              size: 20,
                              tooltip: '播放模式',
                              onPressed: hasSong
                                  ? () {
                                      const modes = [
                                        PlayMode.sequential,
                                        PlayMode.shuffle,
                                        PlayMode.repeatOne,
                                      ];
                                      final next = modes[
                                          (modes.indexOf(player.playMode) + 1) %
                                              modes.length];
                                      player.setPlayMode(next);
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 4),

                            // Previous
                            _IconBtn(
                              icon: Icons.skip_previous_rounded,
                              size: 28,
                              tooltip: '上一首',
                              onPressed: hasSong ? player.playPrevious : null,
                            ),
                            const SizedBox(width: 4),

                            // Play / Pause
                            _PlayPauseButton(
                              isPlaying: player.isPlaying,
                              isLoading: player.isLoading,
                              onPressed: hasSong ? player.togglePlayPause : null,
                            ),
                            const SizedBox(width: 4),

                            // Next
                            _IconBtn(
                              icon: Icons.skip_next_rounded,
                              size: 28,
                              tooltip: '下一首',
                              onPressed: hasSong ? player.playNext : null,
                            ),
                          ],
                        ),
                      ),

                      // ── Right: Volume + time ──
                      Expanded(
                        flex: 2,
                        child: LayoutBuilder(
                          builder: (_, constraints) {
                            final narrow = constraints.maxWidth < 200;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Time display (hide on very narrow)
                                if (hasSong && !narrow)
                                  Flexible(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        '${_formatDuration(player.position)} / ${_formatDuration(player.duration)}',
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                      ),
                                    ),
                                  ),

                                // Volume
                                Icon(
                                  volume > 0.5
                                      ? Icons.volume_up
                                      : (volume > 0.0 ? Icons.volume_down : Icons.volume_mute),
                                  size: 20,
                                  color: cs.onSurfaceVariant,
                                ),
                                SizedBox(
                                  width: narrow ? 60 : 80,
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(
                                          overlayRadius: 12),
                                      activeTrackColor: cs.primary,
                                      inactiveTrackColor: cs.surfaceContainerHighest,
                                      thumbColor: cs.primary,
                                      overlayColor: cs.primary.withValues(alpha: 0.12),
                                    ),
                                    child: Slider(
                                      value: volume,
                                      onChanged: onVolumeChanged,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _coverPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: 24, color: cs.onSurfaceVariant),
    );
  }
}

// ============================================================================
// Small icon button for player bar controls
// ============================================================================

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback? onPressed;

  const _IconBtn({
    required this.icon,
    required this.size,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon, size: size),
      color: onPressed != null ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.4),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

// ============================================================================
// Play / Pause button (themed circle)
// ============================================================================

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(22),
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? cs.primary : cs.surfaceContainerHighest,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _buildChild(cs, enabled),
        ),
      ),
    );
  }

  Widget _buildChild(ColorScheme cs, bool enabled) {
    if (isLoading) {
      return SizedBox(
        key: const ValueKey('loading'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: cs.onPrimary,
        ),
      );
    }
    return Icon(
      key: ValueKey(isPlaying),
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 26,
      color: enabled ? cs.onPrimary : cs.onSurfaceVariant.withValues(alpha: 0.4),
    );
  }
}
