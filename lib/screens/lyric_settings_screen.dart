// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../ui/app_ui.dart';
import '../ui/components/player_bottom_padding.dart';
import '../widgets/lyric_settings_panel.dart';

/// 独立设置页沿用应用主题；播放器面板保持自己的颜色与布局。
class LyricSettingsScreen extends StatelessWidget {
  const LyricSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
            children: const [
              AppPageHeader(
                padding: EdgeInsets.fromLTRB(0, 20, 0, 24),
                title: '歌词设置',
                subtitle: '让每一句歌词都清晰舒适',
                showBack: true,
              ),
              AppSectionHeader(
                padding: EdgeInsets.only(bottom: 12),
                title: '歌词显示',
              ),
              AppSurface(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LyricSettingsPanel(usePlayerStyle: false),
              ),
              PlayerBottomPadding(),
            ],
          ),
        ),
      ),
    );
  }
}
