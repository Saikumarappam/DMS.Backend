import 'package:dio/dio.dart';

import '../../data/models/api_response.dart';
import 'dms_api_exception.dart';

typedef ResponseMapper<T> = T? Function(Map<String, dynamic> body);

/// Shared Dio call wrapper with consistent error handling.
class RepositoryHelper {
  RepositoryHelper._();

  static String _httpStatusMessage(int statusCode) {
    switch (statusCode) {
      case 404:
        return 'This feature is not available on the server yet. Please deploy the latest API update.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'You do not have permission for this action.';
      default:
        return 'Request failed (HTTP $statusCode).';
    }
  }

  static Future<ApiResponse<T>> execute<T>({
    required Future<Response<Map<String, dynamic>>> Function() request,
    ResponseMapper<T>? mapData,
  }) async {
    try {
      final response = await request();
      final httpStatus = response.statusCode ?? 0;
      final body = response.data;

      if (body is! Map<String, dynamic>) {
        if (httpStatus >= 400) {
          return ApiResponse.failure(
            _httpStatusMessage(httpStatus),
            statusCode: '$httpStatus',
          );
        }
        return ApiResponse.failure('Invalid server response.');
      }

      final parsed = ApiResponse.fromDmsJson(body, mapData: mapData);
      if (!parsed.success && parsed.message.isEmpty && httpStatus >= 400) {
        return ApiResponse.failure(
          _httpStatusMessage(httpStatus),
          statusCode: parsed.statusCode ?? '$httpStatus',
        );
      }

      return parsed;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse.fromDmsJson(data, mapData: mapData);
      }
      final apiError = DmsApiException.fromDio(e);
      return ApiResponse.failure(apiError.message, statusCode: apiError.apiStatusCode);
    } catch (e) {
      return ApiResponse.failure('Unexpected error: $e');
    }
  }
}
