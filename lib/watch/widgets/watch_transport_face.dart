// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

/// Presentation-only transport deck. The watch shell supplies artwork and insets.
class WatchTransportFace extends StatelessWidget {
  const WatchTransportFace({
    super.key,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.progress,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onLyrics,
    required this.onOptions,
    this.fm = false,
  });

  final String title, subtitle;
  final bool playing, fm;
  final double progress;
  final VoidCallback onPrevious, onToggle, onNext, onLyrics, onOptions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, bounds) {
      final wide = bounds.maxWidth >= 168;
      final controls = [
        _Action(icon: fm ? Icons.thumb_down_outlined : Icons.skip_previous_rounded,
            label: fm ? '不喜欢，跳过' : '上一首', onPressed: onPrevious),
        _Action(icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: playing ? '暂停' : '播放', onPressed: onToggle,
            primary: true, width: wide ? 64 : 48),
        _Action(icon: Icons.skip_next_rounded, label: '下一首', onPressed: onNext),
      ];
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white,
                      fontSize: wide ? 19 : 16, height: 1.08, fontWeight: FontWeight.w700)),
            ),
            if (subtitle.isNotEmpty)
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            FractionallySizedBox(widthFactor: 0.55,
                child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0),
                    semanticsLabel: '播放进度', minHeight: 3,
                    color: colors.primary, backgroundColor: Colors.white24,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Wrap(alignment: WrapAlignment.center, children: controls),
            Wrap(alignment: WrapAlignment.center, children: [
              _Action(icon: Icons.lyrics_outlined, label: '歌词', onPressed: onLyrics),
              _Action(icon: Icons.more_horiz_rounded, label: '更多操作', onPressed: onOptions),
            ]),
          ]),
        ),
      );
    });
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onPressed,
    this.primary = false, this.width = 48});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(width: width, height: 48, child: IconButton(
      onPressed: onPressed, tooltip: label,
      style: IconButton.styleFrom(
        shape: const StadiumBorder(), padding: EdgeInsets.zero,
        backgroundColor: primary ? cs.primary : Colors.transparent,
        foregroundColor: primary ? cs.onPrimary : Colors.white,
      ),
      icon: Icon(icon, size: primary ? 32 : 23),
    ));
  }
}

@Preview(name: '紧凑圆屏 · 192dp', size: Size(192, 192), brightness: Brightness.dark)
@Preview(name: '大圆屏 · 225dp', size: Size(225, 225), brightness: Brightness.dark)
Widget transportPreview() => LayoutBuilder(builder: (context, bounds) => ClipOval(
  child: Material(color: Colors.black, child: Padding(
    padding: EdgeInsets.all(bounds.biggest.shortestSide * 0.12),
    child: WatchTransportFace(title: '夜空中最亮的星', subtitle: '逃跑计划',
        playing: true, progress: 0.42, onPrevious: () {}, onToggle: () {},
        onNext: () {}, onLyrics: () {}, onOptions: () {}),
  )),
));
