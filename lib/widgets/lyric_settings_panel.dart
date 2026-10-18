// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lyric_settings.dart';
import '../providers/theme_provider.dart';
import '../ui/components/settings_slider.dart';

/// 歌词设置共用表单；默认保持播放器浮层的白色控件。
class LyricSettingsPanel extends StatelessWidget {
  final bool usePlayerStyle;

  const LyricSettingsPanel({super.key, this.usePlayerStyle = true});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ThemeProvider>().lyricSettings;
    return SingleChildScrollView(
      primary: false,
      child: _LyricSettingsForm(
        settings: settings,
        usePlayerStyle: usePlayerStyle,
      ),
    );
  }
}

class _LyricSettingsForm extends StatefulWidget {
  final LyricSettings settings;
  final bool usePlayerStyle;

  const _LyricSettingsForm({
    required this.settings,
    required this.usePlayerStyle,
  });

  @override
  State<_LyricSettingsForm> createState() => _LyricSettingsFormState();
}

class _LyricSettingsFormState extends State<_LyricSettingsForm> {
  late double _fontSize;
  late bool _centerAlign;
  late double _fontWeight;
  late bool _blurEffect;

  @override
  void initState() {
    super.initState();
    _readSettings();
  }

  @override
  void didUpdateWidget(covariant _LyricSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) _readSettings();
  }

  void _readSettings() {
    _fontSize = widget.settings.fontSize.clamp(12, 28);
    _centerAlign = widget.settings.centerAlign;
    _fontWeight = widget.settings.fontWeight.clamp(100, 900);
    _blurEffect = widget.settings.blurEffect;
  }

  void _apply() {
    context.read<ThemeProvider>().setLyricSettings(LyricSettings(
          fontSize: _fontSize,
          centerAlign: _centerAlign,
          fontWeight: _fontWeight,
          blurEffect: _blurEffect,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playerStyle = widget.usePlayerStyle;
    final labelStyle = playerStyle
        ? const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          )
        : theme.textTheme.titleSmall;
    final valueStyle = playerStyle
        ? const TextStyle(fontSize: 14, color: Colors.white60)
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SettingsSlider(
            title: '歌词视图字体大小',
            valueLabel: '${_fontSize.round()}',
            value: _fontSize,
            min: 12,
            max: 28,
            divisions: 16,
            titleStyle: labelStyle,
            valueStyle: valueStyle,
            onChanged: (value) {
              setState(() => _fontSize = value);
              _apply();
            },
          ),
        ),
        Divider(
          color: playerStyle ? Colors.white12 : null,
          height: 1,
          indent: playerStyle ? 0 : 16,
          endIndent: playerStyle ? 0 : 16,
        ),
        _switchRow(
          title: '歌词视图文本居中对齐',
          value: _centerAlign,
          labelStyle: labelStyle,
          onChanged: (value) {
            setState(() => _centerAlign = value);
            _apply();
          },
        ),
        Divider(
          color: playerStyle ? Colors.white12 : null,
          height: 1,
          indent: playerStyle ? 0 : 16,
          endIndent: playerStyle ? 0 : 16,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SettingsSlider(
            title: '字体粗细',
            valueLabel: _weightLabel,
            value: _fontWeight,
            min: 100,
            max: 900,
            divisions: 8,
            titleStyle: labelStyle,
            valueStyle: valueStyle,
            onChanged: (value) {
              setState(() => _fontWeight = value);
              _apply();
            },
          ),
        ),
        Divider(
          color: playerStyle ? Colors.white12 : null,
          height: 1,
          indent: playerStyle ? 0 : 16,
          endIndent: playerStyle ? 0 : 16,
        ),
        _switchRow(
          title: '歌词视图模糊',
          value: _blurEffect,
          labelStyle: labelStyle,
          onChanged: (value) {
            setState(() => _blurEffect = value);
            _apply();
          },
        ),
        const SizedBox(height: 8),
      ],
    );
    if (!playerStyle) return content;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        activeTickMarkColor: Colors.white24,
        inactiveTickMarkColor: Colors.white,
        overlayColor: Colors.white.withValues(alpha: 0.12),
      ),
      child: content,
    );
  }

  Widget _switchRow({
    required String title,
    required bool value,
    required TextStyle? labelStyle,
    required ValueChanged<bool> onChanged,
  }) {
    final playerStyle = widget.usePlayerStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: labelStyle)),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeThumbColor: playerStyle ? Colors.white : null,
            activeTrackColor: playerStyle ? Colors.white38 : null,
            inactiveThumbColor: playerStyle ? Colors.white38 : null,
            inactiveTrackColor: playerStyle ? Colors.white12 : null,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String get _weightLabel {
    if (_fontWeight <= 300) return '细体';
    if (_fontWeight <= 500) return '常规';
    if (_fontWeight <= 700) return '中等';
    return '粗体';
  }
}
