import 'package:dio/dio.dart';

class NetworkErrorHandler {
  static const String moneyWriteMessage =
      'Not saved. Check your internet and try again.';

  static bool isNetworkIssue(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
    }

    final raw = error.toString().toLowerCase();
    return raw.contains('socketexception') ||
        raw.contains('timeout') ||
        raw.contains('connection');
  }

  static String message(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is DioException) {
      final serverMessage = _serverMessage(error);
      final statusCode = error.response?.statusCode;

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Request timed out. Please try again.';
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'Unable to connect. Check your internet and try again.';
      }

      if (statusCode == 429) {
        return serverMessage.isNotEmpty
            ? serverMessage
            : 'Too many requests. Please wait a moment and try again.';
      }

      if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
        return 'Server is temporarily unavailable. Please try again.';
      }

      if (serverMessage.isNotEmpty) {
        return serverMessage;
      }
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') || raw.contains('connection')) {
      return 'Unable to connect. Check your internet and try again.';
    }
    if (raw.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    return fallback;
  }

  static String moneyWrite([Object? error]) {
    if (error != null) return message(error, fallback: moneyWriteMessage);
    return moneyWriteMessage;
  }

  static String _serverMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = (data['error'] ?? data['message'])?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return '';
  }
}
