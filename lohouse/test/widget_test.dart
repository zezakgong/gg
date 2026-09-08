import 'package:flutter_test/flutter_test.dart';
import 'package:lohouse/main.dart';

void main() {
  testWidgets('guoguo kitchen home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const GuoguoKitchenApp());
    expect(find.text('果果厨房'), findsOneWidget);
    expect(find.text('创建第一份菜谱'), findsOneWidget);
  });
}
