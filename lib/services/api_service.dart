import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_config.dart';

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final StreamController<String> _sessionInvalidatedController =
      StreamController<String>.broadcast();
  bool _sessionInvalidationEmitted = false;

  static const String _sessionInvalidationPhrase =
      'signed in on another device';
  static const String _fallbackSessionInvalidationMessage =
      'Your account was signed in on another device. Please log in again.';
  static const int _maxGetAttempts = 3;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.timeout,
      receiveTimeout: ApiConfig.timeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        developer.log(
          '[API] --> ${options.method} ${options.baseUrl}${options.path} | body: ${options.data}',
          name: 'ApiService',
        );
        return handler.next(options);
      },
      onResponse: (response, handler) {
        developer.log(
          '[API] <-- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path} | body: ${response.data}',
          name: 'ApiService',
        );
        return handler.next(response);
      },
      onError: (error, handler) async {
        developer.log(
          '[API] ERROR ${error.response?.statusCode} ${error.requestOptions.method} ${error.requestOptions.path} | ${error.response?.data ?? error.message}',
          name: 'ApiService',
          error: error,
        );
        if (error.response?.statusCode == 401) {
          final serverMessage = _serverMessage(error);
          if (_isSessionInvalidationMessage(serverMessage)) {
            await _handleSessionInvalidation(
              serverMessage.isNotEmpty
                  ? serverMessage
                  : _fallbackSessionInvalidationMessage,
            );
            return handler.next(error);
          }

          if (error.requestOptions.path == ApiConfig.refreshToken) {
            return handler.next(error);
          }

          final hasAuthHeader =
              error.requestOptions.headers['Authorization'] != null;
          final isAuthEndpoint = _isAuthEndpoint(error.requestOptions.path);
          if (!hasAuthHeader && isAuthEndpoint) {
            return handler.next(error);
          }

          developer.log('[API] 401 received, attempting token refresh...',
              name: 'ApiService');
          final refreshed = await _refreshToken();
          if (refreshed) {
            developer.log('[API] Token refreshed, retrying request...',
                name: 'ApiService');
            return handler.resolve(await _dio.fetch(error.requestOptions));
          }
          if (hasAuthHeader || !isAuthEndpoint) {
            await _handleSessionInvalidation(
              serverMessage.isNotEmpty
                  ? serverMessage
                  : _fallbackSessionInvalidationMessage,
            );
            _applyMessageToError(
              error,
              serverMessage.isNotEmpty
                  ? serverMessage
                  : _fallbackSessionInvalidationMessage,
            );
          }
          developer.log('[API] Token refresh failed', name: 'ApiService');
        }
        return handler.next(error);
      },
    ));
  }

  Stream<String> get sessionInvalidated => _sessionInvalidatedController.stream;

  bool _isTransientGetError(DioException error) {
    final statusCode = error.response?.statusCode;
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.badResponse &&
            statusCode != null &&
            const {502, 503, 504}.contains(statusCode));
  }

  bool _isSessionInvalidationMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains(_sessionInvalidationPhrase);
  }

  bool _isAuthEndpoint(String path) {
    return path == ApiConfig.login ||
        path == ApiConfig.refreshToken ||
        path == ApiConfig.sendOtp ||
        path == ApiConfig.verifyOtp ||
        path == ApiConfig.sendResetPinOtp ||
        path == ApiConfig.verifyResetPinOtp;
  }

  void _applyMessageToError(DioException error, String message) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      data['error'] = message;
      data['message'] = message;
    }
  }

  Future<void> _handleSessionInvalidation(String message) async {
    if (_sessionInvalidationEmitted) return;
    _sessionInvalidationEmitted = true;
    await _storage.deleteAll();
    clearToken();
    _sessionInvalidatedController.add(message);
  }

  void resetSessionInvalidationState() {
    _sessionInvalidationEmitted = false;
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await _dio.post(
        ApiConfig.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final newToken = response.data['data']['accessToken'];
        await _storage.write(key: 'access_token', value: newToken);
        return true;
      }
    } catch (e) {
      if (e is DioException) {
        final serverMessage = _serverMessage(e);
        if (_isSessionInvalidationMessage(serverMessage)) {
          await _handleSessionInvalidation(
            serverMessage.isNotEmpty
                ? serverMessage
                : _fallbackSessionInvalidationMessage,
          );
        } else if (e.response?.statusCode == 401) {
          await _handleSessionInvalidation(
            serverMessage.isNotEmpty
                ? serverMessage
                : _fallbackSessionInvalidationMessage,
          );
        }
      }
      return false;
    }
    return false;
  }

  String _serverMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = (data['error'] ?? data['message'])?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return '';
  }

  Future<Response<dynamic>> _getWithRetry(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastError;

    for (var attempt = 1; attempt <= _maxGetAttempts; attempt++) {
      try {
        return await _dio.get(path, queryParameters: queryParameters);
      } on DioException catch (error) {
        lastError = error;

        if (!_isTransientGetError(error) || attempt == _maxGetAttempts) {
          rethrow;
        }

        final delayMs = attempt == 1 ? 500 : 1500;
        developer.log(
          '[API] transient GET error on $path, retrying in ${delayMs}ms '
          '(attempt $attempt/$_maxGetAttempts)',
          name: 'ApiService',
        );
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw lastError!;
  }

  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    return await _getWithRetry(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
}
