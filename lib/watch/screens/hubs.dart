// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/quality.dart';
import '../../providers/audio_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../utils/format.dart';
import '../utils/watch_layout.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_album_backdrop.dart';
import '../widgets/watch_cover_art.dart';
import '../widgets/watch_quick_panel.dart';
import 'audio_output_screen.dart';
import 'fm_screen.dart';
import 'liked_songs_screen.dart';
import 'local_music_screen.dart';
import 'login_screen.dart';
import 'player_screen.dart';
import 'playlist_list_screen.dart';
import 'queue_screen.dart';
import 'rank_list_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class ListenHubPage extends StatelessWidget {
  const ListenHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    final colors = Theme.of(context).colorScheme;
    final layout = WatchLayout.of(context);
    final inset = layout.isRound ? layout.diameter * .12 : 8.0;
    void findMusic() => _open(context, const WatchSearchScreen());
    void openPlayer() => _open(context, const WatchPlayerScreen());
    return Stack(
      fit: StackFit.expand,
      children: [
        WatchAlbumBackdrop(
          art: song?.albumCoverUrl,
          tone: player.palette?.dominant,
        ),
        ListView(
          primary: true,
          padding: EdgeInsets.zero,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: layout.screenSize.height),
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, inset + 2, inset, inset),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (song != null) ...[
                      InkWell(
                        onTap: openPlayer,
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              Text(
                                song.artistDisplay,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                song.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: layout.isCompact ? 29 : 35,
                                  height: 1.04,
                                  letterSpacing: -1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${formatWatchDuration(player.position)} / ${formatWatchDuration(player.duration)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '搜索',
                            onPressed: findMusic,
                            icon: const Icon(Icons.search_rounded),
                          ),
                          IconButton.filledTonal(
                            tooltip: player.isPlaying ? '暂停' : '播放',
                            onPressed: player.togglePlayPause,
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                          IconButton(
                            tooltip: '快捷操作',
                            onPressed: () => WatchQuickPanel.show(context),
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                    ] else ...[
                      Icon(
                        Icons.album_outlined,
                        size: 32,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '听音乐',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: findMusic,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('找歌'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 2, inset, inset),
              child: Column(
                children: [
                  const _Link('私人 FM', Icons.radio_rounded, WatchFmScreen()),
                  const _Link(
                    '排行榜',
                    Icons.leaderboard_rounded,
                    WatchRankListScreen(),
                  ),
                  if (song != null)
                    const _Link(
                      '播放队列',
                      Icons.queue_music_rounded,
                      WatchQueueScreen(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu(this.title, this.rows);
  final String title;
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final inset = layout.isRound ? layout.diameter * .12 : 8.0;
    final playing = context.select((PlayerProvider p) => p.currentSong != null);
    return ListView(
      primary: true,
      padding: EdgeInsets.fromLTRB(
        inset,
        inset + 4,
        inset,
        inset + (playing ? 60 : 0),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ...rows,
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.icon, this.screen);
  final String label;
  final IconData icon;
  final Widget screen;
  @override
  Widget build(BuildContext context) => RoundListTile(
    title: label,
    leading: Icon(icon),
    onTap: () => _open(context, screen),
  );
}

class DiscoverHubPage extends StatelessWidget {
  const DiscoverHubPage({super.key});
  @override
  Widget build(BuildContext context) => const _Menu('发现', [
    _Link('搜索', Icons.search_rounded, WatchSearchScreen()),
    _Link('私人 FM', Icons.radio_rounded, WatchFmScreen()),
    _Link('排行榜', Icons.leaderboard_rounded, WatchRankListScreen()),
  ]);
}

class LibraryHubPage extends StatelessWidget {
  const LibraryHubPage({super.key});
  @override
  Widget build(BuildContext context) => const _Menu('音乐库', [
    _Link('歌单', Icons.library_music_rounded, WatchPlaylistListScreen()),
    _Link('收藏', Icons.favorite_outline_rounded, WatchLikedSongsScreen()),
    _Link('本地音乐', Icons.folder_open_rounded, WatchLocalMusicScreen()),
    _Link('播放队列', Icons.queue_music_rounded, WatchQueueScreen()),
  ]);
}

class MeHubPage extends StatelessWidget {
  const MeHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final prefs = context.watch<AudioSettingsProvider>();
    return _Menu('设备与我', [
      RoundListTile(
        title: auth.isLoggedIn ? (user?.nickname ?? '我的账号') : '登录',
        subtitle: auth.isLoggedIn && user?.isVipActive == true
            ? user?.vipLevelDisplay
            : null,
        leading: auth.isLoggedIn && user?.avatarUrl?.isNotEmpty == true
            ? WatchCoverArt(imageUrl: user!.avatarUrl, size: 28, round: true)
            : const Icon(Icons.person_outline_rounded),
        onTap: () => _open(
          context,
          auth.isLoggedIn
              ? const WatchSettingsScreen()
              : const WatchLoginScreen(),
        ),
      ),
      RoundListTile(
        title: 'Wi-Fi 音质',
        subtitle: Quality.label(prefs.wifiQuality),
        leading: const Icon(Icons.graphic_eq_rounded),
        onTap: () => _open(context, const WatchWifiQualityScreen()),
      ),
      const _Link('音频输出', Icons.headphones_rounded, WatchAudioOutputScreen()),
      const _Link('设置', Icons.settings_outlined, WatchSettingsScreen()),
      if (auth.isLoggedIn)
        RoundListTile(
          title: '退出登录',
          leading: const Icon(Icons.logout_rounded),
          onTap: () => confirmWatchLogout(context),
        ),
    ]);
  }
}
