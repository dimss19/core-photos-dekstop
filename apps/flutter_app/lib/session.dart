import 'api_client.dart';

class SessionInfo {
  SessionInfo({required this.id, required this.date, required this.operator, required this.site});

  final String id;
  final String date;
  final String operator;
  final String site;

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
        id: '${json['id']}',
        date: '${json['date']}',
        operator: '${json['operator']}',
        site: '${json['site']}',
      );
}

class SessionService {
  SessionService(this.api);

  final ApiClient api;

  Future<SessionInfo> create({required String date, required String operator, required String site}) async {
    final response = await api.createSession(date: date, operator: operator, site: site);
    return SessionInfo.fromJson(response['session'] as Map<String, dynamic>);
  }

  Future<List<SessionInfo>> list() async {
    final response = await api.listSessions();
    return (response['sessions'] as List).map((item) => SessionInfo.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<SessionInfo> activate(String id) async {
    final response = await api.activateSession(id);
    return SessionInfo.fromJson(response['active'] as Map<String, dynamic>);
  }
}
