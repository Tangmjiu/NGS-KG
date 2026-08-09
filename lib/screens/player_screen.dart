// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../models/lyric_settings.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/quality.dart';
import '../widgets/player_background.dart';
import '../widgets/player_cover_art.dart';
import '../widgets/player_controls_bar.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/playback_controls.dart' as legacy;
import '../widgets/login_required_dialog.dart';
import '../widgets/lyric_settings_panel.dart';
import '../utils/app_icons.dart';
import '../utils/haptics.dart';
import '../utils/responsive.dart';

/// Apple Music-style full player screen with dynamic background,
/// cover-art / lyrics PageView, and smooth transitions.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  // ─── 下滑拖拽动画控制器（字段持有，避免回调中反复 new 触发 Ticker 冲突） ───
  AnimationController? _dragResetController;
  AnimationController? _dismissController;

  // ─── 构建 LyricView 样式（从设置动态读取） ───
  // ✅ 新增适配代码：compact=true 时用于双栏/沉浸布局（缩小字号、行距与左右留白）
  // 缓存最近一次构建结果，避免每次 build 都创建新 LyricStyle 实例导致 LyricView 重建
  LyricStyle? _cachedLyricStyle;
  LyricSettings? _cachedLyricSettings;
  bool _cachedLyricCompact = false;

  LyricStyle _buildLyricStyle({bool compact = false}) {
    final ls = context.read<ThemeProvider>().lyricSettings;
    if (_cachedLyricStyle != null &&
        identical(_cachedLyricSettings, ls) &&
        _cachedLyricCompact == compact) {
      return _cachedLyricStyle!;
    }
    // 焦点行字重 = 用户设置 + 200（确保比普通行重）
    final int activeWeightIdx = ((ls.fontWeight / 100).round() + 2).clamp(3, 8);
    final activeWeight = FontWeight.values[activeWeightIdx];
    final double fontSize = compact
        ? (ls.fontSize - 4).clamp(12.0, 30.0)
        : ls.fontSize;
    final double translationFontSize = compact
        ? (ls.translationFontSize - 2).clamp(10.0, 26.0)
        : ls.translationFontSize;
    final style = LyricStyle(
      textStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: ls.resolvedWeight,
        height: 1.6,
        color: const Color(0xFFB0A8C0), // 灰紫
      ),
      // 焦点行同字号杜绝折行，但加粗 + 白色 + 字间距确保视觉突出
      activeStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: activeWeight,
        height: 1.4,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
      // ── 渐变扫光高亮（对标 Rhythm WordByWordLyricsView 的 Brush 扫光）──
      // 高亮行从左到右：纯白 → 半透明白 → 透明尾迹，
      // 配合 extraFadeWidth 形成"被点亮"的扫光质感；同步高亮机制不变。
      activeHighlightGradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white,
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.72, 1.0],
      ),
      activeHighlightExtraFadeWidth: 24,
      // 翻译/罗马音用字号区分，不用粗细
      translationStyle: TextStyle(
        fontSize: translationFontSize,
        fontWeight: ls.resolvedWeight,
        height: 1.3,
        color: const Color(0xFF8A7FA0), // 淡紫
      ),
      translationActiveColor: Colors.white70,
      lineGap: compact ? 18 : 24,
      translationLineGap: 4,
      lineTextAlign: ls.centerAlign ? TextAlign.center : TextAlign.left,
      contentAlignment: ls.centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      contentPadding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28),
      selectionAnchorPosition: 0.5,
      selectionAlignment: MainAxisAlignment.center,
      // 焦点行锚点稍偏上(0.4)，补偿标题栏上移后视觉中心偏移
      activeAnchorPosition: 0.4,
      activeAlignment: MainAxisAlignment.center,
      selectedColor: const Color(0xFF8A7FA0),
      selectedTranslationColor: const Color(0xFF8A7FA0),
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
      fadeRange: ls.blurEffect
          ? FadeRange(top: 0.15, bottom: 0.15)
          : null,
    );
    _cachedLyricSettings = ls;
    _cachedLyricCompact = compact;
    _cachedLyricStyle = style;
    return style;
  }

  // ─── PageView ───
  final PageController _pageController = PageController();
  double _pageOffset = 0.0; // 0 = cover, 1 = lyrics

  // ✅ 新增适配代码：沉浸模式状态（Salt Player 风格，仅平板，长按播放/暂停键切换）
  bool _immersive = false;

  void _toggleImmersive() {
    if (!mounted) return;
    setState(() => _immersive = !_immersive);
    unawaited(haptic(HapticKind.medium));
  }

  // ✅ 新增适配代码：平板双指手势状态（Listener 原始指针跟踪，绕过手势竞技场）
  // 双指水平滑=切歌（左滑下一首/右滑上一首），双指垂直滑=音量（上滑增大/下滑减小）。
  final Map<int, Offset> _pointerPos = {};
  final List<int> _pointerOrder = [];
  Offset _lastTwoFingerCenter = Offset.zero;
  double _twoFingerAccDx = 0;
  double _twoFingerAccDy = 0;
  bool _twoFingerConsumed = false;

  int get _activePointers => _pointerOrder.length;

  void _onPointerDown(PointerDownEvent e) {
    _pointerPos[e.pointer] = e.position;
    _pointerOrder.add(e.pointer);
    if (_activePointers == 2) {
      // 第二根手指落下：重置累积并记录双指中心
      _lastTwoFingerCenter = (_pointerPos[_pointerOrder[0]]! +
          _pointerPos[_pointerOrder[1]]!) /
          2;
      _twoFingerAccDx = 0;
      _twoFingerAccDy = 0;
      _twoFingerConsumed = false;
      // 双指激活：吸收 PageView（AbsorbPointer 依赖此重建）
      setState(() {});
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_activePointers < 2) return;
    _pointerPos[e.pointer] = e.position;
    if (_pointerOrder.length < 2) return;
    final p0 = _pointerPos[_pointerOrder[0]];
    final p1 = _pointerPos[_pointerOrder[1]];
    if (p0 == null || p1 == null) return;
    final center = (p0 + p1) / 2;
    final delta = center - _lastTwoFingerCenter;
    _lastTwoFingerCenter = center;
    if (_twoFingerConsumed) return;
    // 方向判定：水平占优 → 切歌；垂直占优 → 音量
    if (delta.dx.abs() > delta.dy.abs()) {
      _twoFingerAccDx += delta.dx;
      if (_twoFingerAccDx.abs() > 60) {
        final player = context.read<PlayerProvider>();
        unawaited(haptic(HapticKind.light));
        if (_twoFingerAccDx > 0) {
          player.playPrevious();
        } else {
          player.playNext();
        }
        _twoFingerConsumed = true;
      }
    } else {
      _twoFingerAccDy += delta.dy;
      if (_twoFingerAccDy.abs() > 20) {
        final player = context.read<PlayerProvider>();
        // 上滑 dy<0 → 音量增大；连续调节（每次移动都生效）
        player.setVolume((player.volume - _twoFingerAccDy / 800).clamp(0.0, 1.0));
        _twoFingerAccDy = 0;
      }
    }
  }

  void _onPointerUp(PointerEvent e) {
    if (!_pointerOrder.remove(e.pointer) &&
        !_pointerPos.containsKey(e.pointer)) {
      return;
    }
    _pointerPos.remove(e.pointer);
    _twoFingerAccDx = 0;
    _twoFingerAccDy = 0;
    _twoFingerConsumed = false;
    // ✅ 仅指针数 2→1 边界重建（AbsorbPointer 状态翻转）；单指抬起无需重建
    if (_activePointers == 1) {
      setState(() {});
    }
  }

  // ─── Slide-down dismiss gesture ───
  double _dragOffset = 0.0;
  bool _isDismissing = false;
  static const double _dismissThreshold = 150.0;

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
    final wasBelowHalf = _pageOffset < 0.5;
    setState(() {
      _pageOffset = newOffset;
    });
    // 进入歌词页面时同步 controller 到实际播放位置
    if (wasBelowHalf && newOffset >= 0.5 && mounted) {
      final player = context.read<PlayerProvider>();
      player.lyricController.setProgress(player.position);
    }
  }

  @override
  void dispose() {
    _dragResetController?.dispose();
    _dismissController?.dispose();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  /// 恢复下滑位移到 0 的动画
  void _animateDragReset() {
    if (!mounted) return;
    final was = _dragOffset;
    // 复用/替换字段持有的控制器，避免手势快速连续触发时产生多个并发 Ticker
    _dragResetController?.dispose();
    final controller =
        _dragResetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    controller.addListener(() {
      if (!mounted) return;
      setState(() {
        _dragOffset = lerpDouble(0, was, 1 - controller.value)!;
      });
    });
    controller.forward().whenComplete(() {
      if (identical(_dragResetController, controller)) {
        _dragResetController = null;
      }
      controller.dispose();
      if (mounted) setState(() => _dragOffset = 0.0);
    });
  }

  /// 执行下滑退出动画
  void _animateDismiss() {
    if (!mounted || _isDismissing) return;
    setState(() => _isDismissing = true);
    _dismissController?.dispose();
    final controller =
        _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    controller.addListener(() {
      if (!mounted) return;
      setState(() {
        _dragOffset = lerpDouble(_dragOffset, MediaQuery.of(context).size.height, controller.value)!;
      });
    });
    controller.forward().whenComplete(() {
      if (identical(_dismissController, controller)) {
        _dismissController = null;
      }
      controller.dispose();
      if (mounted) Navigator.pop(context);
    });
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
            (player.sleepTimerRemaining!.inMinutes - duration.inMinutes).abs() < 2);

    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.blueAccent)
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
    showM3ModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final player = context.read<PlayerProvider>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('定时关闭',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  _sleepTimerOption(ctx, player, '15 分钟', const Duration(minutes: 15)),
                  _sleepTimerOption(ctx, player, '30 分钟', const Duration(minutes: 30)),
                  _sleepTimerOption(ctx, player, '45 分钟', const Duration(minutes: 45)),
                  _sleepTimerOption(ctx, player, '60 分钟', const Duration(minutes: 60)),
                  if (player.sleepTimerRemaining != null)
                    _sleepTimerOption(ctx, player, '关闭定时', Duration.zero),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLyricSettingsSheet() {
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



  void _showArtistSelectionSheet(PlayerProvider player, Song song) {
    // KRM 数据已在 Provider 层通过 hash 校验，可直接信任
    final krmAuthors = player.currentSongAuthors;
    final hasKrm = krmAuthors.isNotEmpty;

    // 兜底方案：使用分割出来的歌名歌手列表
    final List<Map<String, dynamic>> displayAuthors = hasKrm
        ? krmAuthors
        : song.artists.map((name) => {
              'name': name,
              'id': song.artists.indexOf(name) == 0 ? song.artistId : null,
            }).toList();

    showM3ModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('选择歌手',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...displayAuthors.map((author) {
                    final artistName = author['name'] as String;
                    final artistId = author['id'] as int?;
                    final hasDetailId = artistId != null && artistId > 0;
                    return ListTile(
                      leading: const Icon(Icons.person, color: Colors.white70, size: 20),
                      title: Text(artistName, style: const TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (hasDetailId) {
                          Navigator.pushNamed(context, '/artist/detail', arguments: {
                            'id': artistId,
                            'name': artistName,
                          });
                        } else {
                          // 搜索降级
                          Navigator.pushNamed(context, '/search', arguments: artistName);
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
  }

  void _showMoreSheet() {
    const spds = [1.0, 0.5, 0.75, 1.25, 1.5, 2.0];
    showM3ModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Consumer<PlayerProvider>(
                builder: (context, p, _) {
                  final song = p.currentSong;
                  // 优先使用从 /krm/audio 获取的真实专辑 ID
                  final albumId = p.currentSongAlbumId;
                  final albumName = song?.albumName ?? '';
                  // 查看专辑显示条件：有 albumId，或者有 albumName 且不等于 'Unknown' / '无'
                  final hasAlbum = song != null && (albumId > 0 || (albumName.isNotEmpty && albumName != 'Unknown' && albumName != '无'));
                  
                  // 歌手呈现：KRM 数据已在 Provider 层通过 hash 校验，可直接信任
                  final krmAuthors = p.currentSongAuthors;
                  final hasKrm = krmAuthors.isNotEmpty;
                  final displayArtistsList = hasKrm ? krmAuthors.map((e) => e['name'] as String).toList() : (song?.artists ?? []);
                  final hasArtists = song != null && displayArtistsList.isNotEmpty;
                  final artistsDisplayString = hasKrm ? displayArtistsList.join(' / ') : (song?.artistDisplay ?? '');

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
                                    const Icon(Icons.fast_forward, color: Colors.white70, size: 20),
                                    const SizedBox(width: 12),
                                    Text('播放倍速',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: AppShape.xs,
                                  ),
                                  child: Text('${p.currentSpeed.toStringAsFixed(2)}x',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.white70,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.15)
                                              : Colors.white.withValues(alpha: 0.03),
                                          border: Border.all(
                                            color: isSelected ? Colors.white30 : Colors.white10,
                                            width: 1,
                                          ),
                                          borderRadius: AppShape.sm,
                                        ),
                                        child: Text('${s}x',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: isSelected ? Colors.white : Colors.white38,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                      const Divider(color: Colors.white12, height: 16),
                      // 查看专辑
                      if (hasAlbum)
                        ListTile(
                          leading: const Icon(Icons.album, color: Colors.white70, size: 20),
                          title: const Text('查看专辑',
                              style: TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                          onTap: () {
                            Navigator.pop(ctx);
                            if (albumId > 0) {
                              Navigator.pushNamed(context, '/album/detail', arguments: {
                                'id': albumId,
                                'name': albumName,
                              });
                            } else {
                              // 搜索降级
                              Navigator.pushNamed(context, '/search', arguments: albumName);
                            }
                          },
                        ),
                      // 查看歌手
                      if (hasArtists)
                        ListTile(
                          leading: const Icon(Icons.person, color: Colors.white70, size: 20),
                          title: Text(displayArtistsList.length > 1
                              ? '查看歌手 (共 ${displayArtistsList.length} 位)'
                              : '查看歌手'),
                          subtitle: Text(artistsDisplayString,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white30)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                          onTap: () {
                            Navigator.pop(ctx);
                            if (displayArtistsList.length > 1) {
                              // 弹窗让用户挑选歌手
                              _showArtistSelectionSheet(p, song);
                            } else {
                              // 单歌手逻辑
                              final artistName = displayArtistsList.first;
                              final artistId = hasKrm ? krmAuthors.first['id'] as int? : song.artistId;
                              if (artistId != null && artistId > 0) {
                                Navigator.pushNamed(context, '/artist/detail', arguments: {
                                  'id': artistId,
                                  'name': artistName,
                                });
                              } else {
                                // 搜索降级
                                Navigator.pushNamed(context, '/search', arguments: artistName);
                              }
                            }
                          },
                        ),
                      if (hasAlbum || hasArtists)
                        const Divider(color: Colors.white12, height: 1),
                      // 定时关闭
                      ListTile(
                        leading: const Icon(Icons.timer_outlined, color: Colors.white70, size: 20),
                        title: const Text('定时关闭',
                            style: TextStyle(color: Colors.white)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showSleepTimerSheet();
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      // 编码音质
                      ListTile(
                        leading: const Icon(Icons.speed, color: Colors.white70, size: 20),
                        title: const Text('编码音质',
                            style: TextStyle(color: Colors.white)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.currentQualityLabel,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38)),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showQualitySheet();
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      // 音效
                      ListTile(
                        leading: const Icon(Icons.spatial_audio, color: Colors.white70, size: 20),
                        title: const Text('音效',
                            style: TextStyle(color: Colors.white)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.effectLabel,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38)),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                        ],),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showEffectSheet();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEffectSheet() {
    showM3ModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final p = context.read<PlayerProvider>();
        final currentEffect = p.effectKey;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('音效',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  // "关闭"选项始终可用
                  ListTile(
                    leading: Icon(
                      currentEffect == 'none'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: currentEffect == 'none' ? Colors.white : Colors.white38,
                      size: 20,
                    ),
                    title: const Text('关闭',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text('不使用音效',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38)),
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
                            ? Colors.white
                            : (isAvailable ? Colors.white38 : Colors.white10),
                        size: 20,
                      ),
                      title: Text(label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isAvailable ? Colors.white60 : Colors.white24),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          )),
                      subtitle: !isAvailable
                          ? Text('当前歌曲不支持',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white24))
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
  }

  void _showQualitySheet() {
    final player = context.read<PlayerProvider>();
    final selectedKey =
        Quality.levels[player.qualityLevel % Quality.levels.length];
    final availableQualities = player.getAvailableQualities();
    showM3ModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final p = context.read<PlayerProvider>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('音质选择',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...Quality.levels.map((key) {
                  final label = Quality.label(key);
                  final isSelected = key == selectedKey;
                  final isAvailable = p.isQualityAvailable(key);
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected
                          ? Colors.white
                          : (isAvailable ? Colors.white38 : Colors.white10),
                      size: 20,
                    ),
                    title: Text(label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isAvailable ? Colors.white60 : Colors.white24),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        )),
                    subtitle: Row(
                      children: [
                        Text(
                          _qualitySubtitle(key),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isAvailable ? Colors.white38 : Colors.white10),
                        ),
                        if (!isAvailable) ...[
                          const SizedBox(width: 8),
                          Text('当前歌曲不支持',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white24)),
                        ],
                        if (isAvailable && !availableQualities.contains(key)) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: AppShape.xs,
                            ),
                            child: Text('降级可用',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white24)),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white24),
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

  Widget _buildLyricsPage(PlayerProvider player, Song song,
      {bool compact = false}) {
    final model = player.lyricController.lyricNotifier.value;
    final hasLyrics = model != null && model.lines.isNotEmpty;
    final ls = context.read<ThemeProvider>().lyricSettings;

    Widget lyricsContent;
    if (player.lyricLoading) {
      lyricsContent = const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    } else if (!hasLyrics) {
      lyricsContent = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined, size: 48, color: Colors.white54),
            SizedBox(height: 16),
            Text('暂无歌词',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    } else {
      lyricsContent = LyricView(
        key: ValueKey('lyrics_${player.selectedLyricLang}_${song.hash ?? song.id}'),
        controller: player.lyricController,
        style: _buildLyricStyle(compact: compact),
      );
    }

    // 歌词内容（无黑色背景遮罩）
    Widget lyricsWidget = Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: lyricsContent,
    );

    // blurEffect 开启时：用 ShaderMask 给文字做上下边缘渐隐
    if (ls.blurEffect) {
      lyricsWidget = ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.12, 0.88, 1.0],
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
        _buildLyricsFooter(player),
      ],
    );
  }

  Widget _buildLyricsFooter(PlayerProvider player) {
    final currentSong = player.currentSong;
    final bool isLocal = currentSong?.isLocal ?? false;
    String source = isLocal ? 'LOCAL' : 'KUGOU';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          // [词] source badge (点击打开歌词设置)
          GestureDetector(
            onTap: _showLyricSettingsSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: AppShape.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('词',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                          height: 1.2)),
                  const SizedBox(width: 4),
                  Text(source,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white38,
                          height: 1.2)),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Language toggle (only when KRC has lang data)
          if (player.hasLangData)
            GestureDetector(
              onTap: () {
                player.toggleTranslation();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: AppShape.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.showTranslation ? '翻译' : '歌词',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      player.showTranslation
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 10,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (ctx, player, _) {
        final song = player.currentSong;
        if (song == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text('暂无播放', style: TextStyle(color: Colors.white70)),
            ),
          );
        }

        // ✅ 新增适配代码：横屏平板 → 双栏布局（左封面+控制 | 右歌词）
        final isTablet = context.isTablet;
        final isLandscapeTablet = context.isLandscapeTablet;
        // 双指手势激活时吸收 PageView 事件（避免双指横滑触发翻页）
        final twoFingerActive = _activePointers >= 2;

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (_isDismissing) return;
              // ✅ 双指手势激活时不响应下滑退出（双指竖滑 = 音量调节）
              if (_activePointers >= 2) return;
              // 只允许下滑
              if (details.delta.dy < 0 && _dragOffset <= 0) return;
              setState(() {
                _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, double.infinity);
              });
            },
            onVerticalDragEnd: (details) {
              if (_isDismissing) return;
              // ✅ 双指手势激活时不响应下滑退出
              if (_activePointers >= 2) return;
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 800 || _dragOffset > _dismissThreshold) {
                _animateDismiss();
              } else {
                _animateDragReset();
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Opacity(
                opacity: (1.0 - (_dragOffset / _dismissThreshold).clamp(0.0, 0.5)).toDouble(),
                child: RepaintBoundary(
                  // ✅ 新增适配代码：RepaintBoundary 隔离流光背景重绘，避免整页随动画重建
                  child: Stack(
                    children: [
                      // ── Dynamic background ──
                      PlayerBackground(
                        albumCoverUrl: song.albumCoverUrl,
                        paletteColor: player.backgroundColor,
                        paletteColors: player.paletteColors,
                        // 双栏/沉浸布局无 PageView 滚动，背景保持初始状态
                        scrollOffset: isLandscapeTablet || _immersive ? 0.0 : _pageOffset,
                      ),

                      // ── Content ──
                      SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Page header（沉浸模式隐藏，其余场景固定顶部）──
                            if (!_immersive) _buildPageHeader(player, song),
                            Expanded(
                              child: _immersive
                                  ? _buildImmersiveBody(player, song)
                                  : isLandscapeTablet
                                      ? _buildLandscapeBody(player, song)
                                      : AbsorbPointer(
                                          // ✅ 双指手势激活时吸收 PageView 事件（避免双指横滑翻页）
                                          absorbing: twoFingerActive,
                                          child: PageView(
                                            controller: _pageController,
                                            children: [
                                              // Page 0: Cover + controls
                                              // ✅ RepaintBoundary 隔离封面页重绘区域，避免与歌词页互相拖累
                                              RepaintBoundary(child: _buildCoverPage(player, song)),
                                              // Page 1: Immersive lyrics
                                              RepaintBoundary(child: _buildLyricsPage(player, song)),
                                            ],
                                          ),
                                        ),
                            ),
                          ],
                        ),
                      ),

                      // ✅ 新增适配代码：平板双指手势层（Listener 原始指针跟踪，绕过手势竞技场）
                      // 双指水平滑=切歌、双指垂直滑=音量；单指手势（PageView 翻页 / 下滑退出）不受影响。
                      if (isTablet && !_immersive)
                        Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: _onPointerDown,
                          onPointerMove: _onPointerMove,
                          onPointerUp: _onPointerUp,
                          onPointerCancel: _onPointerUp,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ 新增适配代码：横屏平板双栏布局（Salt Player / Apple Music 平板风格）
  Widget _buildLandscapeBody(PlayerProvider player, Song song) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左栏：封面 + 进度 + 控制（复用现有 _buildCoverPage，控件布局不变）
        Expanded(
          flex: 5,
          child: RepaintBoundary(child: _buildCoverPage(player, song)),
        ),
        const SizedBox(width: 1),
        // 右栏：歌词（复用现有 _buildLyricsPage，同步滚动/高亮机制不变，仅样式紧凑化）
        Expanded(
          flex: 6,
          child: RepaintBoundary(
            child: _buildLyricsPage(player, song, compact: true),
          ),
        ),
      ],
    );
  }

  // ✅ 新增适配代码：沉浸模式布局（Salt Player 风格）
  // 仅保留歌词 + 进度条 + 退出提示；点击空白处或提示文字退出。
  Widget _buildImmersiveBody(PlayerProvider player, Song song) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleImmersive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildLyricsPage(player, song, compact: true),
          ),
          // 底部进度条（独立订阅，不随歌词重建）
          _PlayerProgressBar(pageOffset: _pageOffset),
          const SizedBox(height: 6),
          // 退出提示
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '点击任意处退出沉浸模式',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ──

  // ── Page header (shared, pinned at top) ──

  Widget _buildPageHeader(PlayerProvider player, Song song) {
    final krmAuthors = player.currentSongAuthors;
    final hasKrm = krmAuthors.isNotEmpty;
    final displayArtistsList = hasKrm ? krmAuthors.map((e) => e['name'] as String).toList() : song.artists;
    final artistsDisplayString = hasKrm ? displayArtistsList.join(' / ') : song.artistDisplay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () {
              if (displayArtistsList.length > 1) {
                _showArtistSelectionSheet(player, song);
              } else if (displayArtistsList.isNotEmpty) {
                final artistName = displayArtistsList.first;
                final artistId = hasKrm ? krmAuthors.first['id'] as int? : song.artistId;
                if (artistId != null && artistId > 0) {
                  Navigator.pushNamed(context, '/artist/detail', arguments: {
                    'id': artistId,
                    'name': artistName,
                  });
                } else {
                  Navigator.pushNamed(context, '/search', arguments: artistName);
                }
              }
            },
            child: Text(
              artistsDisplayString,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 0: cover page ──

  Widget _buildCoverPage(PlayerProvider player, Song song) {
    // 从 privilege 取最高可用音质，无数据时 fallback 到当前选中
    final qualityOptions = player.qualityOptions;
    final highestAvailable = qualityOptions.isNotEmpty
        ? qualityOptions.last.value
        : null;
    final showKey = player.resolvedQuality ?? highestAvailable ??
        Quality.levels[player.qualityLevel % Quality.levels.length];
    final qualityLabel = Quality.label(showKey);
    const speeds = [1.0, 0.5, 0.75, 1.25, 1.5, 2.0];

    return Column(
      children: [
        // Album cover — flex takes remaining space above bottom controls
        Expanded(
          child: Center(
            // ✅ context.select 移入 PlayerCoverArt.build 内部（合法位置），
            // 这里只传音质是否达到 Hi-Res（resolvedQuality == 'high'），
            // 徽标开关（showHiResBadge）由 PlayerCoverArt 内部订阅
            child: PlayerCoverArt(
              song: song,
              scrollOffset: _pageOffset,
              showHiRes: player.resolvedQuality == 'high',
            ),
          ),
        ),

        // Quality text
        Text(
          qualityLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.white60,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 12),

        // Progress bar（独立订阅 position/duration/progress，避免整页重建）
        _PlayerProgressBar(pageOffset: _pageOffset),

        const SizedBox(height: 12),

        // Three controls: 播放/暂停/切歌（独立订阅 isPlaying/isLoading）
        // ✅ 新增适配代码：仅平板启用长按播放键沉浸模式
        _PlayerControls(
          onLongPressPlayPause: context.isTablet ? _toggleImmersive : null,
        ),

        const SizedBox(height: 8),

        // Five icon bottom bar
        _buildIconBar(player, song, speeds),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
      ],
    );
  }

  // ── Five-icon bottom bar ──

  Widget _buildIconBar(PlayerProvider player, Song song, List<double> speeds) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // ↺ Play mode
        _IconBarItem(
          icon: _modeIcon(player.playMode),
          weight: 500,
          onTap: () {
            const modes = [
              PlayMode.sequential,
              PlayMode.shuffle,
              PlayMode.repeatOne,
            ];
            final next =
                modes[(modes.indexOf(player.playMode) + 1) % modes.length];
            unawaited(haptic(HapticKind.selection));
            player.setPlayMode(next);
          },
        ),

        // ♡ Song info / Favorite
        Consumer<LikedSongsProvider>(
          builder: (_, lp, __) {
            final liked = lp.likedIds.contains(song.id);
            return _IconBarItem(
              icon: liked ? AppIcons.favorite : AppIcons.favoriteBorder,
              weight: liked ? 700 : 400,
              fill: liked ? 1 : 0,
              iconColor: liked ? Colors.redAccent : null,
              onTap: () async {
                final auth = context.read<AuthProvider>();
                if (!auth.isLoggedIn) {
                  final goLogin = await showLoginRequiredDialog(context);
                  if (goLogin && mounted) {
                    Navigator.pushNamed(context, '/login');
                  }
                  return;
                }
                unawaited(haptic(HapticKind.medium));
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
          icon: AppIcons.tune,
          weight: 500,
          onTap: () {
            unawaited(haptic(HapticKind.light));
            Navigator.pushNamed(context, '/settings/audio/effects');
          },
        ),

        // ☰ Playlist queue
        _IconBarItem(
          icon: AppIcons.playlistPlay,
          weight: 500,
          onTap: () {
            unawaited(haptic(HapticKind.light));
            legacy.PlaybackControls.showPlaylistStatic(context, player);
          },
        ),

        // ⋮ More — opens bottom sheet
        _IconBarItem(
          icon: AppIcons.moreHoriz,
          weight: 500,
          onTap: () {
            unawaited(haptic(HapticKind.light));
            _showMoreSheet();
          },
        ),
      ],
    );
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequential:
        return AppIcons.repeat;
      case PlayMode.shuffle:
        return AppIcons.shuffle;
      case PlayMode.repeatOne:
        return AppIcons.repeatOne;
      case PlayMode.radio:
        return AppIcons.radio;
    }
  }

}

/// Icon + label item used in the bottom icon bar.
class _IconBarItem extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final double weight;
  final double fill;

  const _IconBarItem({
    required this.icon,
    this.onTap,
    this.iconColor,
    this.weight = 400,
    this.fill = 0,
  });

  @override
  Widget build(BuildContext context) {
    return M3PressScale(
      scaleDown: 0.85,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShape.sm,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: AppIcon(
            icon,
            size: 22,
            color: iconColor ?? Colors.white60,
            weight: weight,
            fill: fill,
            opticalSize: 24,
          ),
        ),
      ),
    );
  }
}

/// 独立订阅播放进度，避免进度变化时重建整个 PlayerScreen。
class _PlayerProgressBar extends StatefulWidget {
  final double pageOffset;

  const _PlayerProgressBar({required this.pageOffset});

  @override
  State<_PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<_PlayerProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, ({Duration position, Duration duration, double progress})>(
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
                  milliseconds: (_dragValue * state.duration.inMilliseconds)
                      .round(),
                )
              : state.position,
          duration: state.duration,
          progress: _isDragging ? _dragValue : state.progress,
          onDragStart: () {
            setState(() => _isDragging = true);
          },
          onDragEnd: () async {
            await player.seek(Duration(
              milliseconds: (_dragValue * state.duration.inMilliseconds)
                  .round(),
            ));
            if (mounted) {
              setState(() => _isDragging = false);
            }
          },
          onSeek: (v) {
            setState(() => _dragValue = v);
            if (_isDragging && widget.pageOffset >= 0.5) {
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
  // ✅ 新增适配代码：长按播放/暂停键回调（平板沉浸模式）
  final VoidCallback? onLongPressPlayPause;

  const _PlayerControls({this.onLongPressPlayPause});

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, ({bool isPlaying, bool isLoading})>(
      selector: (_, p) => (isPlaying: p.isPlaying, isLoading: p.isLoading),
      builder: (context, state, _) {
        final player = context.read<PlayerProvider>();
        return PlayerControlsBar(
          isPlaying: state.isPlaying,
          isLoading: state.isLoading,
          onPlayPause: player.togglePlayPause,
          onPrevious: player.playPrevious,
          onNext: player.playNext,
          onLongPressPlayPause: onLongPressPlayPause,
        );
      },
    );
  }
}
