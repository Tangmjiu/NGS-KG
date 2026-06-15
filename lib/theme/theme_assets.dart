import 'dart:io';
import 'package:flutter/material.dart';
import '../models/theme_pack.dart';

/// 主题资源管理器
///
/// 统一管理所有主题图片资源路径，支持通过 [loadFromThemePack] 替换。
class ThemeAssets {
  // ─── 默认资源路径（内置） ───
  static const String _defSthiswrong = 'assets/images/sthiswrong.png';
  static const String _defCodecrash = 'assets/images/codecrash.png';
  static const String _defLoading = 'assets/images/loading.png';
  static const String _defBan = 'assets/images/ban.png';
  static const String _defSupportMe = 'assets/images/supportme.png';
  static const String _defIcon = 'assets/images/icon.png';

  // ─── 当前活动路径（可被主题包覆盖） ───
  static String sthiswrong = _defSthiswrong;
  static String codecrash = _defCodecrash;
  static String loading = _defLoading;
  static String ban = _defBan;
  static String supportMe = _defSupportMe;
  static String icon = _defIcon;

  // ─── 占位图（主题包可覆盖） ───
  static String albumPlaceholder = '';
  static String playlistPlaceholder = '';
  static String artistPlaceholder = '';
  static String playerBg = '';

  /// 是否有自定义主题资源生效
  static bool get hasCustomAssets => sthiswrong != _defSthiswrong;

  /// 从 ThemePack 加载资源
  static void loadFromThemePack(ThemePack pack) {
    final files = pack.assetFiles;
    if (files == null) return;

    if (files.containsKey('sthiswrong')) sthiswrong = files['sthiswrong']!;
    if (files.containsKey('codecrash')) codecrash = files['codecrash']!;
    if (files.containsKey('loading')) loading = files['loading']!;
    if (files.containsKey('ban')) ban = files['ban']!;
    if (files.containsKey('supportme')) supportMe = files['supportme']!;
    if (files.containsKey('icon')) icon = files['icon']!;
    if (files.containsKey('album_placeholder')) albumPlaceholder = files['album_placeholder']!;
    if (files.containsKey('playlist_placeholder')) playlistPlaceholder = files['playlist_placeholder']!;
    if (files.containsKey('artist_placeholder')) artistPlaceholder = files['artist_placeholder']!;

    if (pack.playerBgPath != null) playerBg = pack.playerBgPath!;
  }

  /// 重置为内置默认资源
  static void resetToDefault() {
    sthiswrong = _defSthiswrong;
    codecrash = _defCodecrash;
    loading = _defLoading;
    ban = _defBan;
    supportMe = _defSupportMe;
    icon = _defIcon;
    albumPlaceholder = '';
    playlistPlaceholder = '';
    artistPlaceholder = '';
    playerBg = '';
  }
}

// ─── Helper 组件工厂 ───

/// 专辑封面加载失败时的占位图
Widget albumPlaceholderWidget({double size = 48, Color? color}) =>
    _themedPlaceholder(ThemeAssets.albumPlaceholder, Icons.album, size: size, color: color);

/// 歌单封面加载失败时的占位图
Widget playlistPlaceholderWidget({double size = 48, Color? color}) =>
    _themedPlaceholder(ThemeAssets.playlistPlaceholder, Icons.playlist_play, size: size, color: color);

/// 歌手头像加载失败时的占位图
Widget artistPlaceholderWidget({double size = 48, Color? color}) =>
    _themedPlaceholder(ThemeAssets.artistPlaceholder, Icons.person, size: size, color: color);

/// 通用占位图：有自定义路径则显示图片，否则回退到 icon
Widget _themedPlaceholder(String assetPath, IconData fallbackIcon,
    {double size = 48, Color? color}) {
  if (assetPath.isNotEmpty) {
    final widget = assetPath.startsWith('assets/')
        ? Image.asset(assetPath, width: size, height: size, fit: BoxFit.cover)
        : Image.file(File(assetPath), width: size, height: size, fit: BoxFit.cover);
    return widget;
  }
  return Icon(fallbackIcon, size: size * 0.7, color: color);
}

/// 主题图片组件
class ThemeImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;

  const ThemeImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final widget = assetPath.startsWith('assets/')
        ? Image.asset(
            assetPath,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          )
        : Image.file(
            File(assetPath),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );

    if (color != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
        child: widget,
      );
    }
    return widget;
  }
}
