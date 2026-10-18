// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/audio_settings_provider.dart';
import '../providers/player_provider.dart';
import '../services/equalizer_service.dart';
import '../ui/app_ui.dart';
import '../ui/components/player_bottom_padding.dart';
import '../ui/components/settings_slider.dart';

class AudioEffectsScreen extends StatefulWidget {
  const AudioEffectsScreen({super.key});

  @override
  State<AudioEffectsScreen> createState() => _AudioEffectsScreenState();
}

class _AudioEffectsScreenState extends State<AudioEffectsScreen> {
  double _volume = 1.0;
  List<double> _eqLevels = [];
  bool _eqAvailable = false;
  bool _eqLoading = false;
  List<String> _freqLabels = [];

  @override
  void initState() {
    super.initState();
    _initEq();
  }

  Future<void> _initEq() async {
    if (_eqLoading) return;
    setState(() => _eqLoading = true);
    final eq = EqualizerService.instance;
    await eq.init();
    if (!mounted) return;
    if (!eq.isAvailable || eq.minBandLevel >= eq.maxBandLevel) {
      setState(() {
        _eqAvailable = false;
        _eqLoading = false;
      });
      return;
    }
    final levels = <double>[];
    final labels = <String>[];
    for (int i = 0; i < eq.numberOfBands; i++) {
      // 读取实际增益，重新进入时保留已生效的调节。
      levels.add(
          (await eq.getBandLevel(i)).clamp(eq.minBandLevel, eq.maxBandLevel));
      labels.add(_freqLabel(await eq.getCenterFreq(i)));
    }
    if (!mounted) return;
    setState(() {
      _eqLevels = levels;
      _freqLabels = labels;
      _eqAvailable = true;
      _eqLoading = false;
    });
  }

  void _resetEq() {
    final eq = EqualizerService.instance;
    setState(() {
      for (int i = 0; i < _eqLevels.length; i++) {
        _eqLevels[i] = 0.0.clamp(eq.minBandLevel, eq.maxBandLevel);
        eq.setBandLevel(i, _eqLevels[i]);
      }
    });
  }

  String _freqLabel(int hz) {
    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)} kHz';
    return '$hz Hz';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final audioSettings = context.watch<AudioSettingsProvider>();
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
            children: [
              const AppPageHeader(
                padding: EdgeInsets.fromLTRB(0, 20, 0, 24),
                title: '音效',
                subtitle: '调整音量、切歌过渡与均衡器',
                showBack: true,
              ),
              AppSurface(
                child: SettingsSlider(
                  title: '播放音量',
                  valueLabel: '${(_volume * 100).round()}%',
                  value: _volume,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() => _volume = value);
                    player.setVolume(value);
                  },
                ),
              ),
              const AppSectionHeader(
                padding: EdgeInsets.only(top: 28, bottom: 12),
                title: '切歌过渡',
              ),
              AppSurface(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('开启淡入'),
                      subtitle: const Text('切歌时，新歌音量从静音逐渐恢复'),
                      value: audioSettings.crossfadeEnabled,
                      onChanged: audioSettings.setCrossfadeEnabled,
                    ),
                    if (audioSettings.crossfadeEnabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: SettingsSlider(
                          title: '淡入时长',
                          valueLabel:
                              '${(audioSettings.crossfadeMs / 1000).toStringAsFixed(1)} 秒',
                          value: audioSettings.crossfadeMs.toDouble(),
                          min: 500,
                          max: 5000,
                          divisions: 9,
                          onChanged: (value) =>
                              audioSettings.setCrossfadeMs(value.round()),
                        ),
                      ),
                  ],
                ),
              ),
              AppSectionHeader(
                padding: const EdgeInsets.only(top: 28, bottom: 12),
                title: '均衡器',
                actionLabel: '重置',
                actionIcon: Icons.restart_alt_rounded,
                onAction: _eqAvailable && !_eqLoading ? _resetEq : null,
              ),
              if (_eqLoading)
                const AppSurface(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_eqAvailable && _freqLabels.length == _eqLevels.length)
                AppSurface(
                  child: Column(
                    children: List.generate(_eqLevels.length, (index) {
                      return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                        child: SettingsSlider(
                          title: _freqLabels[index],
                          // 系统增益单位为毫贝，100 mB = 1 dB。
                          valueLabel: '${(_eqLevels[index] / 100).round()} dB',
                          value: _eqLevels[index],
                          min: EqualizerService.instance.minBandLevel,
                          max: EqualizerService.instance.maxBandLevel,
                          divisions: 48,
                          onChanged: (value) {
                            setState(() => _eqLevels[index] = value);
                            EqualizerService.instance
                                .setBandLevel(index, value);
                          },
                        ),
                      );
                    }),
                  ),
                )
              else
                AppSurface(
                  padding: EdgeInsets.zero,
                  child: AppEmptyState(
                    icon: Icons.graphic_eq_rounded,
                    title: '均衡器暂不可用',
                    message: '播放一首歌后可重新检测；部分设备不支持系统均衡器',
                    action: OutlinedButton.icon(
                      onPressed: _initEq,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重新检测'),
                    ),
                  ),
                ),
              const PlayerBottomPadding(),
            ],
          ),
        ),
      ),
    );
  }
}
