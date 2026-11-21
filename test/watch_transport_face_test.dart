// 手表播放器控制区的布局回归测试：
// 小圆屏上按钮不能被压缩到 48dp 以下，也不能溢出。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/watch/widgets/watch_transport_face.dart';

Widget _host({required double side, bool fm = false, String title = '夜空中最亮的星'}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: side,
          height: side,
          child: WatchTransportFace(
            title: title,
            subtitle: '逃跑计划',
            playing: true,
            progress: 0.42,
            fm: fm,
            onPrevious: () {},
            onToggle: () {},
            onNext: () {},
            onLyrics: () {},
            onOptions: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final side in <double>[192, 210, 225]) {
    testWidgets('${side.toInt()}dp 圆屏：不溢出且按钮不小于 48dp', (tester) async {
      tester.view.physicalSize = Size(side * 3, side * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(side: side));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final buttons = find.byType(IconButton);
      expect(buttons, findsNWidgets(5));

      for (final element in buttons.evaluate()) {
        final size = element.size;
        expect(size, isNotNull);
        expect(size!.width, greaterThanOrEqualTo(48.0),
            reason: '按钮宽度被压缩到 ${size.width}');
        expect(size.height, greaterThanOrEqualTo(48.0),
            reason: '按钮高度被压缩到 ${size.height}');
      }
    });
  }

  testWidgets('超长歌名不溢出', (tester) async {
    tester.view.physicalSize = const Size(192 * 3, 192 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(
      side: 192,
      title: '一首名字特别特别长而且还要换行的歌曲标题用来测试截断行为是否正确',
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('FM 模式下上一首改名为不喜欢', (tester) async {
    await tester.pumpWidget(_host(side: 225, fm: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip('不喜欢，跳过'), findsOneWidget);
    expect(find.byTooltip('上一首'), findsNothing);
  });
}
