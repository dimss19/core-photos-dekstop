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

  testWidgets('dashboard navigates to correct screens with aligned indices', (tester) async {
    await tester.pumpWidget(const CorePhotoApp(apiBaseUrl: 'http://127.0.0.1:9'));
    await tester.pumpAndSettle();

    // Tap Validation -> must show Validation screen
    await tester.tap(find.widgetWithText(ListTile, 'Validation'));
    await tester.pumpAndSettle();
    expect(find.text('Validation'), findsWidgets);
    expect(find.byKey(const Key('tray_id')), findsOneWidget);

    // Tap bottom nav back to Home
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // Tap Settings -> must show Settings screen
    await tester.tap(find.widgetWithText(ListTile, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Server URL'), findsOneWidget);
  });
}
