import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/audio_settings_provider.dart';
import '../services/equalizer_service.dart';

class AudioEffectsScreen extends StatefulWidget {
  const AudioEffectsScreen({super.key});

  @override
  State<AudioEffectsScreen> createState() => _AudioEffectsScreenState();
}

class _AudioEffectsScreenState extends State<AudioEffectsScreen> {
  double _volume = 1.0;
  List<double> _eqLevels = [];
  bool _eqAvailable = false;
  List<String> _freqLabels = [];

  @override
  void initState() {
    super.initState();
    _initEq();
  }

  Future<void> _initEq() async {
    final eq = EqualizerService.instance;
    await eq.init();
    if (!eq.isAvailable || !mounted) return;
    final bands = eq.numberOfBands;
    final levels = <double>[];
    final labels = <String>[];
    for (int i = 0; i < bands; i++) {
      // 读取当前实际增益（离开页面再进入时保留用户的调节）
      levels.add((await eq.getBandLevel(i))
          .clamp(eq.minBandLevel, eq.maxBandLevel));
      labels.add(_freqLabel(await eq.getCenterFreq(i)));
    }
    if (!mounted) return;
    setState(() {
      _eqLevels = levels;
      _freqLabels = labels;
      _eqAvailable = true;
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
    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)}kHz';
    return '${hz}Hz';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final audioSettings = context.watch<AudioSettingsProvider>();
    final isWide = MediaQuery.of(context).size.width >= 880;
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 音量 ──
        Text('音量', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Slider(
          value: _volume,
          min: 0,
          max: 1,
          divisions: 100,
          label: '${(_volume * 100).round()}%',
          onChanged: (v) {
            setState(() => _volume = v);
            player.setVolume(v);
          },
        ),
        const SizedBox(height: 24),

        // ── 淡入淡出 ──
        Text('淡入淡出', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('开启淡入'),
          subtitle: const Text('切歌时新歌音量从 0 逐渐恢复'),
          value: audioSettings.crossfadeEnabled,
          onChanged: (v) => audioSettings.setCrossfadeEnabled(v),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (audioSettings.crossfadeEnabled) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 16),
              Text('淡入时长', style: Theme.of(context).textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: audioSettings.crossfadeMs.toDouble(),
                  min: 500,
                  max: 5000,
                  divisions: 9,
                  label: '${audioSettings.crossfadeMs}ms',
                  onChanged: (v) => audioSettings.setCrossfadeMs(v.round()),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('${audioSettings.crossfadeMs}ms',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),

        // ── 均衡器 ──
        Row(
          children: [
            Expanded(
              child: Text('均衡器',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (_eqAvailable)
              TextButton(onPressed: _resetEq, child: const Text('重置')),
          ],
        ),
        const SizedBox(height: 8),
        if (_eqAvailable && _freqLabels.length == _eqLevels.length)
          ...List.generate(_eqLevels.length, (i) {
            final band = i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(_freqLabels[i],
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Slider(
                      value: _eqLevels[i],
                      min: EqualizerService.instance.minBandLevel,
                      max: EqualizerService.instance.maxBandLevel,
                      divisions: 48,
                      onChanged: (v) {
                        setState(() => _eqLevels[band] = v);
                        EqualizerService.instance.setBandLevel(band, v);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      // 原生单位是毫贝（mB），1 dB = 100 mB
                      '${(_eqLevels[i] / 100).round()}dB',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          })
        else
          Column(
            children: [
              ...['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'].map((freq) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Text(freq, style: Theme.of(context).textTheme.bodySmall)),
                    const Expanded(
                      // onChanged 为 null → 禁用态，不再给出"能拖但无效"的假交互
                      child: Slider(value: 0, min: -12, max: 12, onChanged: null),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              Text('当前设备不支持系统均衡器，或尚未开始播放（播放一首歌后再进入此页）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline)),
            ],
          ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('音效')),
      body: isWide
          ? Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: body,
            ))
          : body,
    );
  }
}