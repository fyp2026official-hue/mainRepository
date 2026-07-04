import 'dart:convert';

import '../config/api_config.dart';
import 'admin_api_transport.dart'
    if (dart.library.html) 'admin_api_transport_web.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class AdminApiService {
  final AdminApiTransport _transport = AdminApiTransport();

  String? get token => _transport.token;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  void saveToken(String value) {
    _transport.saveToken(value);
  }

  void clearToken() {
    _transport.clearToken();
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      '/api/admin/auth/login',
      auth: false,
      body: {
        'email': email,
        'password': password,
      },
    );

    final loginToken = data['token']?.toString();
    if (loginToken == null || loginToken.isEmpty) {
      throw ApiException('Login response did not include a token');
    }

    saveToken(loginToken);
    return data;
  }

  Future<Map<String, dynamic>> dashboard() {
    return _request('GET', '/api/admin/dashboard');
  }

  Future<Map<String, dynamic>> users({int page = 1}) {
    return _request(
      'GET',
      '/api/admin/users',
      query: {'page': '$page', 'limit': '20'},
    );
  }

  Future<Map<String, dynamic>> userDetails(String id) {
    return _request('GET', '/api/admin/users/$id');
  }

  Future<Map<String, dynamic>> updateUser(
    String id, {
    String? role,
    bool? isActive,
  }) {
    final body = <String, dynamic>{};
    if (role != null) body['role'] = role;
    if (isActive != null) body['isActive'] = isActive;
    return _request('PATCH', '/api/admin/users/$id', body: body);
  }

  Future<Map<String, dynamic>> tournaments({int page = 1}) {
    return _request(
      'GET',
      '/api/admin/tournaments',
      query: {'page': '$page', 'limit': '20'},
    );
  }

  Future<Map<String, dynamic>> tournamentDetails(String id) {
    return _request('GET', '/api/admin/tournaments/$id');
  }

  Future<Map<String, dynamic>> updateTournament(
    String id,
    Map<String, dynamic> body,
  ) {
    return _request('PATCH', '/api/admin/tournaments/$id', body: body);
  }

  Future<Map<String, dynamic>> deleteTournament(String id) {
    return _request('DELETE', '/api/admin/tournaments/$id');
  }

  Future<Map<String, dynamic>> matches({int page = 1}) {
    return _request(
      'GET',
      '/api/admin/matches',
      query: {'page': '$page', 'limit': '20'},
    );
  }

  Future<Map<String, dynamic>> matchDetails(String id) {
    return _request('GET', '/api/admin/matches/$id');
  }

  Future<Map<String, dynamic>> deleteMatch(String id) {
    return _request('DELETE', '/api/admin/matches/$id');
  }

  Future<Map<String, dynamic>> notificationLogs({int page = 1}) {
    return _request(
      'GET',
      '/api/admin/notifications/logs',
      query: {'page': '$page', 'limit': '20'},
    );
  }

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    String? city,
  }) {
    return _request(
      'POST',
      '/api/admin/notifications/send',
      body: {
        'title': title,
        'body': body,
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    final uri = query == null ? base : base.replace(queryParameters: query);

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (auth) {
      final currentToken = token;
      if (currentToken == null || currentToken.isEmpty) {
        throw ApiException('Admin session expired', 401);
      }
      headers['Authorization'] = 'Bearer $currentToken';
    }

    final response = await _transport.request(
      uri.toString(),
      method: method,
      requestHeaders: headers,
      sendData: body == null ? null : jsonEncode(body),
    );

    final text = response.body;
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);

    if (response.status < 200 || response.status >= 300) {
      final message = decoded is Map && decoded['message'] != null
          ? decoded['message'].toString()
          : 'Request failed';
      throw ApiException(message, response.status);
    }

    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }
}
