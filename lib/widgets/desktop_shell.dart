import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import 'app_overlays.dart';
import 'shell_navigation_scope.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../models/playlist.dart';
import '../screens/playlist_detail_screen.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/desktop_song_table.dart';
import '../widgets/m3_title_bar.dart';
import '../widgets/player_desktop_view.dart';
import 'local_cover_art.dart';
import '../screens/home_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';
import '../screens/local_music_screen.dart';

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
  Timer? _searchDebounce;
  _ContentMode _mode = _ContentMode.nav;

  // ── Playlist detail state ──

  List<Song> _playlistSongs = [];
  String _playlistTitle = '';
  bool _isLoadingPlaylist = false;
  bool _playlistLoaded = false;
  String? _playlistId;

  // ── Recent history state ──

  List<Song> _historySongs = [];
  bool _isLoadingHistory = false;
  bool _historyLoaded = false;

  // ── Shell-level detail stack ──

  final List<Widget> _detailStack = [];

  void _openInShell(Widget page) {
    setState(() => _detailStack.add(page));
  }

  void _popFromShell() {
    if (_detailStack.isNotEmpty) {
      setState(() => _detailStack.removeLast());
    }
  }

  bool get _canPopInShell => _detailStack.isNotEmpty;

  // ── Player bar volume ──

  double _playerVolume = 0.8;

  // ==========================================================================
  // Lifecycle
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Load user playlists for sidebar immediately after auth is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn && auth.user?.userId != null) {
        context.read<PlaylistProvider>().fetchUserPlaylist(auth.user!.userId);
      }
      // Listen for future logins
      auth.addListener(() {
        if (auth.isLoggedIn && auth.user?.userId != null) {
          context.read<PlaylistProvider>().fetchUserPlaylist(auth.user!.userId);
        }
      });
    });
  }

  // ==========================================================================
  // Data loading
  // ==========================================================================

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

  String _playlistGcId(Playlist pl) {
    if (pl.globalCollectionId != null && pl.globalCollectionId!.isNotEmpty) {
      return pl.globalCollectionId!;
    }
    final userId = pl.createUserId ?? int.tryParse(ApiClient.userId ?? '');
    if (userId != null) {
      return 'collection_3_${userId}_${pl.id}_0';
    }
    return pl.id.toString();
  }

  Future<void> _loadPlaylistSongs(Playlist pl) async {
    final gcId = _playlistGcId(pl);
    setState(() {
      _isLoadingPlaylist = true;
      _playlistTitle = pl.name;
      _playlistId = gcId;
    });
    try {
      final detail = await _musicService.getPlaylistDetail(gcId);
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
        final songs = await _musicService.getPlaylistTracks(gcId);
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

  // ==========================================================================
  // Navigation callbacks (wired to DesktopSidebar)
  // ==========================================================================

  void _onNavSelected(String id) {
    // Clear any pushed detail pages so the base content is visible
    _detailStack.clear();
    setState(() {
      _currentNavId = id;
      _mode = _ContentMode.nav;
      _searchQuery = '';
    });
    if (id == 'recent') _loadHistory();
  }

  void _onPlaylistSelected(Playlist pl) {
    _detailStack.clear();
    setState(() {
      _searchQuery = '';
    });
    // Reuse PlaylistDetailScreen — same code path as clicking from ProfileScreen
    final gcId = _playlistGcId(pl);
    _openInShell(PlaylistDetailScreen(
      key: ValueKey('pl_$gcId'),
      gcId: gcId,
      playlistName: pl.name,
    ));
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _mode = _ContentMode.nav;
      });
      return;
    }
    _searchQuery = query;
    // Debounce 300ms: wait for user to stop typing before showing results
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _mode = _ContentMode.search;
        });
      }
    });
  }

  void _openPlayer() {
    setState(() => _mode = _ContentMode.player);
  }

  // ==========================================================================
  // Content area builders
  // ==========================================================================

  Widget _buildContent() {
    switch (_mode) {
      case _ContentMode.search:
        return SearchScreen(initialQuery: _searchQuery);

      case _ContentMode.nav:
        return _buildNavContent();

      default:
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

      case 'local':
        return const LocalMusicScreen();

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

  // -------------------------------------------------------------------------
  // Recent history
  // -------------------------------------------------------------------------

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有听歌历史吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() {
        _historySongs.clear();
        _historyLoaded = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('播放记录已清空')),
        );
      }
    }
  }

  Widget _buildRecentHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              Text('最近播放', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (_historySongs.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('清空'),
                  onPressed: _clearHistory,
                ),
            ],
          ),
        ),
        Expanded(
          child: DesktopSongTable(
            songs: _historySongs,
            isLoading: _isLoadingHistory,
            emptyMessage: '暂无播放记录',
            currentSongId: context.watch<PlayerProvider>().currentSong?.id,
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
    return Stack(
      children: [
        Column(
          children: [
            // ── 自定义 MD3 标题栏 ──
            // 始终位于窗口顶部。原生标题栏已在 win32_window.cpp
            // 中通过移除 WS_CAPTION 隐藏，Windows 11 Snap Layout
            // 通过 WM_NCHITTEST 返回 HTMAXBUTTON 保留。
            const M3TitleBar(title: 'NGS-KG+'),

            // ── 主体内容 ──
            Expanded(child: _buildContentArea()),
          ],
        ),

        // ── 全局覆盖层弹窗 ──
        const ContinuePlayOverlay(),
        const SupportPopupHandler(),
        const UpdateCheckHandler(),
        const LoginPromptOverlay(),
      ],
    );
  }

  /// 构建主体内容区域（player 全屏模式或普通桌面模式）。
  Widget _buildContentArea() {
    final isPlayer = _mode == _ContentMode.player;
    final cs = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
      child: isPlayer
          ? PlayerDesktopView(
              key: const ValueKey('player_view'),
              onClose: () => setState(() => _mode = _ContentMode.nav),
            )
          : Scaffold(
              key: const ValueKey('normal_content'),
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
                        // ── Content area (with shell-level page stack) ──
                        Expanded(
                          child: ShellNavigationScope(
                            openInShell: _openInShell,
                            pop: _popFromShell,
                            canPop: _canPopInShell,
                            navigateToSidebar: _onNavSelected,
                            openPlayer: _openPlayer,
                            // Switch between base content and detail page
                            child: _detailStack.isEmpty
                                ? _buildContent()
                                : _detailStack.last,
                          ),
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
              // ── Seekable progress bar ──
              SizedBox(
                height: 12,
                child: hasSong
                    ? SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                          activeTrackColor: cs.primary,
                          inactiveTrackColor: cs.surfaceContainerHighest,
                          thumbColor: Colors.transparent,
                        ),
                        child: Slider(
                          value: player.progress.isFinite ? player.progress : 0.0,
                          onChanged: (v) => player.seek(Duration(
                            milliseconds: (v * player.duration.inMilliseconds).round(),
                          )),
                        ),
                      )
                    : const SizedBox.shrink(),
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
                              LocalCoverArt(
                                url: song?.albumCoverUrl,
                                size: 48,
                                borderRadius: 6,
                                coverData: song?.coverData,
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
                                        '${_formatDuration(player.position)}',
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
