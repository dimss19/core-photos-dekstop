import 'dart:convert';
import 'dart:io';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/screens/session_screen.dart';
import 'package:core_photo/workflow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<HttpServer> _server(List<Map<String, dynamic>> sessions) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final body = await utf8.decoder.bind(request).join();
    Object output;
    if (request.method == 'GET') {
      output = {'sessions': sessions};
    } else {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final session = {'id': 's${sessions.length + 1}', 'date': data['date'], 'operator': data['operator'], 'site': data['site']};
      sessions.add(session);
      output = {'session': session};
    }
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(output));
    await request.response.close();
  });
  return server;
}

void main() {
  testWidgets('create session appears in list', (tester) async {
    final sessions = <Map<String, dynamic>>[];
    final server = await _server(sessions);
    addTearDown(server.close);
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    await tester.pumpWidget(MaterialApp(home: SessionScreen(api: api, workflow: WorkflowState())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('date')), '2026-09-13');
    await tester.enterText(find.byKey(const Key('operator')), 'Dimas');
    await tester.enterText(find.byKey(const Key('site')), 'SiteA');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dimas'), findsOneWidget);
  });

  testWidgets('empty operator shows error and sends nothing', (tester) async {
    var calls = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      if (request.method == 'POST') calls++;
      request.response.statusCode = 500;
      await request.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    await tester.pumpWidget(MaterialApp(home: SessionScreen(api: api, workflow: WorkflowState())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('date')), '2026-09-13');
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.text('Operator wajib diisi'), findsOneWidget);
    expect(calls, 0);
  });
}
