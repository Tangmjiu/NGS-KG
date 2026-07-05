import 'package:flutter/material.dart';

/// Apple Music-style progress bar with current time and total duration labels.
class PlayerProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final double progress;
  final ValueChanged<double> onSeek;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.progress,
    required this.onSeek,
    this.onDragStart,
    this.onDragEnd,
  });

  String _formatDuration(Duration d) {
    if (d.isNegative) return '0:00';
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  _formatDuration(position),
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: cs.primary,
                    inactiveTrackColor: cs.onSurface.withValues(alpha: 0.24),
                    thumbColor: cs.primary,
                    overlayColor: cs.primary.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChangeStart: (_) => onDragStart?.call(),
                    onChangeEnd: (v) {
                      onSeek(v);
                      onDragEnd?.call();
                    },
                    onChanged: onSeek,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  _formatDuration(duration),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
