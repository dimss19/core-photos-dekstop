import 'dart:convert';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/screens/review_screen.dart';
import 'package:core_photo/workflow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

MockClient _stub() => MockClient((req) async {
      Object out = const {};
      final p = req.url.path;
      if (p == '/process') {
        out = {'job_id': 'job-9'};
      } else if (p == '/jobs/job-9') {
        out = {'status': 'done', 'result': {'jpg_path': '/tmp/x.jpg'}};
      } else if (p == '/captures/job-1/retake') {
        out = {'job_id': 'job-2'};
      } else if (p == '/jobs/job-2') {
        out = {'status': 'done', 'result': {'raw_path': '/tmp/r2.jpg'}};
      }
      return http.Response(jsonEncode(out), 200, headers: {'content-type': 'application/json'});
    });

Map<String, dynamic> _cap() => {'job_id': 'job-1', 'raw_path': '/tmp/r.jpg', 'tray_id': 't1', 'box': [0, 0]};

WorkflowState _reviewing() {
  final w = WorkflowState();
  w.toTrayInput();
  w.setIntervalValid(true);
  w.toReadyToCapture();
  w.toCapturing();
  w.toReviewing();
  return w;
}

void main() {
  testWidgets('empty capture disables actions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: _stub()),
        workflow: WorkflowState(),
        capture: null,
        onProcessed: (_) {},
      ),
    ));
    expect(find.text('Belum ada hasil capture'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Retake')).enabled, isFalse);
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save')).enabled, isFalse);
  });

  testWidgets('save processes and retake re-captures with double box coordinates', (tester) async {
    var processed = false;
    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: _stub()),
        workflow: _reviewing(),
        capture: const {'job_id': 'job-1', 'raw_path': '/tmp/r.jpg', 'tray_id': 't1', 'box': [0.25, 0.75]},
        onProcessed: (_) => processed = true,
      ),
    ));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(processed, isTrue);
    expect(find.textContaining('TypeError'), findsNothing);
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Retake done'), findsOneWidget);
  });

  testWidgets('save processes and retake re-captures with int box coordinates', (tester) async {
    var processed = false;
    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: _stub()),
        workflow: _reviewing(),
        capture: _cap(),
        onProcessed: (_) => processed = true,
      ),
    ));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(processed, isTrue);
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Retake done'), findsOneWidget);
  });
}
