import 'package:flutter/material.dart';

/// Discover 页面常量 — 从 discover_screen.dart 提取，避免魔法值散落
class DiscoverConstants {
  DiscoverConstants._();

  // ─── 快捷入口 ───

  /// 4 个快捷操作卡片的渐变配色
  static const List<List<Color>> actionGradients = [
    [Color(0xFFFF6B35), Color(0xFFF7C948)], // 排行榜 → 橙金
    [Color(0xFF7C4DFF), Color(0xFF448AFF)], // 电台 → 紫蓝
    [Color(0xFF00BFA5), Color(0xFF69F0AE)], // 每日推荐 → 青绿
    [Color(0xFFFF4081), Color(0xFFFF6E40)], // 新歌首发 → 粉橙
  ];

  // ─── 数据加载限制 ───

  /// 推荐歌单项数量
  static const int playlistLimit = 10;

  /// 热门榜单项数量
  static const int rankLimit = 4;

  /// 新歌速递项数量
  static const int topSongsLimit = 10;

  /// 新碟上架页大小
  static const int topAlbumsPageSize = 10;

  /// 场景音乐项数量
  static const int sceneLimit = 8;

  /// 编辑精选项数量
  static const int ipLimit = 6;

  /// 电台推荐项数量
  static const int fmLimit = 6;

  /// 推荐歌单更多页面每页数量
  static const int recommendedPlaylistPageSize = 30;

  // ─── 缓存 TTL ───

  /// 排行榜缓存时长
  static const Duration rankCacheTtl = Duration(minutes: 30);

  /// 新碟缓存时长
  static const Duration albumCacheTtl = Duration(minutes: 15);

  /// 场景列表缓存时长
  static const Duration sceneCacheTtl = Duration(minutes: 30);

  /// 编辑精选缓存时长
  static const Duration ipCacheTtl = Duration(minutes: 30);

  /// 电台推荐缓存时长
  static const Duration fmCacheTtl = Duration(minutes: 30);

  // ─── 图片尺寸 ───

  static const String bannerImageSize = '720';
  static const String ipImageSize = '480';
  static const String songCoverSize = '240';
}
