import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../models/song.dart';
import '../constants/quality.dart';
import '../widgets/player_background.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/player_controls_bar.dart';
import '../screens/audio_effects_screen.dart';
import '../widgets/playlist_side_sheet.dart';

/// LyricView 样式（Apple Music 风格，居中适配桌面）
final _desktopLyricStyle = LyricStyle(
  textStyle: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: Colors.white54,
  ),
  activeStyle: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: Colors.white,
  ),
  translationStyle: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w300,
    height: 1.2,
    color: Colors.white38,
  ),
  activeHighlightColor: Colors.white,
  activeHighlightExtraFadeWidth: 14,
  lineGap: 24,
  translationLineGap: 4,
  lineTextAlign: TextAlign.center,
  contentAlignment: CrossAxisAlignment.center,
  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
  selectionAnchorPosition: 0.5,
  selectionAlignment: MainAxisAlignment.center,
  activeAnchorPosition: 0.5,
  activeAlignment: MainAxisAlignment.center,
  selectedColor: Colors.white,
  selectedTranslationColor: Colors.white,
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
/// 由 AppShell 在 player 模式下渲染，覆盖全内容区。
/// NavigationRail 隐藏，MiniPlayer 隐藏。
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<PlayerProvider>(
      builder: (ctx, player, _) {
        final song = player.currentSong;
        if (song == null) {
          return Scaffold(
            backgroundColor: cs.surface,
            body: Center(
              child: Text('暂无播放', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          );
        }

        return Scaffold(
          backgroundColor: cs.surface,
          body: Stack(
            children: [
              // 动态背景
              PlayerBackground(
                albumCoverUrl: song.albumCoverUrl,
                paletteColor: player.backgroundColor,
                scrollOffset: 0,
              ),
              // 主内容
              SafeArea(
                child: Column(
                  children: [
                    // ── 顶部返回栏 ──
                    _buildTopBar(),
                    // ── 双栏内容 ──
                    Expanded(child: _buildDualPane(song, player)),
                    // ── 进度条 ──
                    _buildProgressBar(player),
                    const SizedBox(height: 8),
                    // ── 控制按钮 ──
                    _buildControls(player),
                    const SizedBox(height: 8),
                    // ── 底部动作行 ──
                    _buildBottomActions(song, player),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 顶部：仅返回按钮 ──

  Widget _buildTopBar() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                size: 28, color: cs.onSurface),
            tooltip: '收起',
            onPressed: widget.onClose ?? () => Navigator.pop(context),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── 双栏：左封面 + 右歌词 ──

  Widget _buildDualPane(Song song, PlayerProvider player) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 窄屏（<900）回退到单栏
        final narrow = constraints.maxWidth < 700;
        if (narrow) {
          return _buildSingleColumn(song, player);
        }
        return _buildDualColumn(song, player);
      },
    );
  }

  Widget _buildSingleColumn(Song song, PlayerProvider player) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _albumArt(song, 240),
        const SizedBox(height: 16),
        _songInfo(song),
        const Spacer(),
        if (_showLyrics)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LyricView(
                controller: player.lyricController,
                style: _desktopLyricStyle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDualColumn(Song song, PlayerProvider player) {
    return Row(
      children: [
        // 左栏：封面 + 歌名
        Flexible(
          flex: 4,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _albumArt(song, 360),
                const SizedBox(height: 20),
                _songInfo(song),
              ],
            ),
          ),
        ),
        // 右栏：歌词
        if (_showLyrics)
          Flexible(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 32),
              child: LyricView(
                key: ValueKey('desktop_lyrics_${song.hash ?? song.id}'),
                controller: player.lyricController,
                style: _desktopLyricStyle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _albumArt(Song song, double size) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size,
        height: size,
        child: song.albumCoverUrl != null
            ? CachedNetworkImage(
                imageUrl: song.albumCoverUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.music_note, size: 48, color: cs.onSurfaceVariant),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.music_note, size: 48, color: cs.onSurfaceVariant),
                ),
              )
            : Container(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.music_note, size: 48, color: cs.onSurfaceVariant),
              ),
      ),
    );
  }

  Widget _songInfo(Song song) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          song.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          song.artistDisplay,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ── 进度条 ──

  Widget _buildProgressBar(PlayerProvider player) {
    return PlayerProgressBar(
      position: player.position,
      duration: player.duration,
      progress: _isDragging
          ? _dragValue
          : (player.progress.isFinite ? player.progress : 0.0),
      onDragStart: () => setState(() => _isDragging = true),
      onDragEnd: () async {
        await player.seek(Duration(
          milliseconds:
              (_dragValue * player.duration.inMilliseconds).round(),
        ));
        if (mounted) setState(() => _isDragging = false);
      },
      onSeek: (v) => _dragValue = v,
    );
  }

  // ── 播放控制 ──

  Widget _buildControls(PlayerProvider player) {
    return PlayerControlsBar(
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
        final next =
            modes[(modes.indexOf(player.playMode) + 1) % modes.length];
        player.setPlayMode(next);
      },
      onShowPlaylist: () => showPlaylistSideSheet(context),
    );
  }

  // ── 底部动作行 ──

  Widget _buildBottomActions(Song song, PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    final selectedKey =
        Quality.levels[player.qualityLevel % Quality.levels.length];
    final qualityLabel = Quality.label(player.resolvedQuality ?? selectedKey);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 收藏
          Consumer<LikedSongsProvider>(
            builder: (_, lp, __) {
              final liked = lp.likedIds.contains(song.id);
              return _ActionChip(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                label: liked ? '已收藏' : '收藏',
                iconColor: liked ? cs.error : null,
                onTap: () => lp.toggle(SongInfo(
                  id: song.id,
                  name: song.name,
                  hash: song.hash ?? '',
                  albumId: song.albumId,
                  audioId: song.id,
                )),
              );
            },
          ),
          const SizedBox(width: 8),
          // 歌词开关
          _ActionChip(
            icon: _showLyrics ? Icons.lyrics : Icons.lyrics_outlined,
            label: '歌词',
            iconColor: _showLyrics ? cs.primary : null,
            onTap: () => setState(() => _showLyrics = !_showLyrics),
          ),
          const SizedBox(width: 8),
          // 音效
          _ActionChip(
            icon: Icons.tune_rounded,
            label: '音效',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AudioEffectsScreen()),
            ),
          ),
          const SizedBox(width: 8),
          // 音质
          PopupMenuButton<String>(
            onSelected: (key) => player.setQuality(key),
            itemBuilder: (ctx) {
              return Quality.levels.map((key) {
                final label = Quality.label(key);
                return PopupMenuItem<String>(
                  value: key,
                  child: Row(
                    children: [
                      if (key == selectedKey)
                        Icon(Icons.check,
                            size: 18,
                            color: Theme.of(ctx).colorScheme.primary),
                      SizedBox(
                          width: key == selectedKey ? 8 : 26),
                      Text(label),
                    ],
                  ),
                );
              }).toList();
            },
            child: _ActionChip(
              icon: Icons.speed,
              label: qualityLabel,
              onTap: null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 小型动作按钮 ──

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
              Icon(icon, size: 18,
                  color: iconColor ?? cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
