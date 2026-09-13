import 'package:core_photo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard shows title and navigates to session', (tester) async {
    await tester.pumpWidget(const CorePhotoApp(apiBaseUrl: 'http://127.0.0.1:9'));
    await tester.pumpAndSettle();
    expect(find.text('Core Photo'), findsWidgets);
    await tester.tap(find.widgetWithText(ListTile, 'Session'));
    await tester.pumpAndSettle();
    expect(find.text('Operator'), findsOneWidget);
  });
}
