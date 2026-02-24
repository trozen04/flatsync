import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../data/models/user_model.dart';
import '../core/constants/api_config.dart';
import 'api_service.dart';

enum AuthFlow {
  login,
  sendSignupOtp,
  verifySignupOtp,
}

class AuthService {
  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthService(this._api);

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (phone.trim().startsWith('+')) return '+$digits';
    return '+$digits';
  }

  String _extractServerError(Object error) {
    if (error is! DioException) return '';
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = (data['error'] ?? data['message'])?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return '';
  }

  String getAuthErrorMessage(Object error, {required AuthFlow flow}) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final serverError = _extractServerError(error);
      final lower = serverError.toLowerCase();

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Request timeout. Please try again.';
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'Unable to connect. Check internet or server.';
      }

      if (flow == AuthFlow.login && statusCode == 401) {
        if (lower.contains('setup pending') ||
            lower.contains('complete signup')) {
          return 'User not registered. Please sign up first.';
        }
        return 'Invalid phone or PIN.';
      }

      if (flow == AuthFlow.sendSignupOtp) {
        if (statusCode == 429) {
          return 'Please wait 10 seconds before requesting another OTP.';
        }
        if (statusCode == 400 && lower.contains('already exists')) {
          return 'Phone already registered. Please login.';
        }
      }

      if (flow == AuthFlow.verifySignupOtp && statusCode == 400) {
        if (lower.contains('invalid otp')) return 'Invalid OTP.';
        if (lower.contains('expired')) return 'OTP expired. Request a new OTP.';
        if (lower.contains('already exists')) {
          return 'User already exists. Please login.';
        }
      }

      if (serverError.isNotEmpty) return serverError;
      return 'Oops! Something went wrong';
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') || raw.contains('connection')) {
      return 'Unable to connect. Check internet or server.';
    }
    if (raw.contains('timeout')) return 'Request timeout. Please try again.';
    return 'Oops! Something went wrong';
  }

  Future<Map<String, dynamic>> sendSignupOtp(String phoneNumber) async {
    final response = await _api.post(
      ApiConfig.sendOtp,
      data: {'phoneNumber': _normalizePhone(phoneNumber)},
    );
    return response.data;
  }

  Future<UserModel> verifySignupOtp({
    required String phoneNumber,
    required String otp,
    required String name,
    required String pin,
  }) async {
    final response = await _api.post(
      ApiConfig.verifyOtp,
      data: {
        'phoneNumber': _normalizePhone(phoneNumber),
        'otp': otp,
        'name': name,
        'pin': pin,
      },
    );

    final data = response.data['data'];
    final user = UserModel.fromJson(data['user']);
    user.accessToken = data['accessToken'];
    user.refreshToken = data['refreshToken'];
    user.hashedPin = _hashPin(pin);
    user.isLoggedIn = true;

    await _storage.write(key: 'access_token', value: user.accessToken);
    await _storage.write(key: 'refresh_token', value: user.refreshToken);
    await _storage.write(key: 'user_id', value: user.userId);
    await _storage.write(key: 'hashed_pin', value: user.hashedPin);

    return user;
  }

  Future<UserModel> login({
    required String phoneNumber,
    required String pin,
  }) async {
    final response = await _api.post(
      ApiConfig.login,
      data: {
        'phoneNumber': _normalizePhone(phoneNumber),
        'pin': pin,
      },
    );

    final data = response.data['data'];
    final user = UserModel.fromJson(data['user']);
    user.accessToken = data['accessToken'];
    user.refreshToken = data['refreshToken'];
    user.hashedPin = _hashPin(pin);
    user.isLoggedIn = true;

    await _storage.write(key: 'access_token', value: user.accessToken);
    await _storage.write(key: 'refresh_token', value: user.refreshToken);
    await _storage.write(key: 'user_id', value: user.userId);
    await _storage.write(key: 'hashed_pin', value: user.hashedPin);

    return user;
  }

  Future<bool> loginOffline(String pin) async {
    final storedHash = await _storage.read(key: 'hashed_pin');
    if (storedHash == null) return false;
    return storedHash == _hashPin(pin);
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _api.get(ApiConfig.me);
      return UserModel.fromJson(response.data['data']);
    } catch (e) {
      return null;
    }
  }

  Future<UserModel?> updateMe({String? name, String? avatar}) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (avatar != null) payload['avatar'] = avatar;

      final response = await _api.patch(ApiConfig.usersMe, data: payload);
      return UserModel.fromJson(response.data['data']);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getCurrentUserId() async {
    return await _storage.read(key: 'user_id');
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _api.clearToken();
  }

  Future<void> syncContactsOnLogin() async {
    // This will be called after successful login to auto-populate contacts
    // from users who have transactions/balances with current user
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }
}
