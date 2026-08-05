import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Apple Music 风格大进度条
///
/// 特性规范：
/// 1. **弹性变焦滑块 (Elastic Thumb)**：拖动滑块时，滑块半径平滑放大为 `11`，松开后弹性收缩为 `6`。
/// 2. **气泡式悬浮时间提示 (Tooltip Indicator)**：拖拽时上方实时弹出矩形悬浮气泡，显示当前所处的歌曲时间（如 `03:45`）。
/// 3. **物理阻尼反馈 (Tactile Ticks)**：当用户手指滑动进度条时，每跨越一秒时间，设备会产生轻微的感官物理小振动 (`selectionClick`)。
class PlayerProgressBar extends StatefulWidget {
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

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _thumbController;
  late Animation<double> _thumbAnimation;
  int _lastVibratedSec = -1;

  @override
  void initState() {
    super.initState();
    _thumbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _thumbAnimation = CurvedAnimation(
      parent: _thumbController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _thumbController.dispose();
    super.dispose();
  }

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
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  _formatDuration(widget.position),
                  style: tt.labelSmall?.copyWith(
                    color: Colors.white60,
                    fontFamily: 'HarmonyOS Sans',
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedBuilder(
                  animation: _thumbAnimation,
                  builder: (context, child) {
                    final double radius =
                        lerpDouble(6, 11, _thumbAnimation.value)!;
                    return SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3.5,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: radius,
                          pressedElevation: 3,
                        ),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 20),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: const Color(0x1BFFFFFF),
                        // 气泡指示器样式
                        showValueIndicator: ShowValueIndicator.onDrag,
                        valueIndicatorColor: cs.primaryContainer,
                        valueIndicatorTextStyle: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        valueIndicatorShape:
                            const RectangularSliderValueIndicatorShape(),
                      ),
                      child: Slider(
                        value: widget.progress.clamp(0.0, 1.0),
                        label: _formatDuration(widget.position),
                        onChangeStart: (_) {
                          _thumbController.forward();
                          widget.onDragStart?.call();
                          HapticFeedback.lightImpact();
                        },
                        onChangeEnd: (v) {
                          widget.onSeek(v);
                          widget.onDragEnd?.call();
                          _thumbController.reverse();
                          HapticFeedback.mediumImpact();
                        },
                        onChanged: (v) {
                          widget.onSeek(v);
                          // 物理触感反馈：每滑动改变 1 秒产生一次微小滴答感
                          final currentSec =
                              (v * widget.duration.inSeconds).round();
                          if (currentSec != _lastVibratedSec) {
                            HapticFeedback.selectionClick();
                            _lastVibratedSec = currentSec;
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                child: Text(
                  _formatDuration(widget.duration),
                  textAlign: TextAlign.end,
                  style: tt.labelSmall?.copyWith(
                    color: Colors.white60,
                    fontFamily: 'HarmonyOS Sans',
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w500,
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
