import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/playlist_provider.dart';
import '../constants/quality.dart';
import 'app_overlays.dart';
import 'shell_navigation_scope.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';
import '../models/playlist.dart';
import '../screens/album_detail_screen.dart' show AlbumDetailScreen;
import '../screens/artist_detail_screen.dart' show ArtistDetailScreen;
import '../screens/playlist_detail_screen.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/desktop_song_table.dart';
import '../widgets/m3_title_bar.dart';
import '../widgets/player_desktop_view.dart';
import '../widgets/lyric_settings_panel.dart';
import '../widgets/playlist_side_sheet.dart';
import '../widgets/login_required_dialog.dart';
import '../screens/login_screen.dart';
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

                      // ── Right: Favorite · More · Playlist · Time · Volume ──
                      Expanded(
                        flex: 3,
                        child: LayoutBuilder(
                          builder: (_, constraints) {
                            final narrow = constraints.maxWidth < 300;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Favorite
                                if (hasSong)
                                  Consumer<LikedSongsProvider>(
                                    builder: (_, lp, __) {
                                      final liked = lp.likedIds.contains(song.id);
                                      return _IconBtn(
                                        icon: liked ? Icons.favorite : Icons.favorite_border,
                                        size: 18,
                                        iconColor: liked ? Colors.redAccent : null,
                                        tooltip: liked ? '取消收藏' : '收藏',
                                        onPressed: () async {
                                          final auth = context.read<AuthProvider>();
                                          if (!auth.isLoggedIn) {
                                            final goLogin = await showLoginRequiredDialog(context);
                                            if (goLogin && context.mounted) {
                                              ShellNavigationScope.navigate(
                                                context,
                                                routeName: '/login',
                                                shellPageBuilder: () => const LoginScreen(),
                                              );
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
                                  )
                                else
                                  const SizedBox(width: 36),

                                // More options (MD3 Dialog with chips)
                                if (hasSong)
                                  _IconBtn(
                                    icon: Icons.more_horiz,
                                    size: 20,
                                    tooltip: '更多',
                                    onPressed: () => _showBarMoreDialog(context, player, song),
                                  )
                                else
                                  const SizedBox(width: 36),

                                // Playlist
                                _IconBtn(
                                  icon: Icons.playlist_play,
                                  size: 20,
                                  tooltip: '播放列表',
                                  onPressed: hasSong
                                      ? () => showPlaylistSideSheet(context)
                                      : null,
                                ),

                                const SizedBox(width: 4),

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

  // ── Bar "更多" MD3 Dialog ──

  void _showBarMoreDialog(BuildContext ctx, PlayerProvider player, Song? song) {
    final cs = Theme.of(ctx).colorScheme;
    final tt = Theme.of(ctx).textTheme;
    final currentQ = Quality.levels[player.qualityLevel % Quality.levels.length];
    final availableQualities = player.getAvailableQualities();

    String qualitySubtitle(String key) {
      switch (key) {
        case '128': return '128kbps';
        case '320': return '320kbps';
        case 'high':
        case 'flac': return 'FLAC';
        default: return '';
      }
    }

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: cs.surfaceContainerHighest,
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 24, 8),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('更多操作', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 16),

                // ── 倍速 ──
                Text('倍速', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _buildChipRow(cs, player.currentSpeed.toStringAsFixed(1),
                    ['0.5x', '0.75x', '1.0x', '1.25x', '1.5x', '2.0x'],
                    (label) {
                  final speed = double.tryParse(label.replaceAll('x', '')) ?? 1.0;
                  player.setSpeed(speed);
                  Navigator.pop(dialogCtx);
                }, null, null),
                const SizedBox(height: 12),

                // ── 音质 ──
                Text('音质', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _buildChipRow(
                  cs, Quality.label(currentQ),
                  Quality.levels.map((k) => Quality.label(k)).toList(),
                  (label) {
                    final idx = Quality.labels.values.toList().indexOf(label);
                    if (idx >= 0) player.setQuality(Quality.levels[idx]);
                    Navigator.pop(dialogCtx);
                  },
                  (label) {
                    final idx = Quality.labels.values.toList().indexOf(label);
                    if (idx >= 0) return player.isQualityAvailable(Quality.levels[idx]);
                    return true;
                  },
                  (label) {
                    final idx = Quality.labels.values.toList().indexOf(label);
                    if (idx >= 0) return qualitySubtitle(Quality.levels[idx]);
                    return '';
                  },
                ),
                if (availableQualities.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '当前歌曲最高支持: ${Quality.label(availableQualities.last)}',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    ),
                  ),
                const SizedBox(height: 12),

                // ── 音效 ──
                Text('音效', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _buildChipRow(cs, Quality.effectLabel(player.effectKey),
                    ['关闭', ...Quality.effects.map((k) => Quality.effectLabel(k))],
                    (label) {
                  if (label == '关闭') {
                    player.setEffect('none');
                  } else {
                    final effectLabels = Quality.effects.map((k) => Quality.effectLabel(k)).toList();
                    final idx = effectLabels.indexOf(label);
                    if (idx >= 0) player.setEffect(Quality.effects[idx]);
                  }
                  Navigator.pop(dialogCtx);
                }, null, null),
                const SizedBox(height: 12),

                Divider(height: 1, color: cs.outlineVariant),
                const SizedBox(height: 4),

                // ── 操作列表 ──
                _buildActionTile(cs, Icons.timer_outlined, '定时关闭',
                    subtitle: player.sleepTimerRemaining != null
                        ? '剩余 ${player.sleepTimerRemaining!.inMinutes} 分钟'
                        : null,
                    onTap: () {
                  Navigator.pop(dialogCtx);
                  _showBarSleepTimer(ctx, player);
                }),
                _buildActionTile(cs, Icons.lyrics_outlined, '歌词设置', onTap: () {
                  Navigator.pop(dialogCtx);
                  showDialog(
                    context: ctx,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      backgroundColor: cs.surfaceContainerHighest,
                      contentPadding: EdgeInsets.zero,
                      content: const SizedBox(width: 360, child: LyricSettingsPanel()),
                    ),
                  );
                }),
                if (song != null && song.albumId > 0)
                  _buildActionTile(cs, Icons.album, '查看专辑', onTap: () {
                    Navigator.pop(dialogCtx);
                    ShellNavigationScope.navigate(
                      ctx,
                      routeName: '/album/detail',
                      arguments: {'id': song.albumId, 'name': song.albumName},
                      shellPageBuilder: () => AlbumDetailScreen(
                        albumId: song.albumId,
                        albumName: song.albumName,
                      ),
                    );
                  }),
                if (song != null && song.artistId != null && song.artistId! > 0)
                  _buildActionTile(cs, Icons.person, '查看歌手：${song.artistDisplay}', onTap: () {
                    Navigator.pop(dialogCtx);
                    ShellNavigationScope.navigate(
                      ctx,
                      routeName: '/artist/detail',
                      arguments: {
                        'id': song.artistId,
                        'name': song.artists.isNotEmpty ? song.artists.first : '',
                      },
                      shellPageBuilder: () => ArtistDetailScreen(
                        artistId: song.artistId!,
                        artistName: song.artists.isNotEmpty ? song.artists.first : '',
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipRow(
    ColorScheme cs,
    String current,
    List<String> labels,
    void Function(String) onTap,
    bool Function(String)? isAvailable,
    String Function(String)? subtitle,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.map((label) {
        final selected = label == current;
        final available = isAvailable?.call(label) ?? true;
        return Tooltip(
          message: !available ? '当前歌曲不支持' : '',
          child: InkWell(
            onTap: available ? () => onTap(label) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primaryContainer
                    : (available ? cs.surfaceContainerHighest : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? Colors.transparent : (available ? cs.outlineVariant : cs.outlineVariant.withValues(alpha: 0.3)),
                  width: 1,
                ),
              ),
              child: Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? cs.onPrimaryContainer
                        : (available ? cs.onSurfaceVariant : cs.onSurfaceVariant.withValues(alpha: 0.35)),
                  )),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionTile(ColorScheme cs, IconData icon, String text,
      {String? subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 14, color: cs.onSurface)),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showBarSleepTimer(BuildContext ctx, PlayerProvider player) {
    final cs = Theme.of(ctx).colorScheme;
    if (player.sleepTimerRemaining != null) {
      showDialog(
        context: ctx,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: cs.surfaceContainerHighest,
          title: Text('定时关闭', style: TextStyle(color: cs.onSurface)),
          content: Text('剩余 ${player.sleepTimerRemaining!.inMinutes} 分钟',
              style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text('继续', style: TextStyle(color: cs.onSurface))),
            TextButton(
              onPressed: () { player.cancelSleepTimer(); Navigator.pop(c); },
              child: const Text('关闭定时', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: cs.surfaceContainerHighest,
        title: Text('定时关闭', style: TextStyle(color: cs.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('15 分钟', style: TextStyle(color: cs.onSurface)),
                onTap: () { player.setSleepTimer(const Duration(minutes: 15)); Navigator.pop(c); }),
            ListTile(title: Text('30 分钟', style: TextStyle(color: cs.onSurface)),
                onTap: () { player.setSleepTimer(const Duration(minutes: 30)); Navigator.pop(c); }),
            ListTile(title: Text('45 分钟', style: TextStyle(color: cs.onSurface)),
                onTap: () { player.setSleepTimer(const Duration(minutes: 45)); Navigator.pop(c); }),
            ListTile(title: Text('60 分钟', style: TextStyle(color: cs.onSurface)),
                onTap: () { player.setSleepTimer(const Duration(minutes: 60)); Navigator.pop(c); }),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Small icon button for player bar controls
// ============================================================================

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? iconColor;

  const _IconBtn({
    required this.icon,
    required this.size,
    required this.tooltip,
    this.onPressed,
    this.iconColor,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Icon(
              widget.icon,
              key: ValueKey(widget.icon),
              size: widget.size,
            ),
          ),
          color: widget.iconColor ?? (widget.onPressed != null
              ? cs.onSurface
              : cs.onSurfaceVariant.withValues(alpha: 0.4)),
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ),
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
