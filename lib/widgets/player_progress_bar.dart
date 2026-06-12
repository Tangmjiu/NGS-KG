import 'package:flutter/material.dart';

/// Apple Music-style progress bar with current time and total duration labels.
///
/// 如果 [climaxPosition] 不为 null，会在进度条轨道上绘制小白点标记。
class PlayerProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final double progress;
  final ValueChanged<double> onSeek;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final int? climaxPosition; // 高潮开始位置（毫秒）

  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.progress,
    required this.onSeek,
    this.onDragStart,
    this.onDragEnd,
    this.climaxPosition,
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
    final totalMs = duration.inMilliseconds;
    final climaxRatio = (totalMs > 0 && climaxPosition != null)
        ? (climaxPosition! / totalMs).clamp(0.0, 1.0)
        : null;

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
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.white60,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    trackShape: _ClimaxTrackShape(climaxRatio: climaxRatio),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: const Color(0x26FFFFFF),
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.white60,
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

/// 自定义轨道绘制：标准圆角矩形轨道 + 高潮标记小白点。
class _ClimaxTrackShape extends SliderTrackShape {
  final double? climaxRatio;

  const _ClimaxTrackShape({this.climaxRatio});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 2.0;
    final thumb = sliderTheme.thumbShape ?? const RoundSliderThumbShape();
    final thumbSize = thumb.getPreferredSize(isEnabled, isDiscrete);
    final thumbRadius = thumbSize.width / 2;
    final trackLeft = offset.dx + thumbRadius;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - thumbRadius * 2;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    bool isDiscrete = false,
    bool isEnabled = false,
    Offset? secondaryOffset,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );

    // 已播放部分（active）— 白色
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );
    context.canvas.drawRect(activeRect, Paint()..color = Colors.white);

    // 未播放部分（inactive）— 半透明白
    final inactiveRect = Rect.fromLTRB(
      thumbCenter.dx,
      trackRect.top,
      trackRect.right,
      trackRect.bottom,
    );
    context.canvas.drawRect(inactiveRect, Paint()..color = Colors.white24);

    // 高潮标记小白点（画在轨道上）
    if (climaxRatio != null) {
      final dotX = trackRect.left + trackRect.width * climaxRatio!;
      final dotY = trackRect.center.dy;
      context.canvas.drawCircle(
        Offset(dotX, dotY),
        3.5,
        Paint()..color = Colors.white,
      );
    }
  }
}
