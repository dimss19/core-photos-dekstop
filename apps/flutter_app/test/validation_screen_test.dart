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

  testWidgets('correction edits tray then re-validates', (tester) async {
    var patched = false;
    final stub = MockClient((req) async {
      Object out = const {};
      final p = req.url.path;
      if (p == '/trays/validate') {
        out = patched
            ? {'valid': true, 'status': 'VALID', 'errors': {}}
            : {'valid': false, 'status': 'INVALID', 'errors': {'interval': 'To < From'}};
      } else if (p == '/trays/t1' && req.method == 'GET') {
        out = {
          'tray': {'id': 't1', 'hole_id': 'Core01', 'tray_id': '1', 'interval_from': 20.0, 'interval_to': 10.0, 'rows': 0, 'length': null, 'width': null, 'comments': ''}
        };
      } else if (p == '/trays/t1' && req.method == 'PATCH') {
        patched = true;
        out = {'tray': {'id': 't1', 'validation': null}};
      }
      return http.Response(jsonEncode(out), 200, headers: {'content-type': 'application/json'});
    });
    await tester.pumpWidget(MaterialApp(
      home: ValidationScreen(api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: stub)),
    ));
    await tester.enterText(find.byKey(const Key('tray_id')), 't1');
    await tester.tap(find.text('Validate'));
    await tester.pumpAndSettle();
    expect(find.text('INVALID'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit & Re-validate'));
    await tester.tap(find.text('Edit & Re-validate'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit_comments')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit_interval_to')), '20');
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Correction'));
    await tester.pumpAndSettle();
    expect(find.text('VALID'), findsOneWidget);
    expect(patched, isTrue);
  });
}
