// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Apple Music-style progress bar with current time and total duration labels.
///
/// Rhythm 风格增强（enhanced seeking）：
///   - 拖拽时 thumb 放大、轨道微增，松手回弹
///   - 拖拽中显示目标时间气泡（跟随 thumb 位置）
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

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  bool _dragging = false;
  double _dragValue = 0.0;

  String _formatDuration(Duration d) {
    if (d.isNegative) return '0:00';
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 拖动中的目标时间
  Duration get _dragTarget => Duration(
        milliseconds: (_dragValue * widget.duration.inMilliseconds).round(),
      );

  @override
  Widget build(BuildContext context) {
    final value = _dragging
        ? _dragValue
        : (widget.progress.isFinite ? widget.progress.clamp(0.0, 1.0) : 0.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40, // 气泡 + 滑条 的固定高度，避免拖动时布局跳动
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        _formatDuration(
                            _dragging ? _dragTarget : widget.position),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white60,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: _dragging ? 3 : 2,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: _dragging ? 9 : 6,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: _dragging ? 22 : 16,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                          overlayColor: const Color(0x26FFFFFF),
                        ),
                        child: Slider(
                          value: value,
                          onChangeStart: (_) {
                            setState(() => _dragging = true);
                            widget.onDragStart?.call();
                          },
                          onChangeEnd: (v) {
                            setState(() => _dragging = false);
                            widget.onSeek(v);
                            widget.onDragEnd?.call();
                          },
                          onChanged: (v) {
                            setState(() => _dragValue = v);
                            widget.onSeek(v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text(
                        _formatDuration(widget.duration),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white60,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── 拖拽目标时间气泡 ──
              Positioned(
                top: -26,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _dragging ? 1.0 : 0.0,
                    duration: AppMotion.dShort3,
                    curve: AppMotion.emphasized,
                    child: AnimatedScale(
                      scale: _dragging ? 1.0 : 0.6,
                      duration: AppMotion.dShort3,
                      curve: Curves.easeOutBack,
                      child: Align(
                        alignment: Alignment(_dragValue * 2 - 1, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: AppShape.full,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _formatDuration(_dragTarget),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
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
