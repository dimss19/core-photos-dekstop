import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef ProcessStarter = Future<Process> Function(String exe, List<String> args);

class SidecarLauncher {
  SidecarLauncher({ProcessStarter? starter, this.pollInterval = const Duration(milliseconds: 200)}) : _starter = starter ?? Process.start;

  final ProcessStarter _starter;
  final Duration pollInterval;
  Process? _proc;

  bool get running => _proc != null;

  String resolveExe(String flutterExeDir, {String? overridePath}) {
    if (overridePath != null && overridePath.isNotEmpty) return overridePath;
    return '$flutterExeDir${Platform.pathSeparator}core_service.exe';
  }

  static Future<bool> waitForHealthy(Uri healthUrl, {Duration timeout = const Duration(seconds: 15), Duration poll = const Duration(milliseconds: 200)}) async {
    final deadline = DateTime.now().add(timeout);
    final client = HttpClient();
    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final request = await client.getUrl(healthUrl);
          final response = await request.close().timeout(const Duration(seconds: 2));
          final body = await response.transform(utf8.decoder).join();
          if (response.statusCode == 200 && body.contains('"ok":true')) return true;
        } catch (_) {}
        await Future.delayed(poll);
      }
      return false;
    } finally {
      client.close();
    }
  }

  Future<bool> launch(String exePath, Uri healthUrl) async {
    if (running) return true;
    _proc = await _starter(exePath, const []);
    return waitForHealthy(healthUrl, poll: pollInterval);
  }

  void stop() {
    _proc?.kill();
    _proc = null;
  }
}
