import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry original request
            return handler.resolve(await _dio.fetch(error.requestOptions));
          }
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

  void wakeUpServer() {
    unawaited((() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastWakeUpRaw = prefs.get('last_wake_up');
        final lastWakeUp = (lastWakeUpRaw is int) ? lastWakeUpRaw : 
                          (lastWakeUpRaw is double) ? lastWakeUpRaw.toInt() :
                          (lastWakeUpRaw is String) ? int.tryParse(lastWakeUpRaw) ?? 0 : 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        if (now - lastWakeUp < 900000) return;
        
        try {
          await prefs.setInt('last_wake_up', now);
        } catch (_) {}

        unawaited((() async {
          try {
            await _dio.get('/health', options: Options(sendTimeout: const Duration(seconds: 5)));
          } catch (_) {}
        })());
      } catch (_) {}
    })());
  }
}

