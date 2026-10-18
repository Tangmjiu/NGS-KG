// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/theme_pack.dart';
import 'package:ngskg_plus/theme/app_theme.dart';

const _detailMarker = ValueKey('detail-marker');

/// 使用框架官方预测性返回测试相同的系统消息入口。
Future<Object?> _systemBack(
  WidgetTester tester,
  String method, {
  double? progress,
}) async {
  const codec = StandardMethodCodec();
  final response =
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    codec.encodeMethodCall(MethodCall(
      method,
      progress == null
          ? null
          : <String, Object>{
              'touchOffset': <double>[5 + 300 * progress, 300],
              'progress': progress,
              'swipeEdge': 0,
            },
    )),
    null,
  );
  return response == null ? null : codec.decodeEnvelope(response);
}

class _DetailPage extends StatefulWidget {
  const _DetailPage();

  @override
  State<_DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<_DetailPage> {
  int likes = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('歌曲详情', key: _detailMarker),
            TextButton(
              onPressed: () => setState(() => likes++),
              child: Text('喜欢 $likes'),
            ),
          ],
        ),
      );
}

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets(
      reduceMotion
          ? 'Android减少动效时返回预览保持静止，取消保留详情、提交正常返回'
          : 'Android预测性返回实际预览下层页面，取消保留详情状态、提交才出栈',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.build(ngsNagisa.lightScheme!, ngsNagisa),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          routes: {
            '/': (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/detail'),
                      child: const Text('打开详情'),
                    ),
                  ),
                ),
            '/detail': (_) => const _DetailPage(),
          },
        ));
        await tester.tap(find.text('打开详情'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('喜欢 0'));
        await tester.pumpAndSettle();
        final initialOffset = tester.getTopLeft(find.byKey(_detailMarker));
        expect(navigator.currentState!.canPop(), isTrue);

        final firstGesture =
            await _systemBack(tester, 'startBackGesture', progress: 0);
        await tester.pump();
        expect(firstGesture, !reduceMotion);
        expect(navigator.currentState!.userGestureInProgress, !reduceMotion);
        await _systemBack(tester, 'updateBackGestureProgress', progress: 0.4);
        await tester.pumpAndSettle();
        final previewOffset = tester.getTopLeft(find.byKey(_detailMarker));
        if (reduceMotion) {
          expect(previewOffset, initialOffset);
          expect(find.text('打开详情'), findsNothing);
        } else {
          expect(previewOffset.dx, greaterThan(initialOffset.dx));
          expect(find.text('打开详情'), findsOneWidget);
        }
        expect(find.text('喜欢 1'), findsOneWidget);

        await _systemBack(tester, 'cancelBackGesture');
        await tester.pumpAndSettle();
        expect(find.text('喜欢 1'), findsOneWidget);
        expect(find.text('打开详情'), findsNothing);
        expect(tester.getTopLeft(find.byKey(_detailMarker)), initialOffset);
        expect(navigator.currentState!.canPop(), isTrue);
        expect(navigator.currentState!.userGestureInProgress, isFalse);

        final secondGesture =
            await _systemBack(tester, 'startBackGesture', progress: 0);
        await tester.pump();
        expect(secondGesture, !reduceMotion);
        await _systemBack(tester, 'updateBackGestureProgress', progress: 0.65);
        await tester.pumpAndSettle();
        await _systemBack(tester, 'commitBackGesture');
        await tester.pumpAndSettle();
        expect(find.text('歌曲详情'), findsNothing);
        expect(find.text('喜欢 1'), findsNothing);
        expect(find.text('打开详情').hitTestable(), findsOneWidget);
        expect(navigator.currentState!.canPop(), isFalse);
        expect(navigator.currentState!.userGestureInProgress, isFalse);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
