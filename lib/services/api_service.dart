import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_config.dart';

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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
          developer.log('[API] 401 received, attempting token refresh...', name: 'ApiService');
          final refreshed = await _refreshToken();
          if (refreshed) {
            developer.log('[API] Token refreshed, retrying request...', name: 'ApiService');
            return handler.resolve(await _dio.fetch(error.requestOptions));
          }
          developer.log('[API] Token refresh failed', name: 'ApiService');
        }
        return handler.next(error);
      },
    ));
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
      return false;
    }
    return false;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
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

