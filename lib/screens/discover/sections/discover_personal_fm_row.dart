import 'dart:math';
import 'package:flutter/material.dart';
import '../../../utils/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/discover_provider.dart';

/// 私人 FM — MD3 卡片式嵌入式播放器
///
/// 嵌入在发现页顶部，三种状态：空闲 / 加载中 / 播放中。
/// 点击标题循环切换模式：红心 → 小众 → 速览。
/// MD3 Motion: vinyl spin 4s/rev, eq bars 350ms pulse,
/// state crossfade 300ms, button bg 200ms.
class DiscoverPersonalFmRow extends StatefulWidget {
  const DiscoverPersonalFmRow({super.key});

  @override
  State<DiscoverPersonalFmRow> createState() => _DiscoverPersonalFmRowState();
}

class _DiscoverPersonalFmRowState extends State<DiscoverPersonalFmRow>
    with TickerProviderStateMixin {
  bool _fmLoading = false;
  bool _fmPreloaded = false;

  // ─── MD3 Motion: vinyl rotation (4s per rev, standard easing) ───
  late final AnimationController _vinylSpinController;

  // ─── MD3 Motion: equalizer bars (350ms pulse) ───
  late final AnimationController _eqController;
  static const int _eqBarCount = 8;
  final List<double> _eqHeights = List.generate(
    _eqBarCount,
    (_) => Random().nextDouble() * 12 + 4,
  );

  static const _modeValues = ['normal', 'small', 'peak'];
  static const _modeLabels = ['红心', '小众', '速览'];
  static const _poolValues = [0, 1, 2];
  static const _poolLabels = ['口味', '风格', '探索'];

  @override
  void initState() {
    super.initState();
    // MD3: vinyl — 4s per rotation, standard easing for start/stop
    _vinylSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    // MD3: eq — 200ms repeating pulse, snappy
    _eqController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _eqController.addListener(_randomizeEq);
  }

  @override
  void dispose() {
    _vinylSpinController.dispose();
    _eqController.removeListener(_randomizeEq);
    _eqController.dispose();
    super.dispose();
  }

  void _randomizeEq() {
    if (!_eqController.isAnimating) return;
    for (int i = 0; i < _eqBarCount; i++) {
      _eqHeights[i] = Random().nextDouble() * 12 + 4;
    }
  }

  // ─── 同步动画状态与播放状态 ───
  void _syncAnimations(bool isPlaying) {
    if (isPlaying) {
      if (!_vinylSpinController.isAnimating) {
        _vinylSpinController.repeat();
      }
      if (!_eqController.isAnimating) {
        _eqController.repeat();
      }
    } else {
      if (_vinylSpinController.isAnimating) {
        _vinylSpinController.stop();
      }
      if (_eqController.isAnimating) {
        _eqController.stop();
      }
    }
  }

  // ─── 预取 ───
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fmPreloaded) {
      _fmPreloaded = true;
      final provider = context.read<DiscoverProvider>();
      if (provider.personalFmBuffer.isEmpty &&
          provider.personalFmSongs.isEmpty) {
        provider.loadAll();
      }
    }
  }

  // ─── 循环切换模式（立即生效，替换当前播放队列） ───
  void _cycleMode(DiscoverProvider provider, PlayerProvider player) {
    if (_fmLoading) return;
    final currentIndex = _modeValues.indexOf(provider.fmMode);
    final nextIndex = (currentIndex + 1) % _modeValues.length;
    provider.setFmMode(_modeValues[nextIndex]);
    if (provider.isFmActive) {
      provider.switchFmPlayback(player);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final provider = context.watch<DiscoverProvider>();
    final player = context.watch<PlayerProvider>();

    final isFmActive = provider.isFmActive;
    final currentSong = player.currentSong;
    final buffer = provider.personalFmBuffer;
    final fmSongs = provider.personalFmSongs;
    final hasContent = isFmActive || fmSongs.isNotEmpty;
    final modeLabel = _modeLabels[_modeValues.indexOf(provider.fmMode)];
    final isPlaying = player.isPlaying;

    // 同步动画与播放状态
    _syncAnimations(isPlaying && isFmActive);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: AppShape.lg,
        ),
        child: Stack(
          children: [
            // ── 装饰性圆形底图 ──
            Positioned(
              top: -40,
              left: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.tertiary.withValues(alpha: 0.05),
                ),
              ),
            ),
            // ── 主内容 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 顶部：标题行 ──
                  Row(
                    children: [
                      Icon(Icons.podcasts, size: 22, color: cs.primary),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _cycleMode(provider, player),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (c, a) =>
                                  FadeTransition(opacity: a, child: c),
                              child: Text(
                                '$modeLabel Radio',
                                key: ValueKey(modeLabel),
                                style: tt.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isFmActive)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer,
                            borderRadius: AppShape.sm,
                          ),
                          child: Text(
                            '播放中',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ── 算法池（MD3 AnimatedContainer 背景过渡） ──
                  Row(
                    children: [
                      const SizedBox(width: 30),
                      ...List.generate(_poolLabels.length, (i) {
                        final selected = provider.fmPoolId == _poolValues[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _onPoolChanged(
                                provider, player, _poolValues[i]),
                            borderRadius: AppShape.sm,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: selected
                                    ? cs.secondaryContainer
                                    : Colors.transparent,
                                borderRadius: AppShape.sm,
                              ),
                              child: Text(
                                _poolLabels[i],
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: selected
                                      ? cs.onSecondaryContainer
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── 内容区：MD3 AnimatedCrossFade 过渡 ──
                  if (_fmLoading)
                    _buildLoadingState(cs)
                  else
                    ClipRect(
                      child: AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        firstCurve: Curves.easeInOut,
                        secondCurve: Curves.easeInOut,
                        sizeCurve: Curves.easeInOut,
                        crossFadeState: (isFmActive && currentSong != null)
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 140),
                          child: _buildIdleState(cs, provider, player, hasContent),
                        ),
                        secondChild: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 140),
                          child: _buildPlayingState(
                              cs, tt, provider, player, currentSong, buffer),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 空闲状态 ──
  Widget _buildIdleState(ColorScheme cs, DiscoverProvider provider,
      PlayerProvider player, bool hasContent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '根据你的听歌口味智能推荐',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (hasContent)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: provider.personalFmSongs.length > 5
                  ? 5
                  : provider.personalFmSongs.length,
              itemBuilder: (_, i) {
                final song = provider.personalFmSongs[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: AppShape.md,
                    child: song.thumbnailCoverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: song.thumbnailCoverUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            memCacheWidth: 160,
                            memCacheHeight: 160,
                            errorWidget: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.music_note,
                                  color: cs.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.music_note,
                                color: cs.onSurfaceVariant),
                          ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: _fmLoading ? null : () => _startFm(provider, player),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(hasContent ? '继续FM推荐' : '启动私人FM'),
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: AppShape.lg,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 加载状态 ──
  Widget _buildLoadingState(ColorScheme cs) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  // ── 播放中状态 ──
  Widget _buildPlayingState(
    ColorScheme cs,
    TextTheme tt,
    DiscoverProvider provider,
    PlayerProvider player,
    Song? currentSong,
    List<Song> buffer,
  ) {
    if (currentSong == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 歌曲信息 ──
        Text(
          currentSong.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          currentSong.artistDisplay,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (currentSong.recDesc != null &&
            currentSong.recDesc!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            currentSong.recDesc!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 14),
        // ── 底部交互行 ──
        Row(
          children: [
            // 频谱条（MD3 350ms pulse animation）
            AnimatedBuilder(
              animation: _eqController,
              builder: (_, __) => _buildEqualizerBars(cs,
                  isPlaying: player.isPlaying && _eqController.isAnimating),
            ),
            const Spacer(),
            _iconBtn(Icons.heart_broken_outlined,
                cs.error.withValues(alpha: 0.75),
                () => _dislike(provider, player, currentSong)),
            const SizedBox(width: 4),
            _iconBtn(Icons.skip_previous_rounded,
                cs.onSurfaceVariant.withValues(alpha: 0.3), null),
            const SizedBox(width: 8),
            // FAB 播放/暂停
            FloatingActionButton.small(
              heroTag: 'fm_play',
              onPressed: () => player.togglePlayPause(),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (c, a) =>
                    RotationTransition(turns: a, child: c),
                child: Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(player.isPlaying),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _iconBtn(
                Icons.skip_next_rounded, cs.onSurfaceVariant,
                () => player.playNext()),
          ],
        ),
        // ── 即将播放预览 ──
        if (buffer.isNotEmpty ||
            player.playlist.length > player.currentIndex + 1) ...[
          const SizedBox(height: 12),
          _buildUpcomingPreview(cs, player, buffer, currentSong),
        ],
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback? onTap) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: color,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }

  // ── 等距频谱条（MD3 350ms pulse） ──
  Widget _buildEqualizerBars(ColorScheme cs, {required bool isPlaying}) {
    return SizedBox(
      height: 24,
      child: Row(
        children: List.generate(_eqBarCount, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            width: 3,
            height: isPlaying ? _eqHeights[i] : 6.0,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: isPlaying ? 0.8 : 0.25),
              borderRadius: AppShape.xs,
            ),
          );
        }),
      ),
    );
  }

  // ── 即将播放预览（黑胶唱片风格） ──
  Widget _buildUpcomingPreview(ColorScheme cs, PlayerProvider player,
      List<Song> buffer, Song currentSong) {
    final remainingInQueue = player.playlist.length > player.currentIndex + 1
        ? player.playlist.sublist(player.currentIndex + 1)
        : <Song>[];
    final seen = <int>{};
    final combined = <Song>[];
    for (final song in [...remainingInQueue, ...buffer]) {
      if (song.id == currentSong.id) continue;
      if (seen.contains(song.id)) continue;
      seen.add(song.id);
      combined.add(song);
      if (combined.length >= 5) break;
    }
    if (combined.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.25)),
        const SizedBox(height: 8),
        Text('即将播放',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: combined.length,
            itemBuilder: (_, i) {
              final song = combined[i];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                margin: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 黑胶唱片（MD3: hover scale via Transform + InkWell）
                    InkWell(
                      borderRadius: AppShape.xl,
                      onTap: () {},
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: song.thumbnailCoverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: song.thumbnailCoverUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 88,
                                  memCacheHeight: 88,
                                  errorWidget: (_, __, ___) => Container(
                                    color: cs.surfaceContainerHighest,
                                    child: Icon(Icons.music_note,
                                        size: 14,
                                        color: cs.onSurfaceVariant),
                                  ),
                                )
                              : Container(
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(Icons.music_note,
                                      size: 14,
                                      color: cs.onSurfaceVariant),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 交互 ──

  void _onPoolChanged(
      DiscoverProvider provider, PlayerProvider player, int poolId) {
    provider.setFmPoolId(poolId);
    if (provider.isFmActive) {
      // 立即切换算法池，替换整个播放队列
      provider.switchFmPlayback(player);
    }
  }

  Future<void> _startFm(DiscoverProvider provider, PlayerProvider player) async {
    setState(() => _fmLoading = true);
    await provider.startFmPlayback(player);
    if (mounted) setState(() => _fmLoading = false);
  }

  Future<void> _dislike(DiscoverProvider provider, PlayerProvider player,
      Song currentSong) async {
    await provider.dislikeCurrentFmSong(currentSong);
    player.playNext();
  }
}
