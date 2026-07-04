class TransportResponse {
  final int status;
  final String body;

  const TransportResponse({
    required this.status,
    required this.body,
  });
}

class AdminApiTransport {
  static String? _token;

  String? get token => _token;

  void saveToken(String value) {
    _token = value;
  }

  void clearToken() {
    _token = null;
  }

  Future<TransportResponse> request(
    String url, {
    required String method,
    required Map<String, String> requestHeaders,
    String? sendData,
  }) {
    throw UnsupportedError('Admin API requests are only available on web.');
  }
}
