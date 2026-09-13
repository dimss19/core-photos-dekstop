import 'dart:convert';
import 'dart:io';
import 'package:core_photo/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('health returns ok + sends bearer token', () async {
    String? auth;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      auth = req.headers.value('authorization');
      await utf8.decoder.bind(req).join();
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'ok': true}));
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}', token: 't123');
    expect((await api.health())['ok'], isTrue);
    expect(auth, 'Bearer t123');
  });

  test('validateInterval posts from/to and reads captureEnabled', () async {
    late Map<String, dynamic> seen;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      seen = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'valid': false, 'captureEnabled': false, 'warning': 'To < From'}));
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final r = await api.validateInterval(20, 10);
    expect(r['captureEnabled'], isFalse);
    expect(seen, {'from': 20.0, 'to': 10.0});
  });

  test('non-2xx throws ApiException with status', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      req.response.statusCode = 404;
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    expect(() => api.activeSession(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
  });
}
