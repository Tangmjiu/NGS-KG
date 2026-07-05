// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏搜索页 — 语音搜索 + 文本搜索，适配圆形屏幕

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../services/music_service.dart';
import '../services/voice_search_service.dart';
import '../widgets/watch_song_tile.dart';
import '../widgets/round_safe_area.dart';

/// 搜索页面内部状态
enum _SearchState { initial, listening, searching, results, empty, error }

/// 手表版搜索页面
///
/// 提供两种搜索方式：
/// - 语音搜索：点击大麦克风按钮，启动语音识别后自动搜索
/// - 文本搜索：输入关键字，300ms debounce 后自动搜索
///
/// 搜索结果以 [WatchSongTile] 列表展示，点击即播。
class WatchSearchScreen extends StatefulWidget {
  const WatchSearchScreen({super.key});

  @override
  State<WatchSearchScreen> createState() => _WatchSearchScreenState();
}

class _WatchSearchScreenState extends State<WatchSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _voiceService = VoiceSearchService();

  List<Song> _results = [];
  _SearchState _state = _SearchState.initial;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 搜索逻辑
  // ─────────────────────────────────────────────

  /// 文本输入变化时 debounce 300ms 后搜索
  void _onSearchTextChanged() {
    _debounceTimer?.cancel();
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _state = _SearchState.initial;
        _errorMessage = null;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(keyword);
    });
  }

  /// 执行搜索请求
  Future<void> _performSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;

    setState(() {
      _state = _SearchState.searching;
      _errorMessage = null;
    });

    try {
      final musicService = context.read<MusicService>();
      final songs = await musicService.search(keyword.trim(), limit: 20);

      if (!mounted) return;

      if (songs.isEmpty) {
        setState(() {
          _results = [];
          _state = _SearchState.empty;
        });
      } else {
        setState(() {
          _results = songs;
          _state = _SearchState.results;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _state = _SearchState.error;
        _errorMessage = e.toString();
      });
    }
  }

  // ─────────────────────────────────────────────
  // 语音搜索
  // ─────────────────────────────────────────────

  /// 启动语音搜索流程
  Future<void> _startVoiceSearch() async {
    setState(() => _state = _SearchState.listening);

    try {
      final available = await _voiceService.initialize();
      if (!available) {
        if (!mounted) return;
        setState(() {
          _state = _SearchState.error;
          _errorMessage = '语音搜索不可用';
        });
        return;
      }

      final result = await _voiceService.listenOnce();
      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        _searchController.text = result;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
        // 跳过 debounce，立即搜索
        _debounceTimer?.cancel();
        _performSearch(result);
      } else {
        setState(() {
          _state = _searchController.text.trim().isEmpty
              ? _SearchState.initial
              : _SearchState.results;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _SearchState.error;
        _errorMessage = '语音搜索失败';
      });
    }
  }

  // ─────────────────────────────────────────────
  // 播放
  // ─────────────────────────────────────────────

  /// 点击结果项播放歌曲
  void _playSong(Song song) {
    context.read<PlayerProvider>().playSong(song, playlist: _results);
  }

  // ─────────────────────────────────────────────
  // UI 构建
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RoundSafeArea(
      child: Column(
        children: [
          // ── 搜索输入框 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: '搜索音乐',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _focusNode.unfocus();
                        },
                        child: Icon(
                          Icons.clear,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onSubmitted: (value) {
                _debounceTimer?.cancel();
                _performSearch(value);
              },
            ),
          ),

          // ── 内容区 ──
          Expanded(
            child: _buildContent(theme, colorScheme),
          ),
          ],
        ),
      );
  }

  /// 根据当前状态构建内容区域
  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    switch (_state) {
      case _SearchState.initial:
        return _buildInitialState(theme, colorScheme);
      case _SearchState.listening:
        return _buildListeningState(theme, colorScheme);
      case _SearchState.searching:
        return _buildLoadingState(theme, colorScheme);
      case _SearchState.results:
        return _buildResultsList(theme, colorScheme);
      case _SearchState.empty:
        return _buildEmptyState(theme, colorScheme);
      case _SearchState.error:
        return _buildErrorState(theme, colorScheme);
    }
  }

  /// 初始状态 — 大麦克风按钮 + 提示文字
  Widget _buildInitialState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: colorScheme.primaryContainer,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _startVoiceSearch,
              customBorder: const CircleBorder(),
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                child: Icon(
                  Icons.mic,
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '点击语音搜索',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 语音监听状态 — 脉冲动画麦克风
  Widget _buildListeningState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseMicIndicator(color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            '正在聆听...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '说出歌曲名称',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 加载中状态
  Widget _buildLoadingState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            '搜索中...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索结果列表
  Widget _buildResultsList(ThemeData theme, ColorScheme colorScheme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final song = _results[index];
        return WatchSongTile.fromSong(
          song: song,
          onTap: () => _playSong(song),
        );
      },
    );
  }

  /// 空结果状态
  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 36,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            '未找到结果',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 36,
              color: colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '出错了',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                final keyword = _searchController.text.trim();
                if (keyword.isNotEmpty) {
                  _performSearch(keyword);
                } else {
                  setState(() => _state = _SearchState.initial);
                }
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                '重试',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 语音脉冲动画指示器
// ══════════════════════════════════════════════════════════════════════════════

/// 语音监听时脉冲缩放动画麦克风按钮
class _PulseMicIndicator extends StatefulWidget {
  final Color color;

  const _PulseMicIndicator({required this.color});

  @override
  State<_PulseMicIndicator> createState() => _PulseMicIndicatorState();
}

class _PulseMicIndicatorState extends State<_PulseMicIndicator> {
  double _scale = 1.0;
  bool _growing = true;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) {
        _pulseTimer?.cancel();
        return;
      }
      setState(() {
        _scale = _growing ? 0.85 : 1.0;
        _growing = !_growing;
      });
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Material(
        color: widget.color.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          child: Icon(
            Icons.mic,
            size: 32,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
