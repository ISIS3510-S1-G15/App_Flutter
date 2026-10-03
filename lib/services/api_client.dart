import 'dart:convert';
import 'package:http/http.dart' as http;

// Design pattern: SINGLETON (Juan Felipe Ochoa)
// The whole app shares ONE ApiClient: one place that knows the backend URL, the request timeout
// and how to send/receive JSON. Every service that talks to the backend uses ApiClient() and
// always receives the same instance, so the URL is never copied into several files.
class ApiClient {
  // 1. Private constructor: no other file can create a new ApiClient with ApiClient._internal()
  ApiClient._internal();

  // 2. The single instance, created once the first time it is used
  static final ApiClient _instance = ApiClient._internal();

  // 3. Factory constructor: ApiClient() does NOT create a new object, it returns the same _instance
  factory ApiClient() => _instance;

  // 10.0.2.2 is how the Android emulator reaches the computer running the backend (localhost)
  static const String baseUrl = 'http://10.0.2.2:8000';

  // If the backend does not answer in this time, the request fails instead of freezing the feature
  static const Duration timeout = Duration(seconds: 5);

  // One HTTP client reused for every request (reuses connections instead of opening a new one each time)
  final http.Client _http = http.Client();

  // Session token (JWT) of the logged-in user. Because ApiClient is a Singleton, setting it once after login
  // makes EVERY service send it automatically; logging out clears it for all of them at the same time
  String? _token;

  void setToken(String? token) => _token = token;

  // Headers of every request: JSON content type when there is a body, and the token when there is a session
  Map<String, String> _headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // GET a path and return the decoded JSON. Throws ApiException if the server answers with an error
  Future<dynamic> getJson(String path) async {
    final response = await _http.get(_uri(path), headers: _headers()).timeout(timeout);
    return _decode(response);
  }

  // POST a JSON body to a path and return the decoded JSON answer
  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final response = await _http
        .post(
          _uri(path),
          headers: _headers(json: true),
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body);
  }
}

// Error raised when the backend answers with a status code that is not 2xx
class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  // FastAPI sends errors as {"detail": "message"}; returns that message, or null if the body has another shape
  String? get detail {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) return decoded['detail'] as String;
    } catch (_) {}
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $body';
}
