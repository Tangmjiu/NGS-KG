// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 四主视图 Hub — YouTube Music Wear OS 风格
// 竖向卡片流：正在播放速览 + 快捷入口，内容驱动而非菜单驱动

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/audio_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../utils/format.dart';
import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_cover_art.dart';
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

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

// ═══════════════════════════════════════════════════════
//  聆听 — 正在播放速览 + 快捷入口卡片流
// ═══════════════════════════════════════════════════════

class ListenHubPage extends StatelessWidget {
  const ListenHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;

    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            layout.listHorizontal,
            layout.topInset + 6,
            layout.listHorizontal,
            layout.bottomInset + 20,
          ),
          children: [
            // ── 正在播放速览卡片（有播放时）──
            if (song != null) ...[
              _NowPlayingCard(
                song: song,
                player: player,
                layout: layout,
              ),
              const SizedBox(height: 10),
            ],
            // ── 快捷入口 ──
            _HubCard(
              icon: Icons.search_rounded,
              title: '搜索',
              subtitle: '搜索歌曲、歌手',
              accent: cs.primary,
              onTap: () => _push(context, const WatchSearchScreen()),
            ),
            _HubCard(
              icon: Icons.radio_rounded,
              title: '私人 FM',
              subtitle: '个性化推荐电台',
              accent: cs.secondary,
              onTap: () => _push(context, const WatchFmScreen()),
            ),
            _HubCard(
              icon: Icons.leaderboard_rounded,
              title: '排行榜',
              subtitle: '热门榜单',
              accent: cs.tertiary,
              onTap: () => _push(context, const WatchRankListScreen()),
            ),
            if (song != null)
              _HubCard(
                icon: Icons.queue_music_rounded,
                title: '播放队列',
                subtitle: '${player.playlist.length} 首',
                accent: cs.primary,
                onTap: () => _push(context, const WatchQueueScreen()),
              ),
          ],
        );
      },
    );
  }
}

/// 正在播放速览卡片 — 封面 + 歌名/歌手 + 进度条 + 迷你控制。
class _NowPlayingCard extends StatelessWidget {
  final dynamic song;
  final PlayerProvider player;
  final WatchLayout layout;

  const _NowPlayingCard({
    required this.song,
    required this.player,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final coverSize = 44.0 * layout.scale;

    return GestureDetector(
      onTap: () {
        WatchMotion.tap();
        _push(context, const WatchPlayerScreen());
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                WatchCoverArt(
                  imageUrl: song.albumCoverUrl,
                  size: coverSize,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.name,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13 * layout.scale,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artistDisplay,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 11 * layout.scale,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 播放/暂停按钮
                Material(
                  color: cs.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      WatchMotion.confirm();
                      player.togglePlayPause();
                    },
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: player.progress.clamp(0.0, 1.0),
                minHeight: 2.5,
                color: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatWatchDuration(player.position),
                  style: TextStyle(
                    fontSize: 9 * layout.scale,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  formatWatchDuration(player.duration),
                  style: TextStyle(
                    fontSize: 9 * layout.scale,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  发现 — 搜索 / 语音 / FM / 榜单
// ═══════════════════════════════════════════════════════

class DiscoverHubPage extends StatelessWidget {
  const DiscoverHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        layout.listHorizontal,
        layout.topInset + 6,
        layout.listHorizontal,
        layout.bottomInset + 20,
      ),
      children: [
        _SectionTitle(text: '发现', layout: layout),
        _HubCard(
          icon: Icons.search_rounded,
          title: '搜索',
          subtitle: '输入歌名或歌手',
          accent: cs.primary,
          onTap: () => _push(context, const WatchSearchScreen()),
        ),
        _HubCard(
          icon: Icons.radio_rounded,
          title: '私人 FM',
          subtitle: '个性化推荐',
          accent: cs.tertiary,
          onTap: () => _push(context, const WatchFmScreen()),
        ),
        _HubCard(
          icon: Icons.leaderboard_rounded,
          title: '排行榜',
          subtitle: '热门好歌精选',
          accent: cs.primary,
          onTap: () => _push(context, const WatchRankListScreen()),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  音乐库 — 歌单 / 收藏 / 本地 / 队列
// ═══════════════════════════════════════════════════════

class LibraryHubPage extends StatelessWidget {
  const LibraryHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        layout.listHorizontal,
        layout.topInset + 6,
        layout.listHorizontal,
        layout.bottomInset + 20,
      ),
      children: [
        _SectionTitle(text: '音乐库', layout: layout),
        _HubCard(
          icon: Icons.queue_music_rounded,
          title: '歌单',
          subtitle: '精选歌单',
          accent: cs.primary,
          onTap: () => _push(context, const WatchPlaylistListScreen()),
        ),
        _HubCard(
          icon: Icons.favorite_outline_rounded,
          title: '收藏',
          subtitle: '喜欢的歌曲',
          accent: cs.error,
          onTap: () => _push(context, const WatchLikedSongsScreen()),
        ),
        _HubCard(
          icon: Icons.folder_open_rounded,
          title: '本地音乐',
          subtitle: '手表本地文件',
          accent: cs.secondary,
          onTap: () => _push(context, const WatchLocalMusicScreen()),
        ),
        _HubCard(
          icon: Icons.playlist_play_rounded,
          title: '播放队列',
          subtitle: '当前播放列表',
          accent: cs.tertiary,
          onTap: () => _push(context, const WatchQueueScreen()),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  设备与我 — 账号 / 音质 / 输出 / 关于
// ═══════════════════════════════════════════════════════

class MeHubPage extends StatelessWidget {
  const MeHubPage({super.key});

  static const _qualities = ['128', '320', 'high', 'flac'];
  static String _qualityLabel(String q) => switch (q) {
        '128' => '标准',
        '320' => '高品',
        'high' => '无损',
        'flac' => 'Hi-Res',
        _ => q,
      };

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        layout.listHorizontal,
        layout.topInset + 6,
        layout.listHorizontal,
        layout.bottomInset + 20,
      ),
      children: [
        // 账号卡片
        _AccountCard(layout: layout),
        const SizedBox(height: 8),
        _SectionTitle(text: '设置', layout: layout),
        // 音质
        Consumer<AudioSettingsProvider>(
          builder: (context, settings, _) {
            return _HubCard(
              icon: Icons.graphic_eq_rounded,
              title: 'WiFi 音质',
              subtitle: _qualityLabel(settings.wifiQuality),
              accent: cs.primary,
              onTap: () {
                final idx = _qualities.indexOf(settings.wifiQuality);
                final next = _qualities[(idx + 1) % _qualities.length];
                settings.setWifiQuality(next);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('WiFi 音质：${_qualityLabel(next)}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            );
          },
        ),
        _HubCard(
          icon: Icons.bluetooth_rounded,
          title: '音频输出',
          subtitle: '切换输出设备',
          accent: cs.secondary,
          onTap: () => _push(context, const WatchAudioOutputScreen()),
        ),
        _HubCard(
          icon: Icons.info_outline_rounded,
          title: '关于',
          subtitle: 'NGS-KG+ Watch',
          accent: cs.tertiary,
          onTap: () => _push(context, const WatchSettingsScreen()),
        ),
        if (auth.isLoggedIn)
          RoundListTile(
            title: '退出登录',
            leading: Icon(Icons.logout_rounded, color: cs.error, size: 20),
            onTap: () => auth.logout(),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  共用组件
// ═══════════════════════════════════════════════════════

/// 快捷入口卡片 — 图标 + 标题 + 副标题，M3E 胶囊。
class _HubCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: WatchMotion.durShort2,
        curve: WatchMotion.curveEmphasized,
        child: Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              WatchMotion.tap();
              widget.onTap();
            },
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32 * layout.scale,
                    height: 32 * layout.scale,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 18 * layout.scale,
                      color: widget.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13 * layout.scale,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontSize: 10 * layout.scale,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 分区标题。
class _SectionTitle extends StatelessWidget {
  final String text;
  final WatchLayout layout;

  const _SectionTitle({required this.text, required this.layout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.7),
          fontSize: 12 * layout.scale,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 账号卡片 — 已登录显示头像+昵称，未登录显示登录入口。
class _AccountCard extends StatelessWidget {
  final WatchLayout layout;

  const _AccountCard({required this.layout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (auth.isLoggedIn && user != null) {
      final isVip =
          user.isVipActive || (user.vipType != null && user.vipType! > 0);
      return GestureDetector(
        onTap: () => _push(context, const WatchSettingsScreen()),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person_rounded,
                            size: 22,
                            color: cs.onSurface,
                          ),
                        )
                      : Icon(Icons.person_rounded,
                          size: 22, color: cs.onSurface),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.nickname ?? '用户',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 13 * layout.scale,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isVip)
                      Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded,
                              size: 11, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            'VIP',
                            style: TextStyle(
                              fontSize: 10 * layout.scale,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _HubCard(
      icon: Icons.login_rounded,
      title: '登录账号',
      subtitle: '登录后可使用收藏等功能',
      accent: cs.primary,
      onTap: () => _push(context, const WatchLoginScreen()),
    );
  }
}
