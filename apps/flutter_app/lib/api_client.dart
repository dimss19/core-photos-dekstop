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

  Map<String, dynamic> _decode(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) throw ApiException(r.body, r.statusCode);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> health() => getJson('/healthz');
  Future<Map<String, dynamic>> validateInterval(double from, double to) => postJson('/trays/validate-interval', {'from': from, 'to': to});
  Future<Map<String, dynamic>> jobStatus(String id) => getJson('/jobs/$id');
  Future<Map<String, dynamic>> cameraStatus() => getJson('/camera/status');
  Future<Map<String, dynamic>> capture({required String filename, required List<int> box, required String outDir}) =>
      postJson('/captures', {'filename': filename, 'box': box, 'out_dir': outDir});
  Future<Map<String, dynamic>> createSession({required String date, required String operator, required String site}) =>
      postJson('/sessions', {'date': date, 'operator': operator, 'site': site});
  Future<Map<String, dynamic>> listSessions() => getJson('/sessions');
  Future<Map<String, dynamic>> activateSession(String id) => postJson('/sessions/$id/activate', {});
  Future<Map<String, dynamic>> activeSession() => getJson('/sessions/active');
}
