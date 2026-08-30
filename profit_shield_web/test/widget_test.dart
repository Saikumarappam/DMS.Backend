import 'package:flutter_test/flutter_test.dart';
import 'package:profit_shield_web/main.dart';

void main() {
  testWidgets('App boots to login', (WidgetTester tester) async {
    await tester.pumpWidget(const ProfitShieldApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ProfitShield'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
