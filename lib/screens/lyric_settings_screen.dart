import 'package:flutter/material.dart';
import '../widgets/lyric_settings_panel.dart';

/// 歌词显示设置独立页面（从主题设置进入）。
class LyricSettingsScreen extends StatelessWidget {
  const LyricSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('歌词设置'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const LyricSettingsPanel(),
    );
  }
}
