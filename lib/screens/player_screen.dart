// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../utils/responsive.dart';
import '../routes/app_routes.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../models/lyric_settings.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/quality.dart';
import '../utils/palette_extractor.dart';
import '../widgets/player_background.dart';
import '../widgets/player_cover_art.dart';
import '../widgets/player_controls_bar.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/playback_controls.dart' as legacy;
import '../widgets/login_required_dialog.dart';
import '../widgets/lyric_settings_panel.dart';
import '../widgets/desktop_fullscreen_player.dart';

/// Apple Music-style full player screen with dynamic background,
/// cover-art / lyrics PageView, and smooth transitions.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // ─── PageView ───
  final PageController _pageController = PageController();
  final ValueNotifier<double> _pageOffsetNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final player = context.read<PlayerProvider>();
        player.lyricController.setOnTapLineCallback((duration) {
          player.seek(duration);
        });
      }
    });
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final newOffset = _pageController.page?.clamp(0.0, 1.0) ?? 0.0;
    final wasBelowHalf = _pageOffsetNotifier.value < 0.5;
    _pageOffsetNotifier.value = newOffset;
    // 进入歌词页面时同步 controller 到实际播放位置
    if (wasBelowHalf && newOffset >= 0.5 && mounted) {
      final player = context.read<PlayerProvider>();
      player.lyricController.setProgress(player.position);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _pageOffsetNotifier.dispose();
    super.dispose();
  }

  // ─── Speech bubble helper for menu items shows a bottom sheet ──

  Widget _sleepTimerOption(
    BuildContext ctx,
    PlayerProvider player,
    String label,
    Duration duration,
  ) {
    final isSelected = duration == Duration.zero
        ? false
        : (player.sleepTimerRemaining != null &&
            (player.sleepTimerRemaining!.inMinutes - duration.inMinutes).abs() <
                2);
    final isDesktop = Responsive.isDesktopLayout(ctx);

    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isDesktop ? Theme.of(ctx).colorScheme.onSurface : Colors.white,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check,
              color: isDesktop
                  ? Theme.of(ctx).colorScheme.primary
                  : Colors.blueAccent)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        if (duration == Duration.zero) {
          player.cancelSleepTimer();
        } else {
          player.setSleepTimer(duration);
        }
      },
    );
  }

  void _showSleepTimerSheet() {
    final isDesktop = Responsive.isDesktopLayout(context);
    final content = _buildSleepTimerContent();
    if (isDesktop) {
      showM3Dialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('定时关闭'),
          content: SizedBox(width: 300, child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    } else {
      showM3ModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => content,
      );
    }
  }

  Widget _buildSleepTimerContent() {
    final isDesktop = Responsive.isDesktopLayout(context);
    final player = context.read<PlayerProvider>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDesktop)
                const Text('定时关闭',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              if (!isDesktop) const SizedBox(height: 16),
              _sleepTimerOption(
                  context, player, '15 分钟', const Duration(minutes: 15)),
              _sleepTimerOption(
                  context, player, '30 分钟', const Duration(minutes: 30)),
              _sleepTimerOption(
                  context, player, '45 分钟', const Duration(minutes: 45)),
              _sleepTimerOption(
                  context, player, '60 分钟', const Duration(minutes: 60)),
              if (player.sleepTimerRemaining != null)
                _sleepTimerOption(context, player, '关闭定时', Duration.zero),
            ],
          ),
        ),
      ),
    );
  }

  void _showLyricSettingsSheet() {
    final isDesktop = Responsive.isDesktopLayout(context);
    if (isDesktop) {
      showM3Dialog(
        context: context,
        builder: (ctx) => const AlertDialog(
          content: SizedBox(width: 360, child: LyricSettingsPanel()),
        ),
      );
    } else {
      showM3ModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => const SafeArea(
          child: LyricSettingsPanel(),
        ),
      );
    }
  }

  void _showArtistSelectionSheet(PlayerProvider player, Song song) {
    // KRM 数据已在 Provider 层通过 hash 校验，可直接信任
    final krmAuthors = player.currentSongAuthors;
    final hasKrm = krmAuthors.isNotEmpty;

    // 兜底方案：使用分割出来的歌名歌手列表
    final List<Map<String, dynamic>> displayAuthors = hasKrm
        ? krmAuthors
        : song.artists
            .map((name) => {
                  'name': name,
                  'id': song.artists.indexOf(name) == 0 ? song.artistId : null,
                })
            .toList();

    final isDesktop = Responsive.isDesktopLayout(context);
    final content = Builder(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDesktop)
                    const Text('选择歌手',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  if (!isDesktop) const SizedBox(height: 12),
                  ...displayAuthors.map((author) {
                    final artistName = author['name'] as String;
                    final artistId = author['id'] as int?;
                    final hasDetailId = artistId != null && artistId > 0;
                    return ListTile(
                      leading: Icon(Icons.person,
                          color:
                              isDesktop ? cs.onSurfaceVariant : Colors.white70,
                          size: 20),
                      title: Text(artistName,
                          style: TextStyle(
                              color: isDesktop ? cs.onSurface : Colors.white)),
                      trailing: Icon(Icons.chevron_right,
                          color:
                              isDesktop ? cs.onSurfaceVariant : Colors.white38,
                          size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (hasDetailId) {
                          Navigator.pushNamed(context, AppRoutes.artistDetail,
                              arguments: {
                                'id': artistId,
                                'name': artistName,
                              });
                        } else {
                          // 搜索降级
                          Navigator.pushNamed(context, AppRoutes.search,
                              arguments: artistName);
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (isDesktop) {
      showM3Dialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('选择歌手'),
          content: SizedBox(width: 320, child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    } else {
      showM3ModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => content,
      );
    }
  }

  void _showMoreSheet() {
    const spds = [1.0, 0.5, 0.75, 1.25, 1.5, 2.0];
    final isDesktop = Responsive.isDesktopLayout(context);
    final content = Consumer<PlayerProvider>(
      builder: (context, p, _) {
        final cs = Theme.of(context).colorScheme;
        final song = p.currentSong;
        // 优先使用从 /krm/audio 获取的真实专辑 ID
        final albumId = p.currentSongAlbumId;
        final albumName = song?.albumName ?? '';
        // 查看专辑显示条件：有 albumId，或者有 albumName 且不等于 'Unknown' / '无'
        final hasAlbum = song != null &&
            (albumId > 0 ||
                (albumName.isNotEmpty &&
                    albumName != 'Unknown' &&
                    albumName != '无'));

        // 歌手呈现：KRM 数据已在 Provider 层通过 hash 校验，可直接信任
        final krmAuthors = p.currentSongAuthors;
        final hasKrm = krmAuthors.isNotEmpty;
        final displayArtistsList = hasKrm
            ? krmAuthors.map((e) => e['name'] as String).toList()
            : (song?.artists ?? []);
        final hasArtists = song != null && displayArtistsList.isNotEmpty;
        final artistsDisplayString = hasKrm
            ? displayArtistsList.join(' / ')
            : (song?.artistDisplay ?? '');

        final Color textColor = isDesktop ? cs.onSurface : Colors.white;
        final Color secondaryColor =
            isDesktop ? cs.onSurfaceVariant : Colors.white70;
        final Color hintColor =
            isDesktop ? cs.onSurfaceVariant : Colors.white38;
        final Color chipBg =
            (isDesktop ? cs.onSurface : Colors.white).withValues(alpha: 0.1);
        final Color chipBorderSelected =
            (isDesktop ? cs.onSurface : Colors.white).withValues(alpha: 0.3);
        final Color chipBorderNormal =
            (isDesktop ? cs.onSurface : Colors.white).withValues(alpha: 0.1);
        final Color chipBgSelected =
            (isDesktop ? cs.onSurface : Colors.white).withValues(alpha: 0.15);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 倍速控制（改为独立上下两行排版，防文本被压缩）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.fast_forward,
                              color: secondaryColor, size: 20),
                          const SizedBox(width: 12),
                          Text('播放倍速',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  )),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: AppShape.xs,
                        ),
                        child: Text('${p.currentSpeed.toStringAsFixed(2)}x',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: secondaryColor,
                                  fontWeight: FontWeight.bold,
                                )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: spds.map((s) {
                        final isSelected = s == p.currentSpeed;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: AppShape.sm,
                            onTap: () => p.setSpeed(s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? chipBgSelected : chipBg,
                                border: Border.all(
                                  color: isSelected
                                      ? chipBorderSelected
                                      : chipBorderNormal,
                                  width: 1,
                                ),
                                borderRadius: AppShape.sm,
                              ),
                              child: Text('${s}x',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color:
                                            isSelected ? textColor : hintColor,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                color: isDesktop
                    ? cs.outlineVariant.withValues(alpha: 0.3)
                    : Colors.white12,
                height: 16),
            // 查看专辑
            if (hasAlbum)
              ListTile(
                leading: Icon(Icons.album, color: secondaryColor, size: 20),
                title: Text('查看专辑', style: TextStyle(color: textColor)),
                trailing: Icon(Icons.chevron_right, color: hintColor, size: 20),
                onTap: () {
                  Navigator.pop(context);
                  if (albumId > 0) {
                    Navigator.pushNamed(context, AppRoutes.albumDetail,
                        arguments: {
                          'id': albumId,
                          'name': albumName,
                        });
                  } else {
                    // 搜索降级
                    Navigator.pushNamed(context, AppRoutes.search,
                        arguments: albumName);
                  }
                },
              ),
            // 查看歌手
            if (hasArtists)
              ListTile(
                leading: Icon(Icons.person, color: secondaryColor, size: 20),
                title: Text(displayArtistsList.length > 1
                    ? '查看歌手 (共 ${displayArtistsList.length} 位)'
                    : '查看歌手'),
                subtitle: Text(artistsDisplayString,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: hintColor)),
                trailing: Icon(Icons.chevron_right, color: hintColor, size: 20),
                onTap: () {
                  Navigator.pop(context);
                  if (displayArtistsList.length > 1) {
                    // 弹窗让用户挑选歌手
                    _showArtistSelectionSheet(p, song);
                  } else {
                    // 单歌手逻辑
                    final artistName = displayArtistsList.first;
                    final artistId =
                        hasKrm ? krmAuthors.first['id'] as int? : song.artistId;
                    if (artistId != null && artistId > 0) {
                      Navigator.pushNamed(context, AppRoutes.artistDetail,
                          arguments: {
                            'id': artistId,
                            'name': artistName,
                          });
                    } else {
                      // 搜索降级
                      Navigator.pushNamed(context, AppRoutes.search,
                          arguments: artistName);
                    }
                  }
                },
              ),
            if (hasAlbum || hasArtists)
              Divider(
                  color: isDesktop
                      ? cs.outlineVariant.withValues(alpha: 0.3)
                      : Colors.white12,
                  height: 1),
            // 定时关闭
            ListTile(
              leading:
                  Icon(Icons.timer_outlined, color: secondaryColor, size: 20),
              title: Text('定时关闭', style: TextStyle(color: textColor)),
              trailing: Icon(Icons.chevron_right, color: hintColor, size: 20),
              onTap: () {
                Navigator.pop(context);
                _showSleepTimerSheet();
              },
            ),
            Divider(
                color: isDesktop
                    ? cs.outlineVariant.withValues(alpha: 0.3)
                    : Colors.white12,
                height: 1),
            // 编码音质
            ListTile(
              leading: Icon(Icons.speed, color: secondaryColor, size: 20),
              title: Text('编码音质', style: TextStyle(color: textColor)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.currentQualityLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: hintColor)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: hintColor, size: 20),
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                _showQualitySheet();
              },
            ),
            Divider(
                color: isDesktop
                    ? cs.outlineVariant.withValues(alpha: 0.3)
                    : Colors.white12,
                height: 1),
            // 音效
            ListTile(
              leading:
                  Icon(Icons.spatial_audio, color: secondaryColor, size: 20),
              title: Text('音效', style: TextStyle(color: textColor)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.effectLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: hintColor)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: hintColor, size: 20),
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                _showEffectSheet();
              },
            ),
          ],
        );
      },
    );

    if (isDesktop) {
      showM3Dialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('更多'),
          content: SizedBox(width: 360, child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    } else {
      showM3ModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(child: content),
          ),
        ),
      );
    }
  }

  void _showEffectSheet() {
    final isDesktop = Responsive.isDesktopLayout(context);
    final content = Builder(
      builder: (ctx) {
        final p = context.read<PlayerProvider>();
        final cs = Theme.of(ctx).colorScheme;
        final currentEffect = p.effectKey;
        final textColor = isDesktop ? cs.onSurface : Colors.white;
        final secondaryColor = isDesktop ? cs.onSurfaceVariant : Colors.white70;
        final hintColor = isDesktop ? cs.onSurfaceVariant : Colors.white38;
        final disabledColor = isDesktop
            ? cs.onSurfaceVariant.withValues(alpha: 0.3)
            : Colors.white24;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDesktop)
                    const Text('音效',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  if (!isDesktop) const SizedBox(height: 12),
                  // "关闭"选项始终可用
                  ListTile(
                    leading: Icon(
                      currentEffect == 'none'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: currentEffect == 'none'
                          ? (isDesktop ? cs.primary : Colors.white)
                          : hintColor,
                      size: 20,
                    ),
                    title: Text('关闭', style: TextStyle(color: textColor)),
                    subtitle: Text('不使用音效',
                        style: Theme.of(ctx)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: hintColor)),
                    onTap: () {
                      p.setEffect('none');
                      Navigator.pop(ctx);
                    },
                  ),
                  ...Quality.effects.map((key) {
                    final isSelected = key == currentEffect;
                    final isAvailable = p.isEffectAvailable(key);
                    final label = Quality.effectLabel(key);
                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? (isDesktop ? cs.primary : Colors.white)
                            : (isAvailable ? hintColor : disabledColor),
                        size: 20,
                      ),
                      title: Text(label,
                          style: TextStyle(
                            color: isSelected
                                ? textColor
                                : (isAvailable
                                    ? secondaryColor
                                    : disabledColor),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                      subtitle: !isAvailable
                          ? Text('当前歌曲不支持',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: disabledColor))
                          : null,
                      enabled: isAvailable,
                      onTap: isAvailable
                          ? () {
                              p.setEffect(key);
                              Navigator.pop(ctx);
                            }
                          : null,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (isDesktop) {
      showM3Dialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('音效'),
          content: SizedBox(width: 320, child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    } else {
      showM3ModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => content,
      );
    }
  }

  void _showQualitySheet() {
    final player = context.read<PlayerProvider>();
    final selectedKey =
        Quality.levels[player.qualityLevel % Quality.levels.length];
    final availableQualities = player.getAvailableQualities();
    final isDesktop = Responsive.isDesktopLayout(context);

    final content = Builder(
      builder: (ctx) {
        final p = context.read<PlayerProvider>();
        final cs = Theme.of(ctx).colorScheme;
        final textColor = isDesktop ? cs.onSurface : Colors.white;
        final secondaryColor = isDesktop ? cs.onSurfaceVariant : Colors.white70;
        final hintColor = isDesktop ? cs.onSurfaceVariant : Colors.white38;
        final disabledColor = isDesktop
            ? cs.onSurfaceVariant.withValues(alpha: 0.3)
            : Colors.white24;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDesktop)
                    const Text('音质选择',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  if (!isDesktop) const SizedBox(height: 12),
                  ...Quality.levels.map((key) {
                    final label = Quality.label(key);
                    final isSelected = key == selectedKey;
                    final isAvailable = p.isQualityAvailable(key);
                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? (isDesktop ? cs.primary : Colors.white)
                            : (isAvailable ? hintColor : disabledColor),
                        size: 20,
                      ),
                      title: Text(label,
                          style: TextStyle(
                            color: isSelected
                                ? textColor
                                : (isAvailable
                                    ? secondaryColor
                                    : disabledColor),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                      subtitle: Row(
                        children: [
                          Text(
                            _qualitySubtitle(key),
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: isAvailable ? hintColor : disabledColor),
                          ),
                          if (!isAvailable) ...[
                            const SizedBox(width: 8),
                            Text('当前歌曲不支持',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: disabledColor)),
                          ],
                          if (isAvailable &&
                              !availableQualities.contains(key)) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: (isDesktop ? cs.onSurface : Colors.white)
                                    .withValues(alpha: 0.1),
                                borderRadius: AppShape.xs,
                              ),
                              child: Text('降级可用',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: disabledColor)),
                            ),
                          ],
                        ],
                      ),
                      enabled: isAvailable,
                      onTap: isAvailable
                          ? () {
                              p.setQuality(key);
                              Navigator.pop(ctx);
                            }
                          : null,
                    );
                  }),
                  if (availableQualities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '当前歌曲最高支持: ${Quality.label(availableQualities.last)}',
                        style: Theme.of(ctx)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: disabledColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    if (isDesktop) {
      showM3Dialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('音质选择'),
          content: SizedBox(width: 320, child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    } else {
      showM3ModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => content,
      );
    }
  }

  String _qualitySubtitle(String key) {
    switch (key) {
      case '128':
        return '128kbps';
      case '320':
        return '320kbps';
      case 'high':
      case 'flac':
        return 'FLAC';
      default:
        return '';
    }
  }

  // 歌词页独立成组件（只订阅歌词相关状态），避免播放进度变化时重建 LyricView。
  Widget _buildLyricsPage(PlayerProvider player, Song song, bool isDesktop) {
    return _LyricsPage(
      song: song,
      isDesktop: isDesktop,
      onLyricSettingsTap: _showLyricSettingsSheet,
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktopLayout(context);

    if (isDesktop) {
      return DesktopFullscreenPlayer(
        onClose: () => Navigator.pop(context),
      );
    }

    // 只订阅切歌/音质解析/调色板等低频状态；播放进度由 _PlayerProgressBar
    // 等子组件独立订阅，避免每 200ms 的 position 通知重建整页（LyricView 最贵）。
    return Selector<
        PlayerProvider,
        ({
          Song? song,
          String qualityLabel,
          Color? backgroundColor,
          ExtractedPalette? palette,
        })>(
      selector: (_, p) => (
        song: p.currentSong,
        qualityLabel: p.resolvedQualityLabel,
        backgroundColor: p.backgroundColor,
        palette: p.palette,
      ),
      builder: (ctx, sel, _) {
        final player = ctx.read<PlayerProvider>();
        final song = sel.song;
        if (song == null) {
          return Scaffold(
            backgroundColor: isDesktop
                ? Theme.of(context).colorScheme.surface
                : Colors.black,
            body: Center(
              child: Text(
                '暂无播放',
                style: TextStyle(
                  color: isDesktop
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Colors.white70,
                ),
              ),
            ),
          );
        }

        // ── Slide-down gesture state ──
        double dragOffset = 0;
        const double dismissThreshold = 150;

        // 背景调色板随 palette 引用变化时重算；同一引用下由 Provider 缓存，
        // 不会造成 Selector 频繁重建。
        final paletteColors = player.paletteColors;

        Widget content = GestureDetector(
          onVerticalDragUpdate: isDesktop
              ? null
              : (details) {
                  dragOffset += details.delta.dy;
                  if (dragOffset > dismissThreshold && mounted) {
                    Navigator.pop(context);
                  }
                },
          onVerticalDragEnd: isDesktop
              ? null
              : (details) {
                  dragOffset = 0;
                  if ((details.primaryVelocity ?? 0) > 800 && mounted) {
                    Navigator.pop(context);
                  }
                },
          child: Stack(
            children: [
              // ── Dynamic background ──
              // 滚动偏移经 ValueListenableBuilder 局部驱动，滚动时只重建背景层，
              // 不触碰歌词/封面子树。
              if (!isDesktop)
                ValueListenableBuilder<double>(
                  valueListenable: _pageOffsetNotifier,
                  builder: (context, offset, _) => PlayerBackground(
                    albumCoverUrl: song.albumCoverUrl,
                    paletteColor: sel.backgroundColor,
                    paletteColors: paletteColors,
                    scrollOffset: offset,
                  ),
                ),

              // ── Content ──
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Page header (shared, pinned at top) ──
                    _buildPageHeader(player, song, isDesktop),
                    Expanded(
                      child: isDesktop
                          // 桌面端: Music You 两栏布局 (左封面+控制, 右歌词)
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildCoverPage(player, song, true),
                                ),
                                Expanded(
                                  child: _buildLyricsPage(player, song, true),
                                ),
                              ],
                            )
                          : PageView(
                              controller: _pageController,
                              children: [
                                // Page 0: Cover + controls
                                _buildCoverPage(player, song, false),
                                // Page 1: Immersive lyrics
                                _buildLyricsPage(player, song, false),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (isDesktop) {
          content = Responsive.constrainedContent(
            context,
            maxWidth: Responsive.maxWidthContent,
            child: content,
          );
        }

        return Scaffold(
          backgroundColor:
              isDesktop ? Theme.of(context).colorScheme.surface : Colors.black,
          body: content,
        );
      },
    );
  }

  // ── Top bar ──

  // ── Page header (shared, pinned at top) ──

  Widget _buildPageHeader(PlayerProvider player, Song song, bool isDesktop) {
    final cs = Theme.of(context).colorScheme;
    final krmAuthors = player.currentSongAuthors;
    final hasKrm = krmAuthors.isNotEmpty;
    final displayArtistsList = hasKrm
        ? krmAuthors.map((e) => e['name'] as String).toList()
        : song.artists;
    final artistsDisplayString =
        hasKrm ? displayArtistsList.join(' / ') : song.artistDisplay;

    final primaryColor = isDesktop ? cs.onSurface : Colors.white;
    final secondaryColor = isDesktop ? cs.onSurfaceVariant : Colors.white60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // 左侧返回按钮 (手势向下滑动返回的视觉映射)
          if (!isDesktop)
            M3PressScale(
              child: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                color: primaryColor,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            )
          else
            const SizedBox(width: 48),

          // 中间歌名/歌手 (沉浸式居中)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    if (displayArtistsList.length > 1) {
                      _showArtistSelectionSheet(player, song);
                    } else if (displayArtistsList.isNotEmpty) {
                      final artistName = displayArtistsList.first;
                      final artistId = hasKrm
                          ? krmAuthors.first['id'] as int?
                          : song.artistId;
                      if (artistId != null && artistId > 0) {
                        Navigator.pushNamed(context, AppRoutes.artistDetail,
                            arguments: {
                              'id': artistId,
                              'name': artistName,
                            });
                      } else {
                        Navigator.pushNamed(context, AppRoutes.search,
                            arguments: artistName);
                      }
                    }
                  },
                  child: Text(
                    artistsDisplayString,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 右侧更多操作 (对称平衡)
          M3PressScale(
            child: IconButton(
              icon: const Icon(Icons.more_horiz_rounded, size: 24),
              color: primaryColor,
              onPressed: _showMoreSheet,
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 0: cover page ──

  Widget _buildCoverPage(PlayerProvider player, Song song, bool isDesktop) {
    final cs = Theme.of(context).colorScheme;
    // 音质标签：已由顶层 Selector 订阅 resolvedQualityLabel（含 privilege 预查结果）
    final qualityLabel = player.resolvedQualityLabel;
    const speeds = [1.0, 0.5, 0.75, 1.25, 1.5, 2.0];

    return Column(
      children: [
        // Album cover — flex takes remaining space above bottom controls
        Expanded(
          child: Center(
            child: PlayerCoverArt(
              song: song,
              scrollOffset: _pageOffsetNotifier,
            ),
          ),
        ),

        // Quality text
        Text(
          qualityLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isDesktop ? cs.onSurfaceVariant : Colors.white60,
                letterSpacing: 1.2,
              ),
        ),

        const SizedBox(height: 12),

        // Progress bar（独立订阅 position/duration/progress，避免整页重建）
        _PlayerProgressBar(pageOffset: isDesktop ? null : _pageOffsetNotifier),

        const SizedBox(height: 12),

        // Three controls:???（独立订阅 isPlaying/isLoading）
        const _PlayerControls(),

        const SizedBox(height: 8),

        // Five icon bottom bar
        _buildIconBar(player, song, speeds, isDesktop),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
      ],
    );
  }

  // ── Five-icon bottom bar ──

  Widget _buildIconBar(
      PlayerProvider player, Song song, List<double> speeds, bool isDesktop) {
    final defaultColor = isDesktop
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Colors.white60;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // ↺ Play mode — 独立订阅 playMode，播放进度通知不重建图标栏
        Selector<PlayerProvider, PlayMode>(
          selector: (_, p) => p.playMode,
          builder: (context, mode, _) => _IconBarItem(
            icon: _modeIcon(mode),
            iconColor: defaultColor,
            onTap: () {
              const modes = [
                PlayMode.sequential,
                PlayMode.shuffle,
                PlayMode.repeatOne,
              ];
              final next = modes[(modes.indexOf(mode) + 1) % modes.length];
              player.setPlayMode(next);
            },
          ),
        ),

        // ♡ Song info / Favorite
        Consumer<LikedSongsProvider>(
          builder: (_, lp, __) {
            final liked = lp.likedIds.contains(song.id);
            return _IconBarItem(
              icon: liked ? Icons.favorite : Icons.favorite_border,
              iconColor: liked ? Colors.redAccent : defaultColor,
              onTap: () async {
                final auth = context.read<AuthProvider>();
                if (!auth.isLoggedIn) {
                  final goLogin = await showLoginRequiredDialog(context);
                  if (goLogin && mounted) {
                    Navigator.pushNamed(context, AppRoutes.login);
                  }
                  return;
                }
                lp.toggle(SongInfo(
                  id: song.id,
                  name: song.name,
                  hash: song.hash ?? '',
                  albumId: song.albumId,
                  audioId: song.id,
                ));
              },
            );
          },
        ),

        // ⎔ Audio effects
        _IconBarItem(
          icon: Icons.tune_rounded,
          iconColor: defaultColor,
          onTap: () => Navigator.pushNamed(context, AppRoutes.audioEffects),
        ),

        // ☰ Playlist queue
        _IconBarItem(
          icon: Icons.playlist_play,
          iconColor: defaultColor,
          onTap: () =>
              legacy.PlaybackControls.showPlaylistStatic(context, player),
        ),

        // ⋮ More — opens bottom sheet
        _IconBarItem(
          icon: Icons.more_horiz,
          iconColor: defaultColor,
          onTap: _showMoreSheet,
        ),
      ],
    );
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequential:
        return Icons.repeat;
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.repeatOne:
        return Icons.repeat_one;
      case PlayMode.radio:
        return Icons.radio;
    }
  }
}

/// 歌词页：独立订阅歌词相关状态（加载中/语言/翻译/多语言），
/// 播放进度变化（PlayerProvider 每 200ms notifyListeners）时不会重建
/// LyricView——LyricView 重建需要重新布局全部歌词行，代价极高。
class _LyricsPage extends StatelessWidget {
  final Song song;
  final bool isDesktop;
  final VoidCallback onLyricSettingsTap;

  const _LyricsPage({
    required this.song,
    required this.isDesktop,
    required this.onLyricSettingsTap,
  });

  LyricStyle _buildLyricStyle(BuildContext context, LyricSettings ls) {
    final cs = Theme.of(context).colorScheme;
    // 焦点行字重 = 用户设置 + 200（确保比普通行重）
    final int activeWeightIdx = ((ls.fontWeight / 100).round() + 2).clamp(3, 8);
    final activeWeight = FontWeight.values[activeWeightIdx];
    final textColor = isDesktop ? cs.onSurfaceVariant : const Color(0xFFB0A8C0);
    final activeColor = isDesktop ? cs.onSurface : Colors.white;
    final translationColor = isDesktop
        ? cs.onSurfaceVariant.withValues(alpha: 0.7)
        : const Color(0xFF8A7FA0);
    final selectedColor = isDesktop
        ? cs.onSurfaceVariant.withValues(alpha: 0.8)
        : const Color(0xFF8A7FA0);
    return LyricStyle(
      textStyle: TextStyle(
        fontSize: ls.fontSize,
        fontWeight: ls.resolvedWeight,
        height: 1.6,
        color: textColor,
      ),
      // 焦点行同字号杜绝折行，但加粗 + 白色 + 字间距确保视觉突出
      activeStyle: TextStyle(
        fontSize: ls.fontSize,
        fontWeight: activeWeight,
        height: 1.4,
        color: activeColor,
        letterSpacing: 0.5,
      ),
      // 翻译/罗马音用字号区分，不用粗细
      translationStyle: TextStyle(
        fontSize: ls.translationFontSize,
        fontWeight: ls.resolvedWeight,
        height: 1.3,
        color: translationColor,
      ),
      translationActiveColor: isDesktop ? cs.onSurface : Colors.white70,
      lineGap: 24,
      translationLineGap: 4,
      lineTextAlign: ls.centerAlign ? TextAlign.center : TextAlign.left,
      contentAlignment:
          ls.centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      contentPadding: const EdgeInsets.symmetric(horizontal: 28),
      selectionAnchorPosition: 0.5,
      selectionAlignment: MainAxisAlignment.center,
      // 焦点行锚点稍偏上(0.4)，补偿标题栏上移后视觉中心偏移
      activeAnchorPosition: 0.4,
      activeAlignment: MainAxisAlignment.center,
      activeHighlightColor: isDesktop ? cs.primary : Colors.white,
      activeHighlightExtraFadeWidth: 14,
      selectedColor: selectedColor,
      selectedTranslationColor: selectedColor,
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

      // 上下渐隐范围：仅 blurEffect 开启时生效
      fadeRange: ls.blurEffect ? FadeRange(top: 0.15, bottom: 0.15) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    // 歌词设置在 Selector 外订阅（Selector builder 内禁止 watch/select）
    final ls = context.watch<ThemeProvider>().lyricSettings;
    return Selector<
        PlayerProvider,
        ({
          bool lyricLoading,
          int selectedLyricLang,
          bool showTranslation,
          bool hasLangData,
        })>(
      selector: (_, p) => (
        lyricLoading: p.lyricLoading,
        selectedLyricLang: p.selectedLyricLang,
        showTranslation: p.showTranslation,
        hasLangData: p.hasLangData,
      ),
      builder: (context, state, _) {
        final cs = Theme.of(context).colorScheme;
        final model = player.lyricController.lyricNotifier.value;
        final hasLyrics = model != null && model.lines.isNotEmpty;

        Widget lyricsContent;
        if (state.lyricLoading) {
          lyricsContent = Center(
            child: CircularProgressIndicator(
                color: isDesktop ? cs.onSurfaceVariant : Colors.white70),
          );
        } else if (!hasLyrics) {
          lyricsContent = Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lyrics_outlined,
                    size: 48,
                    color: isDesktop ? cs.onSurfaceVariant : Colors.white54),
                const SizedBox(height: 16),
                Text('暂无歌词',
                    style: TextStyle(
                      color: isDesktop ? cs.onSurfaceVariant : Colors.white54,
                      fontSize: 16,
                    )),
              ],
            ),
          );
        } else {
          lyricsContent = LyricView(
            key: ValueKey(
                'lyrics_${state.selectedLyricLang}_${song.hash ?? song.id}'),
            controller: player.lyricController,
            style: _buildLyricStyle(context, ls),
          );
        }

        // 歌词内容（无黑色背景遮罩）
        Widget lyricsWidget = Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: lyricsContent,
        );

        // blurEffect 开启时：用 ShaderMask 给文字做上下边缘渐隐
        if (ls.blurEffect) {
          final fadeColor = isDesktop ? cs.surface : Colors.black;
          lyricsWidget = ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  fadeColor,
                  fadeColor,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.12, 0.88, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: lyricsWidget,
          );
        }

        return Column(
          children: [
            const SizedBox(height: 4),

            // Lyrics area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: AppShape.md,
                  child: lyricsWidget,
                ),
              ),
            ),

            // Footer: source badge + language toggle
            _buildLyricsFooter(
                context, state.showTranslation, state.hasLangData),
          ],
        );
      },
    );
  }

  Widget _buildLyricsFooter(
      BuildContext context, bool showTranslation, bool hasLangData) {
    final player = context.read<PlayerProvider>();
    final cs = Theme.of(context).colorScheme;
    final bool isLocal = song.isLocal;
    String source = isLocal ? 'LOCAL' : 'KUGOU';
    final badgeColor =
        (isDesktop ? cs.onSurface : Colors.white).withValues(alpha: 0.10);
    final primaryTextColor = isDesktop ? cs.onSurfaceVariant : Colors.white54;
    final secondaryTextColor = isDesktop ? cs.onSurfaceVariant : Colors.white38;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          // [词] source badge (点击打开歌词设置)
          GestureDetector(
            onTap: onLyricSettingsTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: AppShape.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('词',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                          height: 1.2)),
                  const SizedBox(width: 4),
                  Text(source,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: secondaryTextColor, height: 1.2)),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Language toggle (only when KRC has lang data)
          if (hasLangData)
            GestureDetector(
              onTap: () {
                player.toggleTranslation();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: AppShape.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showTranslation ? '翻译' : '歌词',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: primaryTextColor,
                          ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      showTranslation ? Icons.visibility : Icons.visibility_off,
                      size: 10,
                      color: secondaryTextColor,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Icon + label item used in the bottom icon bar.
class _IconBarItem extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _IconBarItem({
    required this.icon,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppShape.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Icon(icon, size: 22, color: iconColor ?? Colors.white60),
      ),
    );
  }
}

/// 独立订阅播放进度，避免进度变化时重建整个 PlayerScreen。
class _PlayerProgressBar extends StatefulWidget {
  /// 页面滚动偏移（0=封面, 1=歌词），仅用于拖动进度时同步歌词；
  /// 桌面端为 null（恒按歌词页处理）。用 ValueListenable 传递，
  /// 使进度条不随滚动重建。
  final ValueListenable<double>? pageOffset;

  const _PlayerProgressBar({this.pageOffset});

  @override
  State<_PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<_PlayerProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider,
        ({Duration position, Duration duration, double progress})>(
      selector: (_, p) {
        final durationMs = p.duration.inMilliseconds;
        return (
          position: p.position,
          duration: p.duration,
          progress: durationMs > 0 && p.progress.isFinite
              ? p.progress.clamp(0.0, 1.0)
              : 0.0,
        );
      },
      builder: (context, state, _) {
        final player = context.read<PlayerProvider>();
        return PlayerProgressBar(
          position: _isDragging
              ? Duration(
                  milliseconds:
                      (_dragValue * state.duration.inMilliseconds).round(),
                )
              : state.position,
          duration: state.duration,
          progress: _isDragging ? _dragValue : state.progress,
          onDragStart: () {
            setState(() => _isDragging = true);
          },
          onDragEnd: () async {
            await player.seek(Duration(
              milliseconds:
                  (_dragValue * state.duration.inMilliseconds).round(),
            ));
            if (mounted) {
              setState(() => _isDragging = false);
            }
          },
          onSeek: (v) {
            setState(() => _dragValue = v);
            // 歌词页可见（或桌面端）时拖动进度同步歌词位置
            if ((widget.pageOffset?.value ?? 1.0) >= 0.5) {
              player.lyricController.setProgress(Duration(
                milliseconds: (v * state.duration.inMilliseconds).round(),
              ));
            }
          },
        );
      },
    );
  }
}

/// 独立订阅播放/加载状态，避免进度变化时重建整个 PlayerScreen。
class _PlayerControls extends StatelessWidget {
  const _PlayerControls();

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, ({bool isPlaying, bool isLoading})>(
      selector: (_, p) => (isPlaying: p.isPlaying, isLoading: p.isLoading),
      builder: (context, state, _) {
        final player = context.read<PlayerProvider>();
        return PlayerControlsBar(
          isPlaying: state.isPlaying,
          isLoading: state.isLoading,
          isDesktop: Responsive.isDesktopLayout(context),
          onPlayPause: player.togglePlayPause,
          onPrevious: player.playPrevious,
          onNext: player.playNext,
        );
      },
    );
  }
}
