// SPDX-License-Identifier: MIT
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/widgets/player_controls_bar.dart';
import 'package:ngskg_plus/widgets/player_progress_bar.dart';

void main() {
  testWidgets('播放器控制保留独立语义和点击区，播放状态随操作更新', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var playing = true;
      var previous = 0;
      var next = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            return Center(
              child: PlayerControlsBar(
                isPlaying: playing,
                isLoading: false,
                onPlayPause: () => setState(() => playing = !playing),
                onPrevious: () => previous++,
                onNext: () => next++,
              ),
            );
          }),
        ),
      ));
      for (final label in ['上一首', '暂停', '下一首']) {
        final node = tester.getSemantics(find.byTooltip(label));
        final data = node.getSemanticsData();
        expect(data.label == label || data.tooltip == label, isTrue);
        expect(node.rect.width, greaterThanOrEqualTo(48));
        expect(node.rect.height, greaterThanOrEqualTo(48));
        expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
      }
      await tester.tap(find.byTooltip('上一首'));
      await tester.tap(find.byTooltip('下一首'));
      await tester.tap(find.byTooltip('暂停'));
      await tester.pumpAndSettle();
      expect(previous, 1);
      expect(next, 1);
      expect(playing, isFalse);
      expect(find.bySemanticsLabel('播放'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('减少动效时保留加载提示和 FM 反馈名称，不持续绘制动画', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var disliked = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: PlayerControlsBar(
              isPlaying: false,
              isLoading: true,
              previousLabel: '不喜欢这首歌',
              previousIcon: Icons.heart_broken_outlined,
              onPlayPause: () {},
              onPrevious: () => disliked++,
              onNext: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('播放'))
              .getSemanticsData()
              .value,
          '正在加载');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.byTooltip('不喜欢这首歌'));
      await tester.pumpAndSettle();
      expect(disliked, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('进度条读出播放时间，读屏增加动作能调整进度且保留细轨', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var progress = 0.375;
      final seeks = <double>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            return Center(
              child: PlayerProgressBar(
                position: Duration(milliseconds: (240000 * progress).round()),
                duration: const Duration(minutes: 4),
                progress: progress,
                onSeek: (value) {
                  seeks.add(value);
                  setState(() => progress = value);
                },
              ),
            );
          }),
        ),
      ));
      final node = tester.getSemantics(find.bySemanticsLabel('播放进度'));
      expect(node.getSemanticsData().value, '1分30秒，共4分0秒');
      expect(node.getSemanticsData().hasAction(ui.SemanticsAction.increase),
          isTrue);
      node.owner!.performAction(node.id, ui.SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(seeks, isNotEmpty);
      expect(progress, greaterThan(0.375));
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('播放进度'))
              .getSemanticsData()
              .value,
          isNot('1分30秒，共4分0秒'));
      expect(
          SliderTheme.of(tester.element(find.byType(Slider))).trackHeight, 2);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
