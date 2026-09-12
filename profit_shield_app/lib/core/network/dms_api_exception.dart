import 'package:dio/dio.dart';

class DmsApiException implements Exception {
  const DmsApiException({
    required this.message,
    this.statusCode,
    this.apiStatusCode,
  });

  final String message;
  final int? statusCode;
  final String? apiStatusCode;

  @override
  String toString() => message;

  static DmsApiException fromDio(DioException error) {
    final response = error.response;
    if (response?.data is Map<String, dynamic>) {
      final body = response!.data as Map<String, dynamic>;
      final message = body['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return DmsApiException(
          message: message,
          statusCode: response.statusCode,
          apiStatusCode: body['statuscode'] as String?,
        );
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return DmsApiException(
          message: 'Request timed out. Check your internet connection.',
          statusCode: response?.statusCode,
        );
      case DioExceptionType.connectionError:
        return DmsApiException(
          message: 'Unable to reach the server. Check your internet connection.',
          statusCode: response?.statusCode,
        );
      default:
        return DmsApiException(
          message: error.message ?? 'Network request failed.',
          statusCode: response?.statusCode,
        );
    }
  }
}
