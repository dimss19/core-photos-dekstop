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

  test('tray + process + photos + transfer roundtrip paths', () async {
    final seen = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      seen.add('${req.method} ${req.uri.path}?${req.uri.query}');
      await utf8.decoder.bind(req).join();
      Object out = const {};
      if (req.uri.path == '/trays') out = {'tray': {'id': 't1'}};
      if (req.uri.path == '/trays/t1') {
        out = req.method == 'PATCH'
            ? {'tray': {'id': 't1', 'validation': null}}
            : {'tray': {'id': 't1', 'hole_id': 'Core01'}};
      }
      if (req.uri.path == '/trays/validate') out = {'valid': true, 'status': 'VALID', 'errors': {}};
      if (req.uri.path == '/process') out = {'job_id': 'job-1'};
      if (req.uri.path == '/photos') out = {'photos': []};
      if (req.uri.path == '/transfer/check') out = {'reachable': true, 'detail': 'writable'};
      if (req.uri.path == '/transfer') out = {'job_id': 'job-2'};
      if (req.uri.path == '/transfer/job-2/retry') out = {'job_id': 'job-3'};
      if (req.uri.path == '/captures/job-1/retake') out = {'job_id': 'job-4'};
      if (req.uri.path == '/camera/capabilities') out = {'adapter': 'fake', 'supports_capture': true};
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(out));
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    expect((await api.createTray({'hole_id': 'Core01'}))['tray']['id'], 't1');
    expect((await api.getTray('t1'))['tray']['hole_id'], 'Core01');
    expect((await api.correctTray('t1', {'comments': 'x'}))['tray']['validation'], isNull);
    expect((await api.validateTray('t1'))['status'], 'VALID');
    expect((await api.processCapture(rawPath: '/r.jpg', trayId: 't1'))['job_id'], 'job-1');
    expect((await api.retakeCapture('job-1', {}))['job_id'], 'job-4');
    expect((await api.cameraCapabilities())['supports_capture'], isTrue);
    expect(await api.listPhotos(drillhole: 'Core01'), {'photos': []});
    expect(api.photoFileUrl('p1'), contains('/photos/p1/file?variant=jpg'));
    expect((await api.transferCheck({'type': 'folder'}))['reachable'], isTrue);
    expect((await api.transferStart(sessionIds: ['s1'], destination: {'type': 'folder'}))['job_id'], 'job-2');
    expect((await api.transferRetry('job-2'))['job_id'], 'job-3');
    expect(seen, contains('GET /photos?drillhole=Core01'));
  });
}
