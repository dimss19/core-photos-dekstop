import 'dart:convert';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('settings shows server url and camera capabilities', (tester) async {
    final mock = MockClient((req) async {
      Object out = const {};
      if (req.url.path == '/camera/capabilities') {
        out = {
          'adapter': 'fake',
          'supports_liveview': true,
          'supports_iso': true,
          'supports_focus': false,
          'supports_zoom': false,
          'supports_capture': true,
        };
      }
      return http.Response(jsonEncode(out), 200, headers: {'content-type': 'application/json'});
    });
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(api: ApiClient(baseUrl: 'http://127.0.0.1:9', httpClient: mock)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('127.0.0.1:9'), findsOneWidget);
    expect(find.text('Kemampuan kamera'), findsOneWidget);
    expect(find.text('Ya'), findsWidgets);
    expect(find.text('Tidak'), findsWidgets);
  });
}
