// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:provider/provider.dart';
import 'package:ym_lyric/model/krc_language_model.dart';
import 'package:ym_lyric/model/krc_lyric_line_model.dart';
import 'package:ym_lyric/utils/krc_lyric_util.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/auth_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../constants/quality.dart';
import '../widgets/player_background.dart';
import '../widgets/player_cover_art.dart';
import '../widgets/player_controls_bar.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/playback_controls.dart' as legacy;
import '../widgets/login_required_dialog.dart';
import '../widgets/lyric_settings_panel.dart';

/// Apple Music-style full player screen with dynamic background,
/// cover-art / lyrics PageView, and smooth transitions.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // ─── 构建 LyricView 样式（从设置动态读取） ───
  LyricStyle _buildLyricStyle() {
    final ls = context.read<ThemeProvider>().lyricSettings;
    // 焦点行字重 = 用户设置 + 200（确保比普通行重）
    final int activeWeightIdx = ((ls.fontWeight / 100).round() + 2).clamp(3, 8);
    final activeWeight = FontWeight.values[activeWeightIdx];
    return LyricStyle(
      textStyle: TextStyle(
        fontSize: ls.fontSize,
        fontWeight: ls.resolvedWeight,
        height: 1.6,
        color: const Color(0xFFB0A8C0), // 灰紫
      ),
      // 焦点行同字号杜绝折行，但加粗 + 白色 + 字间距确保视觉突出
      activeStyle: TextStyle(
        fontSize: ls.fontSize,
        fontWeight: activeWeight,
        height: 1.4,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
      // 翻译/罗马音用字号区分，不用粗细
      translationStyle: TextStyle(
        fontSize: ls.translationFontSize,
        fontWeight: ls.resolvedWeight,
        height: 1.3,
        color: const Color(0xFF8A7FA0), // 淡紫
      ),
      translationActiveColor: Colors.white70,
      lineGap: 24,
      translationLineGap: 4,
      lineTextAlign: ls.centerAlign ? TextAlign.center : TextAlign.left,
      contentAlignment: ls.centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      contentPadding: const EdgeInsets.symmetric(horizontal: 28),
      selectionAnchorPosition: 0.5,
      selectionAlignment: MainAxisAlignment.center,
      // 焦点行锚点稍偏上(0.4)，补偿标题栏上移后视觉中心偏移
      activeAnchorPosition: 0.4,
      activeAlignment: MainAxisAlignment.center,
      activeHighlightColor: Colors.white,
      activeHighlightExtraFadeWidth: 14,
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
    );
  }

  // ─── PageView ───
  final PageController _pageController = PageController();
  double _pageOffset = 0.0; // 0 = cover, 1 = lyrics

  // ─── Lyrics ───
  final MusicService _musicService = MusicService();
  String? _lastLoadedHash;
  int? _lastLoadedSongId; // for local songs without hash
  bool _lyricLoading = false;

  // ─── Lyric language tracks (KRC only) ───
  /// language→per-line texts.  0=translation(中文), 1=transliteration(罗马�?
  Map<int, List<String>> _lyricLangMap = {};
  List<KrcLyricLineModel>? _krcLines;  // raw KRC lines for re‑building
  int _selectedLyricLang = 0; // default: translation
  /// Any language data available (translation and/or transliteration).
  bool get _hasLangData => _lyricLangMap.isNotEmpty;

  // ─── Drag state (progress bar) ───
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScroll);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _attachPlayerListener());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final player = context.read<PlayerProvider>();
        player.lyricController.setOnTapLineCallback((duration) {
          player.seek(duration);
        });
      }
    });
  }

  void _attachPlayerListener() {
    if (!mounted) return;
    context.read<PlayerProvider>().addListener(_onPlayerTick);
  }

  void _onPlayerTick() {
    if (!mounted) return;
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return;

    // 拖拽进度条时同步歌词滚动（仅在歌词页可见时才更新 controller�?
    // 否则 controller 会被拖拽位置污染，进歌词页时第一帧显示错�?
    if (_isDraggingProgress && _pageOffset >= 0.5) {
      final dragPos = Duration(
        milliseconds: (_dragProgressValue * player.duration.inMilliseconds)
            .round(),
      );
      player.lyricController.setProgress(dragPos);
    }

    // Load lyrics when song changes or lyrics were cleared (e.g. quality switch)
    final songChanged = (song.hash != null && song.hash != _lastLoadedHash) ||
        (song.hash == null && song.id != _lastLoadedSongId);
    final currentLines = player.lyricController.lyricNotifier.value?.lines ?? [];
    final lyricsCleared = currentLines.isEmpty &&
        _lastLoadedHash != null &&
        song.hash == _lastLoadedHash;
    if (songChanged || lyricsCleared) {
      if (song.hash != null) {
        _lastLoadedHash = song.hash;
      }
      _lastLoadedSongId = song.id;
      _loadLyricsForSong(song);
    }
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final newOffset = _pageController.page?.clamp(0.0, 1.0) ?? 0.0;
    final wasBelowHalf = _pageOffset < 0.5;
    setState(() {
      _pageOffset = newOffset;
    });
    // 进入歌词页面时同�?controller 到实际播放位�?
    if (wasBelowHalf && newOffset >= 0.5 && mounted) {
      final player = context.read<PlayerProvider>();
      if (!_isDraggingProgress) {
        player.lyricController.setProgress(player.position);
      }
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    try {
      context.read<PlayerProvider>().removeListener(_onPlayerTick);
    } catch (_) {}
    super.dispose();
  }

  // ─── Speech bubble helper for �?menu items �?shows a bottom sheet ──

  void _showSleepTimerSheet() {
    showModalBottomSheet(
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
    showModalBottomSheet(
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

  void _showMoreSheet() {
    const spds = [1.0, 0.5, 0.75, 1.25, 1.5, 2.0];
    showModalBottomSheet(
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
                  // 倍速
                  ListTile(
                    leading: const Icon(Icons.fast_forward, color: Colors.white70, size: 20),
                    title: Text('倍速 ${p.currentSpeed.toStringAsFixed(1)}x',
                        style: const TextStyle(color: Colors.white)),
                    trailing: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...spds.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => p.setSpeed(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: s == p.currentSpeed
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${s}x',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: s == p.currentSpeed ? Colors.white : Colors.white38,
                                      fontWeight: s == p.currentSpeed ? FontWeight.w600 : FontWeight.normal,
                                    )),
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
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
                  // 音质切换
                  ListTile(
                    leading: const Icon(Icons.speed, color: Colors.white70, size: 20),
                    title: const Text('音质切换',
                        style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showQualitySheet();
                    },
                  ),
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
    showModalBottomSheet(
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
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.white : Colors.white38,
                      size: 20,
                    ),
                    title: Text(label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        )),
                    subtitle: Text(
                      _qualitySubtitle(key),
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                    onTap: () {
                      p.setQuality(key);
                      Navigator.pop(ctx);
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

  Widget _sleepTimerOption(BuildContext ctx, PlayerProvider player, String label, Duration duration) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        if (duration == Duration.zero) {
          player.cancelSleepTimer();
        } else {
          player.setSleepTimer(duration);
        }
        Navigator.pop(ctx);
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Lyric loading (same API as original)
  // ────────────────────────────────────────────────────────────

  void _loadLyricsForSong(Song song) {
    _dragProgressValue = 0.0;
    _lyricLangMap = {};
    _krcLines = null;
    _selectedLyricLang = 0;

    // Embedded lyrics from local files (companion .lrc or metadata)
    if (song.lyrics != null && song.lyrics!.isNotEmpty) {
      setState(() => _lyricLoading = false);
      if (mounted) {
        context.read<PlayerProvider>().lyricController.loadLyric(song.lyrics!);
      }
      return;
    }

    // Online lyrics via API (hash-based)
    if (song.hash != null) {
      setState(() => _lyricLoading = true);
      _loadLyrics(song.hash!, songName: song.name);
    } else {
      if (mounted) {
        context.read<PlayerProvider>().clearLyrics();
      }
    }
  }

  Future<void> _loadLyrics(String hash, {String? songName}) async {
    try {
      final searchRes =
          await _musicService.searchLyricByHash(hash, keywords: songName);
      final data = searchRes['data'] as Map<String, dynamic>? ?? searchRes;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = int.parse(c['id'].toString());
        final key = c['accesskey'] as String? ?? '';

        // ── Try KRC first (with translations) ──
        final krcBytes = await _musicService.fetchKrcContent(id, key);
        if (krcBytes.isNotEmpty) {
          try {
            final krcModel = KrcLyricUtil.parseLyrics(krcBytes);
            if (krcModel.krcLyricList.isEmpty) throw 'empty krc';

            // Parse translation & transliteration from lyricTag.language (base64 JSON)
            // language: 0 = translation (意译/中文翻译), 1 = transliteration (音译/罗马�?
            _lyricLangMap = {};
            if (krcModel.lyricTag.language != null &&
                krcModel.lyricTag.language!.isNotEmpty) {
              try {
                final langJson = jsonDecode(
                  utf8.decode(base64Decode(krcModel.lyricTag.language!)),
                );
                final krcLang = KrcLanguage.fromJson(langJson);
                for (final c in krcLang.content) {
                  _lyricLangMap[c.language] = c.lyricContent
                      .map((words) => words.join())
                      .toList();
                }
              } catch (e, s) {
                Log.e('player_screen', 'krc lang parse error', e, s);
              }
            }

            // 记住原始 KRC lines，供语言切换时重�?
            _krcLines = krcModel.krcLyricList;
            _selectedLyricLang = _lyricLangMap.keys
                .contains(0) ? 0 : (_lyricLangMap.keys.firstOrNull ?? 0);

            // 构建选定语言的翻译时间戳映射
            final transMap = _buildTransMap(_selectedLyricLang);
            final lines = _buildLyricLines(krcModel.krcLyricList, transMap);

            if (mounted) {
              if (hash != _lastLoadedHash) return;
              context.read<PlayerProvider>().loadLyricModel(
                LyricModel(lines: lines),
              );
            }
            if (mounted) setState(() => _lyricLoading = false);
            return;
          } catch (e, s) {
            Log.e('player_screen', 'krc parse error', e, s);
          }
        }

        // ── Fallback to LRC ──
        final rawContent = await _musicService.fetchLyricContent(id, key);
        if (rawContent.isNotEmpty) {
          try {
            String decoded;
            try {
              decoded = utf8.decode(base64Decode(rawContent));
            } catch (e, s) {
              Log.e('player_screen', 'base64 error', e, s);
              decoded = rawContent;
            }
            if (mounted) {
              if (hash != _lastLoadedHash) return;
              context.read<PlayerProvider>().lyricController.loadLyric(decoded);
            }
          } catch (e, s) {
            Log.e('player_screen', 'parse error', e, s);
          }
        }
      } else if (mounted) {
        context.read<PlayerProvider>().clearLyrics();
      }
    } catch (e, s) {
      Log.e('player_screen', 'lyric load error', e, s);
    }
    if (mounted) setState(() => _lyricLoading = false);
  }

  // ─── Lyric language toggle ───────────────────────────────────

  /// Build translation map for a single language track.
  Map<int, String> _buildTransMap(int lang) {
    final map = <int, String>{};
    final lines = _lyricLangMap[lang];
    if (lines == null || _krcLines == null) return map;
    for (int i = 0;
        i < _krcLines!.length && i < lines.length; i++) {
      if (lines[i].isNotEmpty) {
        map[_krcLines![i].startTime] = lines[i];
      }
    }
    return map;
  }

  /// Build LyricLine list from raw KRC lines + translation map.
  List<LyricLine> _buildLyricLines(
    List<KrcLyricLineModel> krcLines,
    Map<int, String> transMap,
  ) {
    final result = <LyricLine>[];
    for (final line in krcLines) {
      String text;
      try {
        text = line.getWordLine();
      } catch (_) {
        continue;
      }
      if (text.trim().isEmpty) continue;

      final words = <LyricWord>[];
      if (line.line != null) {
        final lineStart = line.startTime;
        for (final w in line.line!) {
          if (w.word == null || w.word!.isEmpty) continue;
          final ws = (w.startTime ?? 0) + lineStart;
          final we = ws + (w.duration ?? 0);
          words.add(LyricWord(
            text: w.word!,
            start: Duration(milliseconds: ws),
            end: Duration(milliseconds: we),
          ));
        }
      }

      result.add(LyricLine(
        start: Duration(milliseconds: line.startTime),
        end: Duration(milliseconds: line.startTime + line.duration),
        text: text,
        words: words.isNotEmpty ? words : null,
        translation: transMap[line.startTime],
      ));
    }
    return result;
  }

  /// Re‑build and reload the lyric model with the other language track.
  void _applyLyricLang(int lang) {
    if (_krcLines == null || !_lyricLangMap.containsKey(lang)) return;
    _selectedLyricLang = lang;
    final transMap = _buildTransMap(lang);
    final lines = _buildLyricLines(_krcLines!, transMap);
    if (mounted) {
      context.read<PlayerProvider>().loadLyricModel(LyricModel(lines: lines));
    }
  }

  // ────────────────────────────────────────────────────────────
  //  Lyric UI
  // ────────────────────────────────────────────────────────────

  String _langLabel(int lang) {
    switch (lang) {
      case 0:
        return '翻译';
      case 1:
        return '罗马音';
      default:
        return '歌词';
    }
  }

  Widget _buildLyricsPage(PlayerProvider player, Song song) {
    final model = player.lyricController.lyricNotifier.value;
    final hasLyrics = model != null && model.lines.isNotEmpty;

    Widget lyricsContent;
    if (_lyricLoading) {
      lyricsContent = const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    } else if (!hasLyrics) {
      lyricsContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lyrics_outlined, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            const Text('暂无歌词',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    } else {
      lyricsContent = LyricView(
        key: ValueKey('lyrics_${_selectedLyricLang}_${_lastLoadedHash ?? _lastLoadedSongId}'),
        controller: player.lyricController,
        style: _buildLyricStyle(),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 4),

        // Lyrics area with dark backdrop for readability
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Blur backdrop (semi-transparent dark overlay)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Lyrics
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: lyricsContent,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Footer: source badge + language toggle
        _buildLyricsFooter(),
      ],
    );
  }

  Widget _buildLyricsFooter() {
    // Determine source label
    // Default to KUGOU; could check song.path for local, Navidrome flag etc.
    String source = 'KUGOU';
    // TODO: detect source �?LOCAL if local file, NAVIDROME if from Navidrome

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
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('词',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                          height: 1.2)),
                  const SizedBox(width: 4),
                  Text(source,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                          height: 1.2)),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Language toggle (only when KRC has lang data)
          if (_hasLangData)
            GestureDetector(
              onTap: () {
                final keys = _lyricLangMap.keys.toList()..sort();
                if (keys.isEmpty) return;
                final cur = keys.indexOf(_selectedLyricLang);
                final next = keys[(cur + 1) % keys.length];
                _applyLyricLang(next);
                setState(() {});
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _langLabel(_selectedLyricLang),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios,
                        size: 10, color: Colors.white38),
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

        // ── Slide-down gesture state ──
        double _dragOffset = 0;
        const double _dismissThreshold = 150;

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onVerticalDragUpdate: (details) {
              _dragOffset += details.delta.dy;
              if (_dragOffset > _dismissThreshold && mounted) {
                Navigator.pop(context);
              }
            },
            onVerticalDragEnd: (details) {
              _dragOffset = 0;
              if ((details.primaryVelocity ?? 0) > 800 && mounted) {
                Navigator.pop(context);
              }
            },
            child: Stack(
              children: [
                // ── Dynamic background ──
                PlayerBackground(
                  albumCoverUrl: song.albumCoverUrl,
                  paletteColor: player.backgroundColor,
                  paletteColors: player.paletteColors,
                  scrollOffset: _pageOffset,
                ),

                // ── Content ──
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Page header (shared, pinned at top) ──
                      _buildPageHeader(song),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          children: [
                            // Page 0: Cover + controls
                            _buildCoverPage(player, song),
                            // Page 1: Immersive lyrics
                            _buildLyricsPage(player, song),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Top bar ──

  // ── Page header (shared, pinned at top) ──

  Widget _buildPageHeader(Song song) {
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
          Text(
            song.artistDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 0: cover page ──

  Widget _buildCoverPage(PlayerProvider player, Song song) {
    final selectedKey =
        Quality.levels[player.qualityLevel % Quality.levels.length];
    final showLabel = player.resolvedQuality ?? selectedKey;
    final qualityLabel = Quality.label(showLabel);
    const speeds = [1.0, 0.5, 0.75, 1.25, 1.5, 2.0];

    return Column(
      children: [
        // Album cover — flex takes remaining space above bottom controls
        Expanded(
          child: Center(
            child: PlayerCoverArt(song: song, scrollOffset: _pageOffset),
          ),
        ),

        // Quality text
        Text(
          qualityLabel,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white60,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 12),

        // Progress bar
        PlayerProgressBar(
          position: player.position,
          duration: player.duration,
          progress: _isDraggingProgress
              ? _dragProgressValue
              : (player.progress.isFinite ? player.progress : 0.0),
          onDragStart: () {
            setState(() => _isDraggingProgress = true);
            final pos = Duration(
              milliseconds:
                  (_dragProgressValue * player.duration.inMilliseconds).round(),
            );
            player.lyricController.setProgress(pos);
          },
          onDragEnd: () async {
            await player.seek(Duration(
              milliseconds: (_dragProgressValue *
                      player.duration.inMilliseconds)
                  .round(),
            ));
            if (mounted) {
              setState(() => _isDraggingProgress = false);
            }
          },
          onSeek: (v) {
            _dragProgressValue = v;
            if (_isDraggingProgress) {
              final pos = Duration(
                milliseconds: (v * player.duration.inMilliseconds).round(),
              );
              player.lyricController.setProgress(pos);
            }
          },
        ),

        const SizedBox(height: 12),

        // Three controls: �?�?�?
        PlayerControlsBar(
          isPlaying: player.isPlaying,
          isLoading: player.isLoading,
          onPlayPause: player.togglePlayPause,
          onPrevious: player.playPrevious,
          onNext: player.playNext,
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
          onTap: () {
            const modes = [
              PlayMode.sequential,
              PlayMode.shuffle,
              PlayMode.repeatOne,
            ];
            final next =
                modes[(modes.indexOf(player.playMode) + 1) % modes.length];
            player.setPlayMode(next);
          },
        ),

        // ♡ Song info / Favorite
        Consumer<LikedSongsProvider>(
          builder: (_, lp, __) {
            final liked = lp.likedIds.contains(song.id);
            return _IconBarItem(
              icon: liked ? Icons.favorite : Icons.favorite_border,
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
          onTap: () =>
              Navigator.pushNamed(context, '/settings/audio/effects'),
        ),

        // ☰ Playlist queue
        _IconBarItem(
          icon: Icons.playlist_play,
          onTap: () =>
              legacy.PlaybackControls.showPlaylistStatic(context, player),
        ),

        // ⋮ More — opens bottom sheet
        _IconBarItem(
          icon: Icons.more_horiz,
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Icon(icon, size: 22, color: iconColor ?? Colors.white60),
      ),
    );
  }
}
