import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_route_wrapper.dart';

class AudioEffectsScreen extends StatefulWidget {
  const AudioEffectsScreen({super.key});

  @override
  State<AudioEffectsScreen> createState() => _AudioEffectsScreenState();
}

class _AudioEffectsScreenState extends State<AudioEffectsScreen> {
  double _volume = 1.0;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      mobile: (_) => _buildMobile(),
      tablet: (_) => _buildMobile(),
      desktop: (_) => _buildDesktop(),
    );
  }

  Widget _buildMobile() {
    final isWide = MediaQuery.of(context).size.width >= 880;
    return Scaffold(
      appBar: AppBar(title: const Text('音效')),
      body: isWide
          ? Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _buildBody(),
            ))
          : _buildBody(),
    );
  }

  Widget _buildDesktop() {
    return DesktopRouteWrapper(
      title: '音效',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final player = context.read<PlayerProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        Text('播放速度', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Slider(
          value: _speed,
          min: 0.5,
          max: 2.0,
          divisions: 30,
          label: '${_speed.toStringAsFixed(1)}x',
          onChanged: (v) {
            setState(() => _speed = v);
            player.setSpeed(v);
          },
        ),
        const SizedBox(height: 24),
        Text('均衡器', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'].map((freq) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(width: 60, child: Text(freq, style: Theme.of(context).textTheme.bodySmall)),
              Expanded(
                child: Slider(
                  value: 0,
                  min: -12,
                  max: 12,
                  divisions: 24,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 16),
        Text('均衡器需要设备支持，当前版本暂不可调',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}
