import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../models/song.dart';
import '../../../models/song_mapper.dart';
import '../../../providers/player_provider.dart';
import '../../../services/music_service.dart';
import '../../../utils/theme.dart';

/// FM — 横向滚动歌曲卡片
///
/// 支持 mode 切换（红心/小众）和 AI 算法切换（Alpha/Beta/Gamma）
class DiscoverPersonalFmRow extends StatefulWidget {
  final List<Song> songs;
  final VoidCallback onRefresh;

  const DiscoverPersonalFmRow({
    super.key,
    required this.songs,
    required this.onRefresh,
  });

  @override
  State<DiscoverPersonalFmRow> createState() => _DiscoverPersonalFmRowState();
}

class _DiscoverPersonalFmRowState extends State<DiscoverPersonalFmRow> {
  int _modeIndex = 0; // 0=红心(normal), 1=小众(small)
  int _poolIndex = 0; // 0=Alpha, 1=Beta, 2=Gamma

  static const _modes = ['normal', 'small'];
  static const _modeLabels = ['♥ 红心', '🎯 小众'];
  static const _poolLabels = ['Alpha', 'Beta', 'Gamma'];
  static const _poolIds = [0, 1, 2];

  Future<void> _refreshFm() async {
    final mode = _modes[_modeIndex];
    final poolId = _poolIds[_poolIndex];
    final musicService = MusicService();
    try {
      final raw = await musicService.getPersonalFm(mode: mode, songPoolId: poolId);
      if (mounted) {
        final songs = raw
            .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
            .whereType<Song>()
            .toList();
        if (songs.isNotEmpty) {
          final player = context.read<PlayerProvider>();
          player.playSong(songs.first, playlist: songs);
          return; // 播放成功后不触发全页刷新
        }
      }
    } catch (_) {}
    // 获取失败时刷新页面显示空状态
    widget.onRefresh();
  }

  void _playFrom(BuildContext context, int index) {
    final player = context.read<PlayerProvider>();
    player.playSong(widget.songs[index], playlist: widget.songs.sublist(index));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('FM', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              // mode toggle
              ...List.generate(_modeLabels.length, (i) {
                final selected = _modeIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => setState(() => _modeIndex = i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected ? cs.primaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? cs.primary : cs.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _modeLabels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              TextButton.icon(
                onPressed: _refreshFm,
                icon: Icon(Icons.play_arrow, size: 18, color: cs.primary),
                label: Text('播放全部', style: TextStyle(fontSize: 13, color: cs.primary)),
              ),
            ],
          ),
        ),
        // ── AI algorithm toggle ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(_poolLabels.length, (i) {
              final selected = _poolIndex == i;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => _poolIndex = i),
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
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // ── Song cards ──
        if (widget.songs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Text('点击播放全部开始FM推荐', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.songs.length,
              itemBuilder: (_, i) {
                final song = widget.songs[i];
                return GestureDetector(
                  onTap: () => _playFrom(context, i),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: song.albumCoverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: song.albumCoverUrl!,
                                  width: 120, height: 120,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    width: 120, height: 120,
                                    color: cs.surfaceContainerHighest,
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 120, height: 120,
                                    color: cs.surfaceContainerHighest,
                                    child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
                                  ),
                                )
                              : Container(
                                  width: 120, height: 120,
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
