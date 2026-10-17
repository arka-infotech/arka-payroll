import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/network/api_http.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

typedef TokenGetter = Future<String?> Function();

class ApiClient {
  ApiClient({required this.getToken, http.Client? httpClient})
      : _http = httpClient ?? createApiHttpClient();

  final TokenGetter getToken;
  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query, bool auth = true}) async {
    final res = await _http.get(_uri(path, query), headers: await _headers(auth: auth));
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    final res = await _http.post(
      _uri(path),
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) async {
    final res = await _http.patch(
      _uri(path),
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> put(String path, {Object? body, bool auth = true}) async {
    final res = await _http.put(
      _uri(path),
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final res = await _http.delete(
      _uri(path),
      headers: await _headers(auth: auth),
    );
    return _decode(res);
  }

  Future<List<int>> getBytes(String path) async {
    final res = await _http.get(_uri(path), headers: await _headers());
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    return res.bodyBytes;
  }

  dynamic _decode(http.Response res) {
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final msg = _errorMessage(decoded, res.body);
      throw ApiException(res.statusCode, msg);
    }
    return decoded;
  }

  String _errorMessage(dynamic decoded, String fallback) {
    if (decoded is! Map) return fallback;
    final message = decoded['message'];
    if (message is List) {
      return message.map((e) => e.toString()).join('\n');
    }
    if (message != null) return message.toString();
    return fallback;
  }
}
