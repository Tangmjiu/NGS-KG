import 'package:flutter/material.dart';

/// 主题资源管理器
///
/// 统一管理所有主题图片资源路径，支持通过 [loadFromTheme] 替换为 ZIP 导入的资源。
class ThemeAssets {
  // ─── 默认资源路径（内置） ───
  static const String _defSthiswrong = 'assets/images/sthiswrong.png';
  static const String _defCodecrash = 'assets/images/codecrash.png';
  static const String _defLoading = 'assets/images/loading.png';
  static const String _defBan = 'assets/images/ban.png';
  static const String _defSupportMe = 'assets/images/supportme.png';
  static const String _defIcon = 'assets/images/icon.png';

  // ─── 当前活动路径（可被 ZIP 主题覆盖） ───
  static String sthiswrong = _defSthiswrong;
  static String codecrash = _defCodecrash;
  static String loading = _defLoading;
  static String ban = _defBan;
  static String supportMe = _defSupportMe;
  static String icon = _defIcon;

  /// 是否有自定义主题资源生效
  static bool get hasCustomAssets => sthiswrong != _defSthiswrong;

  /// 从 LoadedTheme 的 assetFiles 加载自定义资源
  static void loadFromTheme(Map<String, String> assetFiles) {
    if (assetFiles.containsKey('sthiswrong')) sthiswrong = assetFiles['sthiswrong']!;
    if (assetFiles.containsKey('codecrash')) codecrash = assetFiles['codecrash']!;
    if (assetFiles.containsKey('loading')) loading = assetFiles['loading']!;
    if (assetFiles.containsKey('ban')) ban = assetFiles['ban']!;
    if (assetFiles.containsKey('supportme')) supportMe = assetFiles['supportme']!;
    if (assetFiles.containsKey('icon')) icon = assetFiles['icon']!;
  }

  /// 重置为内置默认资源
  static void resetToDefault() {
    sthiswrong = _defSthiswrong;
    codecrash = _defCodecrash;
    loading = _defLoading;
    ban = _defBan;
    supportMe = _defSupportMe;
    icon = _defIcon;
  }
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
    final widget = Image.asset(
      assetPath,
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
