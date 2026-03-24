import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/user_model.dart';
import '../constants/api_config.dart';
import 'api_service.dart';
import 'contact_service.dart';
import 'expense_service.dart';
import 'isar_service.dart';

enum AuthFlow {
  login,
  sendSignupOtp,
  verifySignupOtp,
  sendResetPinOtp,
  verifyResetPinOtp,
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

  String describeOtpDestination(Map<String, dynamic>? responseData) {
    final label = responseData?['data']?['deliveryChannelLabel']?.toString().trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return 'messages';
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
          return serverError.isNotEmpty
              ? serverError
              : 'Please wait 2 minutes before requesting another OTP.';
        }
        if (statusCode == 400 && lower.contains('already exists')) {
          return 'Phone already registered. Please login.';
        }
        if (lower.contains('template')) {
          return 'WhatsApp OTP template is not ready yet. Check backend configuration.';
        }
      }

      if (flow == AuthFlow.sendResetPinOtp) {
        if (statusCode == 429) {
          return serverError.isNotEmpty
              ? serverError
              : 'Please wait 2 minutes before requesting another OTP.';
        }
        if (statusCode == 404 || lower.contains('not found')) {
          return 'User not found. Please sign up first.';
        }
        if (lower.contains('template')) {
          return 'WhatsApp OTP template is not ready yet. Check backend configuration.';
        }
      }

      if (flow == AuthFlow.verifySignupOtp && statusCode == 400) {
        if (lower.contains('invalid otp')) return 'Invalid OTP.';
        if (lower.contains('expired')) return 'OTP expired. Request a new OTP.';
        if (lower.contains('already exists')) {
          return 'User already exists. Please login.';
        }
      }

      if (flow == AuthFlow.verifyResetPinOtp) {
        if (statusCode == 400) {
          if (lower.contains('invalid otp')) return 'Invalid OTP.';
          if (lower.contains('expired')) {
            return 'OTP expired. Request a new OTP.';
          }
        }
        if (statusCode == 404 || lower.contains('not found')) {
          return 'User not found. Please sign up first.';
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
    final normalizedPhone = _normalizePhone(phoneNumber);
    developer.log('AuthService: sendSignupOtp request ($normalizedPhone)',
        name: 'AuthService');

    final response = await _api.post(
      ApiConfig.sendOtp,
      data: {'phoneNumber': normalizedPhone},
    );

    developer.log('AuthService: sendSignupOtp response: ${response.data}',
        name: 'AuthService');

    return response.data;
  }

  Future<Map<String, dynamic>> sendResetPinOtp(String phoneNumber) async {
    final response = await _api.post(
      ApiConfig.sendResetPinOtp,
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
    final normalizedPhone = _normalizePhone(phoneNumber);
    developer.log('AuthService: login request ($normalizedPhone)',
        name: 'AuthService');

    final response = await _api.post(
      ApiConfig.login,
      data: {
        'phoneNumber': normalizedPhone,
        'pin': pin,
      },
    );

    developer.log('AuthService: login response: ${response.data}',
        name: 'AuthService');

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

  Future<void> verifyResetPinOtp({
    required String phoneNumber,
    required String otp,
    required String pin,
  }) async {
    await _api.post(
      ApiConfig.verifyResetPinOtp,
      data: {
        'phoneNumber': _normalizePhone(phoneNumber),
        'otp': otp,
        'pin': pin,
      },
    );

    // Keep offline PIN check aligned with the latest successful reset.
    await _storage.write(key: 'hashed_pin', value: _hashPin(pin));
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

  Future<UserModel?> updateMe({String? name}) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;

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

  Future<void> syncContactsOnLogin({
    required ExpenseService expenseService,
    required ContactService contactService,
    required IsarService isar,
  }) async {
    final balances = await expenseService.getBalances(forceRefresh: true);
    if (balances.isNotEmpty) {
      final contacts = expenseService.getCachedBalanceContacts();
      if (contacts.isNotEmpty) {
        await contactService.upsertContactsByCanonical(isar, contacts);
        contactService.notifyUpdate();
      }
    }
    await expenseService.getExpenses(forceRefresh: true);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }
}

