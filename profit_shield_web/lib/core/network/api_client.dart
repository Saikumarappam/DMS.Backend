import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'api_logger.dart';
import 'api_response.dart';

typedef TokenRefreshedCallback = Future<void> Function(
  String token,
  String refreshToken,
  DateTime? expiresAt,
);
typedef SessionExpiredCallback = void Function();

class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  String? accessToken;
  String? refreshToken;
  DateTime? expiresAt;
  TokenRefreshedCallback? onTokensRefreshed;
  SessionExpiredCallback? onSessionExpired;

  static const _tokenKey = 'ps_access_token';
  static const _refreshKey = 'ps_refresh_token';
  static const _expiresKey = 'ps_expires_at';
  static const _usernameKey = 'ps_login_username';

  Future<void> loadStoredTokens() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_tokenKey);
    refreshToken = prefs.getString(_refreshKey);
    final expires = prefs.getString(_expiresKey);
    expiresAt = expires != null ? DateTime.tryParse(expires) : null;
  }

  Future<void> persistTokens({
    required String token,
    required String refresh,
    DateTime? expires,
  }) async {
    accessToken = token;
    refreshToken = refresh;
    expiresAt = expires;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_refreshKey, refresh);
    if (expires != null) {
      await prefs.setString(_expiresKey, expires.toIso8601String());
    }
  }

  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_expiresKey);
    await prefs.remove(_usernameKey);
  }

  Future<void> persistUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, trimmed);
  }

  Future<String?> loadStoredUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${AppConfig.apiBaseUrl}$normalized').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool auth = true, bool json = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (auth && accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    return headers;
  }

  Future<ApiResponse> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) =>
      _send(
        method: 'GET',
        uri: _uri(path, query),
        auth: auth,
        request: () => _http.get(_uri(path, query), headers: _headers(auth: auth)),
      );

  Future<ApiResponse> post(
    String path, {
    Object? body,
    bool auth = true,
  }) {
    final uri = _uri(path);
    return _send(
      method: 'POST',
      uri: uri,
      body: body,
      auth: auth,
      request: () => _http.post(
        uri,
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<ApiResponse> put(
    String path, {
    Object? body,
    bool auth = true,
  }) {
    final uri = _uri(path);
    return _send(
      method: 'PUT',
      uri: uri,
      body: body,
      auth: auth,
      request: () => _http.put(
        uri,
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<ApiResponse> delete(String path, {bool auth = true}) {
    final uri = _uri(path);
    return _send(
      method: 'DELETE',
      uri: uri,
      auth: auth,
      request: () => _http.delete(uri, headers: _headers(auth: auth)),
    );
  }

  Future<ApiResponse> _send({
    required String method,
    required Uri uri,
    required Future<http.Response> Function() request,
    required bool auth,
    Object? body,
    bool retried = false,
  }) async {
    final started = DateTime.now();
    ApiLogger.request(method: method, uri: uri, body: body, auth: auth);

    try {
      final response = await request();
      final elapsed = DateTime.now().difference(started);

      if (response.statusCode == 401 && auth && !retried) {
        ApiLogger.failure(
          method: method,
          uri: uri,
          error: 'HTTP 401 — trying token refresh',
          elapsed: elapsed,
        );
        final refreshed = await _tryRefresh();
        if (refreshed) return _send(method: method, uri: uri, request: request, auth: auth, body: body, retried: true);
        onSessionExpired?.call();
        throw ApiException('Session expired. Please sign in again.', statusCode: '401');
      }

      if (response.body.isEmpty) {
        ApiLogger.failure(
          method: method,
          uri: uri,
          error: 'Empty response body (HTTP ${response.statusCode})',
          elapsed: elapsed,
        );
        throw ApiException('Empty response from server (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        ApiLogger.failure(
          method: method,
          uri: uri,
          error: 'Response is not a JSON object',
          elapsed: elapsed,
        );
        throw ApiException('Unexpected response format.');
      }

      final api = ApiResponse.fromJson(decoded);
      ApiLogger.response(
        method: method,
        uri: uri,
        httpStatus: response.statusCode,
        body: response.body,
        elapsed: elapsed,
        apiStatus: api.status,
        apiStatusCode: api.statusCode,
        apiMessage: api.message,
      );

      if (!api.status) {
        throw ApiException(
          api.message.isEmpty ? 'Request failed.' : api.message,
          statusCode: api.statusCode,
        );
      }
      return api;
    } on ApiException catch (e) {
      if (DateTime.now().difference(started) > Duration.zero) {
        ApiLogger.failure(
          method: method,
          uri: uri,
          error: e.message,
          elapsed: DateTime.now().difference(started),
        );
      }
      rethrow;
    } catch (e) {
      final elapsed = DateTime.now().difference(started);
      if (e is FormatException) {
        ApiLogger.failure(method: method, uri: uri, error: 'Invalid JSON: $e', elapsed: elapsed);
        throw ApiException('Invalid JSON from server.');
      }

      final target = AppConfig.apiBaseUrl;
      final message =
          'Unable to reach the server at $target. '
          'Start the DMS.API backend (dotnet run) or set API_BASE_URL. '
          'Details: $e';
      ApiLogger.failure(method: method, uri: uri, error: message, elapsed: elapsed);
      throw ApiException(message);
    }
  }

  Future<bool> _tryRefresh() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    try {
      final uri = _uri('/auth/refresh');
      ApiLogger.request(
        method: 'POST',
        uri: uri,
        body: {'refreshToken': '***'},
        auth: false,
      );
      final started = DateTime.now();
      final response = await _http.post(
        uri,
        headers: _headers(auth: false),
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      final elapsed = DateTime.now().difference(started);
      if (response.statusCode >= 400 || response.body.isEmpty) {
        ApiLogger.failure(
          method: 'POST',
          uri: uri,
          error: 'Refresh failed (HTTP ${response.statusCode})',
          elapsed: elapsed,
        );
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      final api = ApiResponse.fromJson(decoded);
      ApiLogger.response(
        method: 'POST',
        uri: uri,
        httpStatus: response.statusCode,
        body: response.body,
        elapsed: elapsed,
        apiStatus: api.status,
        apiStatusCode: api.statusCode,
        apiMessage: api.message,
      );
      if (!api.status || api.token == null || api.refreshToken == null) return false;
      await persistTokens(
        token: api.token!,
        refresh: api.refreshToken!,
        expires: api.expiresAt,
      );
      await onTokensRefreshed?.call(api.token!, api.refreshToken!, api.expiresAt);
      return true;
    } catch (e) {
      ApiLogger.failure(method: 'POST', uri: _uri('/auth/refresh'), error: e);
      return false;
    }
  }
}
