import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({required this.baseUrl, this.token, http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final String baseUrl;
  final String? token;
  final http.Client _http;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> getJson(String path) async => _decode(await _http.get(Uri.parse('$baseUrl$path'), headers: _headers));

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async =>
      _decode(await _http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body)));

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body) async =>
      _decode(await _http.patch(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body)));

  Map<String, dynamic> _decode(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) throw ApiException(r.body, r.statusCode);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> health() => getJson('/healthz');
  Future<Map<String, dynamic>> validateInterval(double from, double to) => postJson('/trays/validate-interval', {'from': from, 'to': to});
  Future<Map<String, dynamic>> jobStatus(String id) => getJson('/jobs/$id');
  Future<Map<String, dynamic>> cameraStatus() => getJson('/camera/status');
  Future<Map<String, dynamic>> cameraCapabilities() => getJson('/camera/capabilities');
  Future<Map<String, dynamic>> cameraConnect() => postJson('/camera/connect', {});
  Future<Map<String, dynamic>> cameraDisconnect() => postJson('/camera/disconnect', {});
  Future<Map<String, dynamic>> cameraLiveViewStart() => postJson('/camera/liveview/start', {});
  Future<Map<String, dynamic>> cameraLiveViewStop() => postJson('/camera/liveview/stop', {});
  Future<Map<String, dynamic>> capture({required String filename, required List<num> box, required String outDir, String? trayId}) =>
      postJson('/captures', {'filename': filename, 'box': box, 'out_dir': outDir, if (trayId != null) 'tray_id': trayId});
  Future<Map<String, dynamic>> createSession({required String date, required String operator, required String site}) =>
      postJson('/sessions', {'date': date, 'operator': operator, 'site': site});
  Future<Map<String, dynamic>> listSessions() => getJson('/sessions');
  Future<Map<String, dynamic>> activateSession(String id) => postJson('/sessions/$id/activate', {});
  Future<Map<String, dynamic>> activeSession() => getJson('/sessions/active');
  Future<Map<String, dynamic>> createTray(Map<String, dynamic> tray) => postJson('/trays', tray);
  Future<Map<String, dynamic>> getTray(String id) => getJson('/trays/$id');
  Future<Map<String, dynamic>> correctTray(String id, Map<String, dynamic> fields) => patchJson('/trays/$id', fields);
  Future<Map<String, dynamic>> validateTray(String trayId) => postJson('/trays/validate', {'tray_id': trayId});
  Future<Map<String, dynamic>> processCapture({required String rawPath, required String trayId, List<num> box = const [0.0, 0.0]}) =>
      postJson('/process', {'raw_path': rawPath, 'tray_id': trayId, 'box': box});
  Future<Map<String, dynamic>> retakeCapture(String jobId, Map<String, dynamic> payload) =>
      postJson('/captures/$jobId/retake', payload);
  Future<Map<String, dynamic>> listPhotos({String? drillhole, String? sessionId}) {
    final q = [if (drillhole != null) 'drillhole=$drillhole', if (sessionId != null) 'session_id=$sessionId'].join('&');
    return getJson(q.isEmpty ? '/photos' : '/photos?$q');
  }

  String photoFileUrl(String photoId, [String variant = 'jpg']) => '$baseUrl/photos/$photoId/file?variant=$variant';
  Future<Map<String, dynamic>> transferCheck(Map<String, dynamic> destination) =>
      postJson('/transfer/check', {'destination': destination});
  Future<Map<String, dynamic>> transferStart({required List<String> sessionIds, required Map<String, dynamic> destination}) =>
      postJson('/transfer', {'session_ids': sessionIds, 'destination': destination});
  Future<Map<String, dynamic>> transferRetry(String jobId) => postJson('/transfer/$jobId/retry', {});
}
