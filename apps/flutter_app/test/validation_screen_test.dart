import 'dart:convert';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/screens/validation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

MockClient _stub(String status, Map<String, dynamic> errors) => MockClient((req) async {
      return http.Response(jsonEncode({'valid': status == 'VALID', 'status': status, 'errors': errors}), 200,
          headers: {'content-type': 'application/json'});
    });

Future<void> _pump(WidgetTester tester, MockClient stub) async {
  await tester.pumpWidget(MaterialApp(
    home: ValidationScreen(api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: stub)),
  ));
  await tester.enterText(find.byKey(const Key('tray_id')), 't1');
  await tester.tap(find.text('Validate'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('INVALID shows problems', (tester) async {
    await _pump(tester, _stub('INVALID', {'interval': 'To < From'}));
    expect(find.byKey(const Key('status')), findsOneWidget);
    expect(find.text('INVALID'), findsOneWidget);
    expect(find.text('interval: To < From'), findsOneWidget);
  });

  testWidgets('VALID shows green status', (tester) async {
    await _pump(tester, _stub('VALID', {}));
    expect(find.text('VALID'), findsOneWidget);
  });
}
