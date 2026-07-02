import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/discover_provider.dart';

/// 私人 FM — 紧凑嵌入式播放器
///
/// 嵌入在发现页顶部，三种状态：
/// - 空闲：模式/池切换 + 「启动FM」按钮
/// - 加载中：微调器
/// - 播放中：当前歌曲卡片 + 传输控件 + 即将播放预览
class DiscoverPersonalFmRow extends StatefulWidget {
  const DiscoverPersonalFmRow({super.key});

  @override
  State<DiscoverPersonalFmRow> createState() => _DiscoverPersonalFmRowState();
}

class _DiscoverPersonalFmRowState extends State<DiscoverPersonalFmRow> {
  bool _fmLoading = false;

  static const _modeValues = ['normal', 'small', 'peak'];
  static const _modeLabels = ['红心', '小众', '速览'];
  static const _poolValues = [0, 1, 2];
  static const _poolLabels = ['口味', '风格', '探索'];

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFmActive
                ? cs.primary.withValues(alpha: 0.2)
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: 标题 + 模式切换 ──
            _buildHeader(cs, tt, provider),

            // ── AI 算法池切换（第二行） ──
            _buildPoolRow(cs, tt, provider),

            // ── 内容区 ──
            if (_fmLoading)
              _buildLoadingState(cs, tt)
            else if (isFmActive && currentSong != null)
              _buildPlayingState(cs, tt, provider, player, currentSong, buffer)
            else
              _buildIdleState(cs, tt, provider, player, hasContent, fmSongs),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader(ColorScheme cs, TextTheme tt, DiscoverProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Icon(Icons.podcasts, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text('FM', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          ...List.generate(_modeLabels.length, (i) {
            final selected = provider.fmMode == _modeValues[i];
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => _onModeChanged(provider, _modeValues[i]),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected ? cs.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? cs.primary : cs.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    _modeLabels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // 当前状态指示
          if (provider.isFmActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '播放中',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.onTertiaryContainer),
              ),
            ),
        ],
      ),
    );
  }

  // ── 算法池切换 ──
  Widget _buildPoolRow(ColorScheme cs, TextTheme tt, DiscoverProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          const SizedBox(width: 28), // 与 "FM" 图标对齐
          ...List.generate(_poolLabels.length, (i) {
            final selected = provider.fmPoolId == _poolValues[i];
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => _onPoolChanged(provider, _poolValues[i]),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? cs.secondaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _poolLabels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── 空闲状态 ──
  Widget _buildIdleState(ColorScheme cs, TextTheme tt,
      DiscoverProvider provider, PlayerProvider player, bool hasContent,
      [List<Song> fmSongs = const []]) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasContent)
            // 有歌但没在播放 → 展示封面预览
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: fmSongs.length > 5 ? 5 : fmSongs.length,
                itemBuilder: (_, i) {
                  final song = fmSongs[i];
                  return GestureDetector(
                    onTap: () => _startFm(provider, player),
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: song.albumCoverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: song.albumCoverUrl!,
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: cs.surfaceContainerHighest,
                                      child: Icon(Icons.music_note,
                                          color: cs.onSurfaceVariant),
                                    ),
                                  )
                                : Container(
                                    width: 90,
                                    height: 90,
                                    color: cs.surfaceContainerHighest,
                                    child: Icon(Icons.music_note,
                                        color: cs.onSurfaceVariant),
                                  ),
                          ),
                        ],
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
              icon: _fmLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                hasContent ? '继续FM推荐' : '启动私人FM',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (!hasContent)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  '根据你的听歌口味智能推荐',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 加载状态 ──
  Widget _buildLoadingState(ColorScheme cs, TextTheme tt) {
    return const Padding(
      padding: EdgeInsets.all(32),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        children: [
          // ── 当前歌曲卡片 ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: currentSong.albumCoverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: currentSong.albumCoverUrl!,
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
              const SizedBox(width: 14),
              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentSong.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currentSong.artistDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    // 推荐理由
                    if (currentSong.recDesc != null &&
                        currentSong.recDesc!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        currentSong.recDesc!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // 传输控件
                    Row(
                      children: [
                        // 不喜欢
                        _iconButton(
                          Icons.heart_broken_outlined,
                          cs.error.withValues(alpha: 0.7),
                          () => _dislike(provider, player, currentSong),
                        ),
                        const SizedBox(width: 4),
                        // 上一首（不可用，FM 没有上一首）
                        _iconButton(
                          Icons.skip_previous_rounded,
                          cs.onSurfaceVariant.withValues(alpha: 0.4),
                          null,
                        ),
                        const SizedBox(width: 4),
                        // 播放/暂停
                        Container(
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: cs.onPrimary,
                              size: 22,
                            ),
                            onPressed: () => player.togglePlayPause(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 40),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // 下一首
                        _iconButton(
                          Icons.skip_next_rounded,
                          cs.onSurfaceVariant,
                          () => player.playNext(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── 即将播放预览 ──
          if (buffer.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildUpcomingPreview(cs, tt, buffer),
          ],
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, Color color, VoidCallback? onTap) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: color,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 18,
    );
  }

  // ── 即将播放预览 ──
  Widget _buildUpcomingPreview(
      ColorScheme cs, TextTheme tt, List<Song> buffer) {
    final previewSongs = buffer.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text('即将播放',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: previewSongs.length,
            itemBuilder: (_, i) {
              final song = previewSongs[i];
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: song.albumCoverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: song.albumCoverUrl!,
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Icon(
                                  Icons.music_note,
                                  size: 14,
                                  color: cs.onSurfaceVariant),
                            )
                          : Icon(Icons.music_note,
                              size: 14, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
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

  void _onModeChanged(DiscoverProvider provider, String mode) {
    provider.setFmMode(mode);
    // 如果当前激活，提示用户重新启动
    if (provider.isFmActive && mounted) setState(() {});
  }

  void _onPoolChanged(DiscoverProvider provider, int poolId) {
    provider.setFmPoolId(poolId);
    if (provider.isFmActive && mounted) setState(() {});
  }

  Future<void> _startFm(DiscoverProvider provider, PlayerProvider player) async {
    setState(() => _fmLoading = true);
    await provider.startFmPlayback(player);
    if (mounted) setState(() => _fmLoading = false);
  }

  Future<void> _dislike(DiscoverProvider provider, PlayerProvider player,
      Song currentSong) async {
    // 上报不喜欢
    await provider.dislikeCurrentFmSong(currentSong);
    // 从队列移除 + 切下一首
    player.playNext();
  }
}
