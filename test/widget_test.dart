import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/main.dart';

void main() {
  testWidgets('App should render home page', (WidgetTester tester) async {
    await tester.pumpWidget(const NGSKGApp());
    expect(find.text('NGS-KG+'), findsWidgets);
  });
}
