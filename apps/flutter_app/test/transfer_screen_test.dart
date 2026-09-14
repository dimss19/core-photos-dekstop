import 'dart:convert';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/screens/transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

MockClient _stub() => MockClient((req) async {
      final p = req.url.path;
      Object out = const {};
      if (p == '/sessions') {
        out = {
          'sessions': [
            {'id': 's1', 'date': '2026-09-13', 'operator': 'Dimas', 'site': 'SiteA'}
          ]
        };
      } else if (p == '/transfer/check') {
        out = {'reachable': true, 'detail': 'writable'};
      } else if (p == '/transfer') {
        out = {'job_id': 'job-5'};
      } else if (p == '/jobs/job-5') {
        out = {'status': 'done', 'progress': 100, 'result': {'copied': ['a.jpg'], 'failed': []}};
      } else if (p == '/transfer/job-5/retry') {
        out = {'job_id': 'job-6'};
      } else if (p == '/jobs/job-6') {
        out = {'status': 'done', 'progress': 100, 'result': {'copied': ['a.jpg'], 'failed': []}};
      }
      return http.Response(jsonEncode(out), 200, headers: {'content-type': 'application/json'});
    });

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: TransferScreen(api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: _stub())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('check + start transfer shows success', (tester) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('dest')), '/tmp/srv');
    await tester.tap(find.text('Check Connection'));
    await tester.pumpAndSettle();
    expect(find.textContaining('reachable'), findsOneWidget);
    await tester.tap(find.text('Dimas @ SiteA'));
    await tester.tap(find.text('Start Transfer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Success'), findsOneWidget);
  });

  testWidgets('retry enabled after transfer', (tester) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('dest')), '/tmp/srv');
    await tester.tap(find.text('Dimas @ SiteA'));
    await tester.tap(find.text('Start Transfer'));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Retry')).enabled, isTrue);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Success'), findsOneWidget);
  });
}
