import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/lyric_settings.dart';

/// 歌词显示设置面板 — 可嵌入 BottomSheet 或独立页面。
class LyricSettingsPanel extends StatelessWidget {
  const LyricSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final settings = theme.lyricSettings;
    return _LyricSettingsForm(settings: settings);
  }
}

class _LyricSettingsForm extends StatefulWidget {
  final LyricSettings settings;
  const _LyricSettingsForm({required this.settings});

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
    _fontSize = widget.settings.fontSize;
    _centerAlign = widget.settings.centerAlign;
    _fontWeight = widget.settings.fontWeight;
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 歌词视图字体大小 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Text('歌词视图字体大小',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  )),
              const Spacer(),
              Text('${_fontSize.round()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: cs.primary,
              inactiveTrackColor: cs.onSurface.withValues(alpha: 0.24),
              thumbColor: cs.primary,
              overlayColor: cs.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _fontSize,
              min: 12,
              max: 28,
              divisions: 16,
              onChanged: (v) {
                setState(() => _fontSize = v);
                _apply();
              },
            ),
          ),
        ),

        Divider(color: cs.onSurface.withValues(alpha: 0.12), height: 1),

        // ── 歌词视图文本居中对齐 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text('歌词视图文本居中对齐',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    )),
              ),
              Switch(
                value: _centerAlign,
                activeThumbColor: cs.primary,
                activeTrackColor: cs.primary.withValues(alpha: 0.38),
                inactiveThumbColor: cs.onSurface.withValues(alpha: 0.38),
                inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
                onChanged: (v) {
                  setState(() => _centerAlign = v);
                  _apply();
                },
              ),
            ],
          ),
        ),

        Divider(color: cs.onSurface.withValues(alpha: 0.12), height: 1),

        // ── 字体粗细 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text('字体粗细',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  )),
              const Spacer(),
              Text(_weightLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: cs.primary,
              inactiveTrackColor: cs.onSurface.withValues(alpha: 0.24),
              thumbColor: cs.primary,
              overlayColor: cs.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _fontWeight,
              min: 100,
              max: 900,
              divisions: 8,
              onChanged: (v) {
                setState(() => _fontWeight = v);
                _apply();
              },
            ),
          ),
        ),

        Divider(color: cs.onSurface.withValues(alpha: 0.12), height: 1),

        // ── 歌词视图模糊 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text('歌词视图模糊',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    )),
              ),
              Switch(
                value: _blurEffect,
                activeThumbColor: cs.primary,
                activeTrackColor: cs.primary.withValues(alpha: 0.38),
                inactiveThumbColor: cs.onSurface.withValues(alpha: 0.38),
                inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
                onChanged: (v) {
                  setState(() => _blurEffect = v);
                  _apply();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String get _weightLabel {
    if (_fontWeight <= 300) return '细体';
    if (_fontWeight <= 500) return '常规';
    if (_fontWeight <= 700) return '中等';
    return '粗体';
  }
}
