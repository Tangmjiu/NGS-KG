// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../models/song.dart';
import '../utils/responsive.dart';
import 'song_tile.dart';
import 'song_grid_tile.dart';

/// ✅ 新增适配代码：自适应歌曲列表 —— 平板网格封面墙 / 手机线性列表
///
/// 同一数据源、两种展示方式，通过响应式判断自动切换；
/// 手机端逐字走原有 [SongTile] 线性列表路径。
class AdaptiveSongList extends StatelessWidget {
  final List<Song> songs;
  final void Function(Song song)? onTap;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final Widget? emptyWidget;

  const AdaptiveSongList({
    super.key,
    required this.songs,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return emptyWidget ?? const SizedBox.shrink();
    }

    if (!context.isTablet) {
      return ListView.builder(
        controller: controller,
        padding: padding,
        itemCount: songs.length,
        itemBuilder: (_, i) => SongTile(song: songs[i], onTap: onTap),
      );
    }

    // 平板：网格封面墙（卡片最大宽度 180dp，自适应列数）
    return GridView.builder(
      controller: controller,
      padding: padding,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.75,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: songs.length,
      itemBuilder: (_, i) => SongGridTile(song: songs[i], onTap: onTap),
    );
  }
}
