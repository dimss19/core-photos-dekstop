// apps/flutter_app/test/capture_screen_test.dart
import 'package:core_photo/screens/capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture screen shows header and controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CaptureScreen()));
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Live View'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('Zoom'), findsOneWidget);
    expect(find.text('Take Picture'), findsOneWidget);
  });
}
