// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表搜索页 — 键盘输入搜索，进入自动唤起输入法
// 圆屏/方屏自适应，结果列表适配圆屏安全边距

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../services/music_service.dart';
import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';

enum _SearchState { initial, searching, results, empty, error }

/// 手表搜索页。
///
/// - 进入后自动唤起输入法
/// - 输入 300ms 防抖后自动搜索
/// - 结果列表适配圆屏安全边距，表冠/触摸可滚动
class WatchSearchScreen extends StatefulWidget {
  const WatchSearchScreen({super.key});

  @override
  State<WatchSearchScreen> createState() => _WatchSearchScreenState();
}

class _WatchSearchScreenState extends State<WatchSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<Song> _results = [];
  _SearchState _state = _SearchState.initial;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    // 进入页面后自动唤起输入法
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

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

  Future<void> _performSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    setState(() {
      _state = _SearchState.searching;
      _errorMessage = null;
    });
    try {
      final songs =
          await context.read<MusicService>().search(keyword.trim(), limit: 20);
      if (!mounted) return;
      setState(() {
        if (songs.isEmpty) {
          _results = [];
          _state = _SearchState.empty;
        } else {
          _results = songs;
          _state = _SearchState.results;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _state = _SearchState.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final layout = WatchLayout.of(context);
    final isRound = layout.isRound;
    final horizontal = isRound ? layout.contentHorizontal : 10.0;

    return Semantics(
      container: true,
      label: '音乐搜索',
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // ── 搜索栏 ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                layout.topInset,
                horizontal,
                4,
              ),
              child: _SearchBar(
                controller: _searchController,
                focusNode: _focusNode,
                layout: layout,
                theme: theme,
                cs: cs,
                onClear: () {
                  _searchController.clear();
                  // 保留焦点方便连续搜索
                  _focusNode.requestFocus();
                },
                onSubmitted: (value) {
                  _debounceTimer?.cancel();
                  _performSearch(value);
                },
              ),
            ),
            // ── 结果区 ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal * 0.5),
                child: _buildContent(theme, cs, layout),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme cs, WatchLayout layout) {
    return switch (_state) {
      _SearchState.initial => _StateView(
          icon: Icons.search_rounded,
          iconSize: layout.diameter * 0.16,
          iconColor: cs.primary.withValues(alpha: 0.5),
          text: '输入歌名或歌手',
          layout: layout,
          cs: cs,
        ),
      _SearchState.searching => _StateView(
          icon: null,
          customChild: SizedBox(
            width: layout.touchTarget,
            height: layout.touchTarget,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
          text: '搜索中…',
          layout: layout,
          cs: cs,
        ),
      _SearchState.results => _buildResults(layout),
      _SearchState.empty => _StateView(
          icon: Icons.search_off_rounded,
          iconSize: 30,
          iconColor: cs.onSurface.withValues(alpha: 0.3),
          text: '未找到结果',
          layout: layout,
          cs: cs,
        ),
      _SearchState.error => _buildError(theme, cs, layout),
    };
  }

  Widget _buildResults(WatchLayout layout) {
    return WatchScrollList(
      itemCount: _results.length,
      itemExtent: 52 * layout.scale,
      topPadding: 4,
      bottomPadding: layout.bottomInset,
      itemBuilder: (context, index) {
        final song = _results[index];
        return Semantics(
          button: true,
          label: '${song.name}，${song.artistDisplay}',
          child: WatchSongTile.fromSong(
            song: song,
            onTap: () {
              WatchMotion.tap();
              context.read<PlayerProvider>().playSong(song, playlist: _results);
            },
          ),
        );
      },
    );
  }

  Widget _buildError(ThemeData theme, ColorScheme cs, WatchLayout layout) {
    return _StateView(
      icon: Icons.error_outline_rounded,
      iconSize: 30,
      iconColor: cs.error,
      text: _errorMessage ?? '出错了',
      layout: layout,
      cs: cs,
      action: TextButton.icon(
        onPressed: () {
          final keyword = _searchController.text.trim();
          if (keyword.isNotEmpty) {
            _performSearch(keyword);
          } else {
            setState(() => _state = _SearchState.initial);
          }
        },
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('重试'),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  搜索栏组件
// ═══════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final WatchLayout layout;
  final ThemeData theme;
  final ColorScheme cs;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.layout,
    required this.theme,
    required this.cs,
    required this.onClear,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: layout.touchTarget,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13 * layout.scale,
        ),
        decoration: InputDecoration(
          hintText: '搜索音乐',
          hintStyle: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.45),
            fontSize: 12 * layout.scale,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18 * layout.scale,
            color: cs.onSurfaceVariant,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: 32 * layout.scale,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? Semantics(
                  button: true,
                  label: '清除',
                  child: IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 16 * layout.scale,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                )
              : null,
          filled: true,
          fillColor: cs.surfaceContainerHigh,
          isDense: true,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(999)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            borderSide: BorderSide(color: cs.primary, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 10 * layout.scale,
            vertical: 0,
          ),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  状态视图（初始/加载/空/错误共用）
// ═══════════════════════════════════════════════════════

class _StateView extends StatelessWidget {
  final IconData? icon;
  final double iconSize;
  final Color iconColor;
  final String text;
  final Widget? customChild;
  final Widget? action;
  final WatchLayout layout;
  final ColorScheme cs;

  const _StateView({
    this.icon,
    this.iconSize = 28,
    this.iconColor = Colors.white38,
    required this.text,
    this.customChild,
    this.action,
    required this.layout,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: layout.contentHorizontal,
          vertical: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (customChild != null)
              customChild!
            else if (icon != null)
              Icon(icon, size: iconSize, color: iconColor),
            const SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 12 * layout.scale,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
