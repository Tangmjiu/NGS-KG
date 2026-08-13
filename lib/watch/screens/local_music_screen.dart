// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表本地音乐 — 扫描手表本地音频并播放

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/local_music_provider.dart';
import '../../providers/player_provider.dart';
import '../utils/watch_layout.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';

/// 手表版本地音乐（外壳 PageView 第 4 页）。
///
/// 首次进入自动扫描；下拉重新扫描；支持表冠滚动。
class WatchLocalMusicScreen extends StatefulWidget {
  const WatchLocalMusicScreen({super.key});

  @override
  State<WatchLocalMusicScreen> createState() => _WatchLocalMusicScreenState();
}

class _WatchLocalMusicScreenState extends State<WatchLocalMusicScreen> {
  bool _initialScanTriggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialScanTriggered) {
      _initialScanTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final local = context.read<LocalMusicProvider>();
        if (!local.scanned) local.scanMusic();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = WatchLayout.of(context);

    return Padding(
      padding: EdgeInsets.only(top: layout.topInset),
      child: Consumer2<LocalMusicProvider, PlayerProvider>(
        builder: (context, local, player, _) {
          final songs = local.songs;
          final isScanning = local.isScanning;
          final currentSong = player.currentSong;

          if (songs.isEmpty) {
            return _buildEmptyOrScanning(theme, local, isScanning);
          }

          return RefreshIndicator(
            onRefresh: local.scanMusic,
            child: WatchScrollList(
              itemCount: songs.length + 1,
              itemExtent: 52,
              topPadding: 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          '本地音乐',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          '${songs.length} 首',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        if (isScanning) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                final localSong = songs[index - 1];
                final isPlaying = currentSong?.filePath == localSong.filePath;
                return WatchSongTile(
                  title: localSong.displayName,
                  artist: localSong.artist,
                  subtitle: localSong.album,
                  isPlaying: isPlaying,
                  onTap: () {
                    final song = LocalMusicProvider.localSongToSong(localSong);
                    player.playSong(song, playlist: local.toSongList());
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyOrScanning(
      ThemeData theme, LocalMusicProvider local, bool isScanning) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isScanning) ...[
            const CircularProgressIndicator(strokeWidth: 2.5),
            const SizedBox(height: 10),
            Text(
              '正在扫描…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ] else ...[
            Icon(
              Icons.music_note_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              '未找到本地音乐',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: local.scanMusic,
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('扫描本地音乐'),
            ),
          ],
        ],
      ),
    );
  }
}
