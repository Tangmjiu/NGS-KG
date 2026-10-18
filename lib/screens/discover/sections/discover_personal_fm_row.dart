// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/song.dart';
import '../../../providers/discover_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_theme_tokens.dart';
import '../../../ui/components/app_components.dart';
import '../../../ui/components/app_primary_button.dart';
import 'discover_media_rail.dart';

class DiscoverPersonalFmRow extends StatefulWidget {
  const DiscoverPersonalFmRow({super.key});

  @override
  State<DiscoverPersonalFmRow> createState() => _DiscoverPersonalFmRowState();
}

class _DiscoverPersonalFmRowState extends State<DiscoverPersonalFmRow> {
  bool _busy = false;
  bool _preloaded = false;

  static const _modes = [
    ('normal', '红心'),
    ('small', '小众'),
    ('peak', '速览'),
  ];
  static const _pools = ['口味', '风格', '探索'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preloaded) return;
    _preloaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DiscoverProvider>().ensureLoaded();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeMode(
      DiscoverProvider provider, PlayerProvider player, String mode) async {
    if (provider.fmMode == mode || _busy) return;
    await _run(() async {
      provider.setFmMode(mode);
      if (player.isFmMode) {
        await provider.switchFmPlayback(player);
      } else {
        await provider.replaceFmBuffer();
      }
    });
  }

  Future<void> _changePool(
      DiscoverProvider provider, PlayerProvider player, int pool) async {
    if (provider.fmPoolId == pool || _busy) return;
    await _run(() async {
      provider.setFmPoolId(pool);
      if (player.isFmMode) {
        await provider.switchFmPlayback(player);
      } else {
        await provider.replaceFmBuffer();
      }
    });
  }

  Future<void> _start(DiscoverProvider provider, PlayerProvider player) =>
      _run(() async {
        await provider.startFmPlayback(player);
        if (mounted && !player.isFmMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂时没有推荐歌曲，请稍后重试')),
          );
        }
      });

  Future<void> _dislike(
          DiscoverProvider provider, PlayerProvider player, Song song) =>
      _run(() async {
        await provider.dislikeCurrentFmSong(song);
        // 用户可能在反馈请求完成前切到其他歌曲，不能再跳过新的当前歌曲。
        if (mounted && player.isFmMode && identical(player.currentSong, song)) {
          player.playNext();
        }
      });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiscoverProvider>();
    final player = context.watch<PlayerProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final active = player.isFmMode;
    final song = active ? player.currentSong : null;
    final preview = provider.personalFmBuffer.isNotEmpty
        ? provider.personalFmBuffer
        : provider.personalFmSongs;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppThemeTokens.of(context).pagePadding),
      child: AppSurface(
        color: cs.primaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waves_rounded, color: cs.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('私人 FM',
                      style: tt.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ),
                IconButton.filledTonal(
                  tooltip: '更多电台',
                  onPressed: () => Navigator.pushNamed(context, '/fm'),
                  icon: const Icon(Icons.arrow_outward_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('从你的喜好出发，遇见下一首好歌',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final mode in _modes)
                  ChoiceChip(
                    label: Text(mode.$2),
                    selected: provider.fmMode == mode.$1,
                    onSelected: _busy
                        ? null
                        : (_) => _changeMode(provider, player, mode.$1),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('推荐方式', style: tt.labelMedium),
                for (var index = 0; index < _pools.length; index++)
                  ChoiceChip(
                    label: Text(_pools[index]),
                    selected: provider.fmPoolId == index,
                    onSelected: _busy
                        ? null
                        : (_) => _changePool(provider, player, index),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (song != null) ...[
              Row(
                children: [
                  DiscoverArtwork(
                      url: song.thumbnailCoverUrl, size: 72, radius: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(song.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall),
                        if (song.recDesc?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 5),
                          Text(song.recDesc!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  tt.labelSmall?.copyWith(color: cs.primary)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    tooltip: '不喜欢这首歌',
                    onPressed: () => _dislike(provider, player, song),
                    icon: const Icon(Icons.heart_broken_outlined),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AppPrimaryButton(
                        onPressed: player.togglePlayPause,
                        icon: player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        label: player.isPlaying ? '暂停' : '继续',
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: '下一首',
                    onPressed: player.playNext,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              _upcoming(player, provider.personalFmBuffer, song),
            ] else ...[
              if (preview.isNotEmpty) ...[
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: preview.length.clamp(0, 5),
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) => DiscoverArtwork(
                        url: preview[index].thumbnailCoverUrl,
                        size: 78,
                        radius: 24),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              AppPrimaryButton(
                onPressed: () => _start(provider, player),
                icon: Icons.play_arrow_rounded,
                label: '开启私人 FM',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _upcoming(PlayerProvider player, List<Song> buffer, Song current) {
    final upcoming = <Song>[];
    final seen = <String>{};
    for (final song in [
      ...player.playlist.skip(player.currentIndex + 1),
      ...buffer,
    ]) {
      final key = song.hash ?? song.mixSongId?.toString() ?? song.id.toString();
      if (identical(song, current) || !seen.add(key)) continue;
      upcoming.add(song);
      if (upcoming.length == 5) break;
    }
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('接下来', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: upcoming.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final song = upcoming[index];
                return Tooltip(
                  message: song.name,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () {
                      final queueIndex = player.playlist.indexOf(song);
                      if (queueIndex >= 0) {
                        player.playIndex(queueIndex);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('「${song.name}」将在稍后播放'),
                          ),
                        );
                      }
                    },
                    child: DiscoverArtwork(
                        url: song.thumbnailCoverUrl, size: 52, radius: 26),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
