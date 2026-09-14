import 'dart:convert';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/screens/browser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

MockClient _stub() => MockClient((req) async {
      Object out = const {};
      if (req.url.path == '/photos') {
        out = {
          'photos': [
            {'id': 'p1', 'filename': 'Core01_1_000.00_2.60.jpg', 'hole_id': 'Core01', 'interval_from': 0.0, 'interval_to': 2.6},
            {'id': 'p2', 'filename': 'Core02_1_000.00_3.00.jpg', 'hole_id': 'Core02', 'interval_from': 0.0, 'interval_to': 3.0},
          ]
        };
      }
      return http.Response(jsonEncode(out), 200, headers: {'content-type': 'application/json'});
    });

void main() {
  testWidgets('browser lists photos and filters by drillhole', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BrowserScreen(api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: _stub())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Core01_1_000.00_2.60.jpg'), findsOneWidget);
    expect(find.text('Core02_1_000.00_3.00.jpg'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search')), 'core02');
    await tester.pump();
    expect(find.text('Core01_1_000.00_2.60.jpg'), findsNothing);
    expect(find.text('Core02_1_000.00_3.00.jpg'), findsOneWidget);
    await tester.tap(find.text('Core02_1_000.00_3.00.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('Tutup'), findsOneWidget);
  });
}
