import 'package:flutter/material.dart';
import '../widgets/lyric_settings_panel.dart';

/// 歌词显示设置独立页面（从主题设置进入）。
///
/// 面板本身是为深色播放页设计的（白色文字），因此这里用深色主题包住整页，
/// 而不是只写死一个黑色背景——AppBar、返回键、Switch 等控件也随之协调，
/// 不会在浅色主题下出现"黑底 + 浅色控件"的割裂效果。
class LyricSettingsScreen extends StatelessWidget {
  const LyricSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: base.colorScheme.primary,
        brightness: Brightness.dark,
      ),
      fontFamily: base.textTheme.bodyMedium?.fontFamily,
      pageTransitionsTheme: base.pageTransitionsTheme,
    );
    return Theme(
      data: dark,
      child: Scaffold(
        appBar: AppBar(title: const Text('歌词设置')),
        body: const LyricSettingsPanel(),
      ),
    );
  }
}
