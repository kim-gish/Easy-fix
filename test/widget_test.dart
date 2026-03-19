import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const EasyFixApp()); // ← EasyFixApp not MyApp
    expect(find.byType(EasyFixApp), findsOneWidget);
  });
}