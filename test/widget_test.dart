import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lstocker/views/home_screen.dart';

void main() {
  testWidgets('Home screen menu is shown', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    expect(find.text('商品登録'), findsOneWidget);
    expect(find.text('在庫登録'), findsOneWidget);
  });
}
