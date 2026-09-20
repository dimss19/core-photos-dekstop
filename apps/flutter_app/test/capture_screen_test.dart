import 'dart:convert';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/screens/capture_screen.dart';
import 'package:core_photo/workflow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

MockClient _stub() => MockClient((req) async {
      Object out = const {};
      final p = req.url.path;
      if (p == '/trays') {
        out = {'tray': {'id': 't1'}};
      } else if (p == '/captures') {
        out = {'job_id': 'job-1'};
      } else if (p == '/jobs/job-1') {
        out = {'status': 'done', 'result': {'raw_path': '/tmp/r.jpg', 'md5': 'x'}};
      }
      return http.Response(jsonEncode(out), 200, headers: {'content-type': 'application/json'});
    });

Widget _screen(void Function(Map<String, dynamic>) onCaptured) => MaterialApp(
      home: CaptureScreen(
        api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: _stub()),
        workflow: WorkflowState(),
        sessionId: 's1',
        onCaptured: onCaptured,
      ),
    );

Future<void> _fillValid(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('tray_hole')), 'Core01');
  await tester.enterText(find.byKey(const Key('tray_tray')), '1');
  await tester.enterText(find.byKey(const Key('tray_from')), '0');
  await tester.enterText(find.byKey(const Key('tray_to')), '2.6');
  await tester.pump();
}

void main() {
  testWidgets('invalid interval warns and disables capture', (tester) async {
    var captured = false;
    await tester.pumpWidget(_screen((_) => captured = true));
    await tester.enterText(find.byKey(const Key('tray_hole')), 'Core01');
    await tester.enterText(find.byKey(const Key('tray_tray')), '1');
    await tester.enterText(find.byKey(const Key('tray_from')), '20');
    await tester.enterText(find.byKey(const Key('tray_to')), '10');
    await tester.pump();
    expect(find.byKey(const Key('warning')), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('capture'))).enabled, isFalse);
    expect(captured, isFalse);
  });

  testWidgets('valid tray enables capture and reports result', (tester) async {
    Map<String, dynamic>? got;
    await tester.pumpWidget(_screen((c) => got = c));
    await _fillValid(tester);
    await tester.tapAt(tester.getCenter(find.byKey(const Key('liveview'))));
    await tester.pump();
    expect(find.textContaining('Box: 50%, 50%'), findsOneWidget);
    await tester.ensureVisible(find.text('Validate Tray'));
    await tester.tap(find.text('Validate Tray'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('capture'))).enabled, isTrue);
    await tester.ensureVisible(find.byKey(const Key('capture')));
    await tester.tap(find.byKey(const Key('capture')));
    await tester.pumpAndSettle();
    expect(got?['raw_path'], '/tmp/r.jpg');
    expect((got?['box'] as List).map((e) => (e as num).toDouble()).toList(), [0.5, 0.5]);
  });

  testWidgets('camera status displays and connects', (tester) async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.url.path == '/camera/connect') {
        return http.Response(jsonEncode({'status': 'Connected/Ready'}), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode({'ok': true}), 200, headers: {'content-type': 'application/json'});
    });
    await tester.pumpWidget(MaterialApp(
      home: CaptureScreen(
        api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: client),
        workflow: WorkflowState(),
        sessionId: 's1',
        onCaptured: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('camera_status_label')), findsOneWidget);
    expect(calls, contains('POST /camera/connect'));
    expect(calls, contains('POST /camera/liveview/start'));
  });
}
