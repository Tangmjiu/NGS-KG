
// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 本地音乐屏幕 — 显示手表本地音频文件，支持扫描与播放

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/local_music_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/watch_song_tile.dart';
import '../widgets/round_safe_area.dart';

/// 手表版本地音乐屏幕 — 显示本地存储的音频文件，支持扫描与播放
///
/// 集成在 [WatchHome] 的 PageView 中，作为独立页面使用。
/// 首次进入时自动扫描本地音频，提供扫描按钮和歌曲列表。
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
        if (!local.scanned) {
          local.scanMusic();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RoundSafeArea(
      child: Consumer2<LocalMusicProvider, PlayerProvider>(
        builder: (context, local, player, _) {
          final songs = local.songs;
          final isScanning = local.isScanning;
          final currentSong = player.currentSong;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 标题栏：标题 + 歌曲数 + 刷新按钮 ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '本地音乐',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 歌曲计数（非空且未扫描时显示）
                    if (!isScanning && songs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${songs.length} 首',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    // 刷新 / 加载指示
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: isScanning
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : Icon(Icons.refresh, size: 18),
                        onPressed:
                            isScanning ? null : () => local.scanMusic(),
                        visualDensity: VisualDensity.compact,
                        tooltip: '扫描本地音乐',
                      ),
                    ),
                  ],
                ),

                // ── 扫描进度条 ──
                if (isScanning)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                const SizedBox(height: 4),

                // ── 空状态（无歌曲且未扫描时） ──
                if (songs.isEmpty && !isScanning)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.music_note_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '未找到本地音乐',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => local.scanMusic(),
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text('扫描本地音乐'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── 歌曲列表 ──
                if (songs.isNotEmpty)
                  ...songs.map((localSong) {
                    final isPlaying =
                        currentSong?.filePath == localSong.filePath;
                    return WatchSongTile(
                      title: localSong.displayName,
                      artist: localSong.artist,
                      subtitle: localSong.album,
                      isPlaying: isPlaying,
                      onTap: () {
                        final song =
                            LocalMusicProvider.localSongToSong(localSong);
                        final playlist = local.toSongList();
                        player.playSong(song, playlist: playlist);
                      },
                    );
                  }),

                // ── 底部间距 ──
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

