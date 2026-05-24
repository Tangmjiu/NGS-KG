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

  // ─── 全部分类 ───

  /// 分类图标映射（tagname → IconData）
  static const Map<String, IconData> categoryIcons = {
    '华语': Icons.language,
    '欧美': Icons.public,
    '日语': Icons.flag,
    '韩语': Icons.flag_outlined,
    '流行': Icons.trending_up,
    '摇滚': Icons.flash_on,
    '民谣': Icons.self_improvement,
    '电子': Icons.track_changes,
    '说唱': Icons.mic,
    '轻音乐': Icons.piano,
    '爵士': Icons.music_note,
    '古风': Icons.history_edu,
    'R&B': Icons.headphones,
    '舞曲': Icons.nightlife,
    '古典': Icons.theater_comedy,
    '儿童': Icons.child_care,
    '校园': Icons.school,
    '纯音乐': Icons.queue_music,
  };

  /// 分类卡片颜色（轮转使用）
  static const List<Color> categoryColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFFD81B60),
    Color(0xFF3949AB),
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

  /// 全部分类网格最多显示项数
  static const int categoryGridMax = 16;

  /// 分类网格最小/最大列数
  static const int categoryGridMinColumns = 3;
  static const int categoryGridMaxColumns = 4;

  // ─── 缓存 TTL ───

  /// 歌单标签缓存时长
  static const Duration tagsCacheTtl = Duration(hours: 24);

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
