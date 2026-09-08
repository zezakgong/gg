import 'package:flutter_test/flutter_test.dart';
import 'package:lohouse/main.dart';

void main() {
  testWidgets('shopping archive home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ShoppingArchiveApp());
    expect(find.text('购物档案'), findsOneWidget);
    expect(find.text('添加第一件商品'), findsOneWidget);
  });
}
