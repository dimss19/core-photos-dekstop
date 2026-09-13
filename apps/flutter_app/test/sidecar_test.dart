import 'dart:io';

import 'package:core_photo/sidecar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveExe prefers override, else joins dir', () {
    final launcher = SidecarLauncher();
    expect(launcher.resolveExe('C:\\app', overridePath: 'D:\\svc.exe'), 'D:\\svc.exe');
    expect(launcher.resolveExe('C:\\app'), 'C:\\app${Platform.pathSeparator}core_service.exe');
  });

  test('waitForHealthy true against stub, false on closed port', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"ok":true,"version":"0.1.0"}');
      await request.response.close();
    });
    expect(await SidecarLauncher.waitForHealthy(Uri.parse('http://127.0.0.1:${server.port}/healthz')), isTrue);
    expect(
      await SidecarLauncher.waitForHealthy(Uri.parse('http://127.0.0.1:9/healthz'), timeout: const Duration(milliseconds: 300)),
      isFalse,
    );
  });

  test('stop without process is no-op; failed starter leaves not-running', () async {
    final launcher = SidecarLauncher(starter: (_, __) => throw const SocketException('no exe'));
    launcher.stop();
    expect(launcher.running, isFalse);
    await expectLater(() => launcher.launch('missing.exe', Uri.parse('http://127.0.0.1:9/healthz')), throwsA(isA<SocketException>()));
    expect(launcher.running, isFalse);
  });
}
