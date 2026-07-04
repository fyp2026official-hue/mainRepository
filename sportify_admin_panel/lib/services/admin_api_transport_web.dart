// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import '../config/api_config.dart';
import 'admin_api_transport.dart' hide AdminApiTransport;

class AdminApiTransport {
  String? get token => html.window.sessionStorage[ApiConfig.tokenStorageKey];

  void saveToken(String value) {
    html.window.sessionStorage[ApiConfig.tokenStorageKey] = value;
  }

  void clearToken() {
    html.window.sessionStorage.remove(ApiConfig.tokenStorageKey);
  }

  Future<TransportResponse> request(
    String url, {
    required String method,
    required Map<String, String> requestHeaders,
    String? sendData,
  }) async {
    final response = await html.HttpRequest.request(
      url,
      method: method,
      requestHeaders: requestHeaders,
      sendData: sendData,
    );

    return TransportResponse(
      status: response.status ?? 0,
      body: response.responseText ?? '',
    );
  }
}
