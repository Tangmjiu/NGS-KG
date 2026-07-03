import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/discover_provider.dart';

/// 私人 FM — MD3 卡片式嵌入式播放器
///
/// 嵌入在发现页顶部，三种状态：空闲 / 加载中 / 播放中。
/// 点击标题循环切换模式：红心 → 小众 → 速览。
class DiscoverPersonalFmRow extends StatefulWidget {
  const DiscoverPersonalFmRow({super.key});

  @override
  State<DiscoverPersonalFmRow> createState() => _DiscoverPersonalFmRowState();
}

class _DiscoverPersonalFmRowState extends State<DiscoverPersonalFmRow> {
  bool _fmLoading = false;
  bool _fmPreloaded = false;

  static const _modeValues = ['normal', 'small', 'peak'];
  static const _modeLabels = ['红心', '小众', '速览'];
  static const _poolValues = [0, 1, 2];
  static const _poolLabels = ['口味', '风格', '探索'];

  // ─── 预取（类似 EchoMusic onMounted 预加载） ───
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fmPreloaded) {
      _fmPreloaded = true;
      final provider = context.read<DiscoverProvider>();
      if (provider.personalFmBuffer.isEmpty && provider.personalFmSongs.isEmpty) {
        // 后台预取，不阻塞 UI
        provider.loadAll();
      }
    }
  }

  // ─── 循环切换模式 ───
  void _cycleMode(DiscoverProvider provider) {
    if (_fmLoading) return; // 加载中不响应
    final currentIndex = _modeValues.indexOf(provider.fmMode);
    final nextIndex = (currentIndex + 1) % _modeValues.length;
    provider.setFmMode(_modeValues[nextIndex]);
    // 如果当前正在播放 FM，模式切换后重新获取并播放
    if (provider.isFmActive) {
      _startFm(provider, context.read<PlayerProvider>());
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
                      // 点击标题循环切换模式
                      GestureDetector(
                        onTap: () => _cycleMode(provider),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$modeLabel Radio',
                              style: tt.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '播放中',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: cs.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ── 副标题 / 算法池 ──
                  Row(
                    children: [
                      const SizedBox(width: 30),
                      ...List.generate(_poolLabels.length, (i) {
                        final selected = provider.fmPoolId == _poolValues[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _onPoolChanged(provider, _poolValues[i]),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: selected
                                    ? cs.secondaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _poolLabels[i],
                                style: TextStyle(
                                  fontSize: 10,
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
                  // ── 内容区 ──
                  if (_fmLoading)
                    _buildLoadingState(cs)
                  else if (isFmActive && currentSong != null)
                    _buildPlayingState(
                        cs, tt, provider, player, currentSong, buffer)
                  else
                    _buildIdleState(cs, provider, player, hasContent),
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
      children: [
        Text(
          '根据你的听歌口味智能推荐',
          style: ttBody(cs, provider.fmMode),
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
                    borderRadius: BorderRadius.circular(10),
                    child: song.albumCoverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: song.albumCoverUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: cs.surfaceContainerHighest,
                              child:
                                  Icon(Icons.music_note, color: cs.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: cs.surfaceContainerHighest,
                            child:
                                Icon(Icons.music_note, color: cs.onSurfaceVariant),
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
    Song currentSong,
    List<Song> buffer,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        if (currentSong.recDesc != null &&
            currentSong.recDesc!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            currentSong.recDesc!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: cs.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 14),
        // ── 底部交互行：等距频谱条 + FAB ──
        Row(
          children: [
            // 频谱条（左侧装饰）
            _buildEqualizerBars(cs, isPlaying: player.isPlaying),
            const Spacer(),
            // 不喜欢按钮
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                icon: Icon(Icons.heart_broken_outlined, size: 18),
                color: cs.error.withValues(alpha: 0.75),
                onPressed: () => _dislike(provider, player, currentSong),
                padding: EdgeInsets.zero,
                splashRadius: 18,
              ),
            ),
            const SizedBox(width: 4),
            // 上一首（FM 不可用，灰显）
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                icon: Icon(Icons.skip_previous_rounded, size: 20),
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                onPressed: null,
                padding: EdgeInsets.zero,
                splashRadius: 18,
              ),
            ),
            const SizedBox(width: 8),
            // 播放/暂停 FAB
            FloatingActionButton.small(
              heroTag: 'fm_play',
              onPressed: () => player.togglePlayPause(),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              child: Icon(
                player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            // 下一首
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                icon: Icon(Icons.skip_next_rounded, size: 20),
                color: cs.onSurfaceVariant,
                onPressed: () => player.playNext(),
                padding: EdgeInsets.zero,
                splashRadius: 18,
              ),
            ),
          ],
        ),
          // ── 即将播放预览 ──
          if (buffer.isNotEmpty || player.playlist.length > player.currentIndex + 1) ...[
            const SizedBox(height: 12),
            _buildUpcomingPreview(cs, player, buffer, currentSong),
          ],
      ],
    );
  }

  // ── 等距频谱条 ──
  Widget _buildEqualizerBars(ColorScheme cs, {required bool isPlaying}) {
    // 8 条高度不同的竖线
    final heights = [8, 14, 10, 18, 12, 16, 9, 13];
    return SizedBox(
      height: 24,
      child: Row(
        children: heights.map((h) {
          return Container(
            width: 3,
            height: h.toDouble(),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: isPlaying ? 0.7 : 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 即将播放预览（黑胶唱片风格） ──
  /// 展示队列剩余歌曲 + 预取池中的歌曲，去重后最多 5 首，不包含当前播放
  Widget _buildUpcomingPreview(ColorScheme cs, PlayerProvider player, List<Song> buffer, Song currentSong) {
    // 队列中尚未播放的歌曲（当前索引之后）
    final remainingInQueue = player.playlist.length > player.currentIndex + 1
        ? player.playlist.sublist(player.currentIndex + 1)
        : <Song>[];
    // 合并队列剩余 + 预取池，去重，排除当前播放
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
            style: TextStyle(
                fontSize: 11,
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
              return Container(
                width: 56,
                margin: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 黑胶唱片 ──
                    Container(
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
                        child: song.albumCoverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: song.albumCoverUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
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
                                    size: 14, color: cs.onSurfaceVariant),
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

  // ── 工具方法 ──
  TextStyle ttBody(ColorScheme cs, String mode) {
    return TextStyle(
      fontSize: 12,
      color: cs.onSurfaceVariant,
    );
  }

  // ── 交互 ──

  void _onPoolChanged(DiscoverProvider provider, int poolId) {
    provider.setFmPoolId(poolId);
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
