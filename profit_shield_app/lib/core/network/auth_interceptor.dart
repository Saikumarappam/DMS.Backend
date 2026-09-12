import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/config/api_endpoints.dart';
import '../../core/config/env_config.dart';
import '../../data/models/api_parsers.dart';
import '../../data/models/auth_models.dart';
import '../storage/session_token_cache.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokenStorage,
    required this.onSessionExpired,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final void Function() onSessionExpired;

  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra['skipAuth'] == true;
    if (!skipAuth) {
      final envToken = EnvConfig.authToken;
      final cachedToken = SessionTokenCache.accessToken;
      final storedToken = cachedToken ?? await _tokenStorage.getAccessToken();
      final token = storedToken ?? envToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['skipAuth'] == true ||
        err.requestOptions.extra['retried'] == true) {
      return handler.next(err);
    }

    if (_isRefreshing) {
      final completer = _PendingRequest(err.requestOptions);
      _pendingRequests.add(completer);
      try {
        final response = await completer.future;
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
      return;
    }

    _isRefreshing = true;
    try {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        await _tokenStorage.clearAll();
        onSessionExpired();
        _rejectPending(err);
        return handler.next(err);
      }

      final response = await _retry(err.requestOptions);
      _resolvePending(response);
      handler.resolve(response);
    } catch (e) {
      await _tokenStorage.clearAll();
      onSessionExpired();
      _rejectPending(err);
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> _refreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.authRefresh,
        data: RefreshTokenRequest(refreshToken: refreshToken).toJson(),
        options: Options(
          extra: const {'skipAuth': true},
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode != 200 || response.data == null) return false;

      final auth = AuthResponseParser.parse(response.data!);
      if (auth == null) return false;

      await _tokenStorage.saveTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
        expiresAt: auth.expiresAt,
      );
      SessionTokenCache.set(
        access: auth.accessToken,
        refresh: auth.refreshToken,
        expires: auth.expiresAt,
      );
      await _tokenStorage.saveUser(auth.user);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final token = SessionTokenCache.accessToken ?? await _tokenStorage.getAccessToken();
    final headers = Map<String, dynamic>.from(options.headers);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return _dio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: Options(
        method: options.method,
        headers: headers,
        responseType: options.responseType,
        contentType: options.contentType,
        extra: {...options.extra, 'retried': true},
      ),
    );
  }

  void _resolvePending(Response<dynamic> response) {
    for (final pending in _pendingRequests) {
      _retry(pending.options).then(pending.complete).catchError(pending.fail);
    }
    _pendingRequests.clear();
  }

  void _rejectPending(DioException err) {
    for (final pending in _pendingRequests) {
      pending.fail(err);
    }
    _pendingRequests.clear();
  }
}

class _PendingRequest {
  _PendingRequest(this.options);

  final RequestOptions options;
  final _completer = Completer<Response<dynamic>>();

  Future<Response<dynamic>> get future => _completer.future;

  void complete(Response<dynamic> response) {
    if (!_completer.isCompleted) _completer.complete(response);
  }

  void fail(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}
