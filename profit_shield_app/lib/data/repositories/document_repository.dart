import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/dms_data_parser.dart';
import '../../core/network/repository_helper.dart';
import '../models/api_parsers.dart';
import '../models/api_response.dart';
import '../models/document_models.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.read(apiClientProvider));
});

class DocumentRepository {
  DocumentRepository(this._apiClient);

  final ApiClient _apiClient;
  final Map<int, DocumentDownloadModel> _downloadCache = {};

  void invalidateDownloadCache(int fileId) => _downloadCache.remove(fileId);

  Future<ApiResponse<String>> upload(UploadFilePayload payload) async {
    final filePart = MultipartFile.fromBytes(
      payload.bytes,
      filename: payload.fileName,
    );

    final formData = FormData.fromMap({
      'categoryId': payload.categoryId,
      'source': payload.source,
      'file': filePart,
    });

    return RepositoryHelper.execute<String>(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.documentsUpload,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      ),
      mapData: (body) {
        if (body['status'] != true) return null;
        UploadResponseParser.parseFileId(body);
        return UploadResponseParser.successMessage(body);
      },
    );
  }

  Future<ApiResponse<List<DocumentModel>>> getHistory(
    DocumentHistoryFilter filter,
  ) {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.documentsHistory,
        queryParameters: filter.toQuery(),
      ),
      mapData: (body) => DmsDataParser.mapList(
        body['data'],
        'Array0',
        DocumentModel.fromJson,
      ),
    );
  }

  Future<ApiResponse<DashboardModel>> getDashboard() {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.documentsDashboard,
      ),
      mapData: DashboardResponseParser.parse,
    );
  }

  Future<ApiResponse<DocumentDownloadModel>> downloadDocument(int fileId) async {
    final cached = _downloadCache[fileId];
    if (cached != null) {
      return ApiResponse(
        success: true,
        message: '',
        data: cached,
      );
    }

    try {
      final response = await _apiClient.get<String>(
        ApiEndpoints.documentDownload(fileId),
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      final httpStatus = response.statusCode ?? 0;
      final rawBody = response.data;

      if (rawBody == null || rawBody.isEmpty) {
        if (httpStatus >= 400) {
          return ApiResponse.failure(
            _downloadHttpMessage(httpStatus),
            statusCode: '$httpStatus',
          );
        }
        return ApiResponse.failure('Invalid server response.');
      }

      final file = await DocumentDownloadModel.parseFromResponseBody(rawBody);
      if (file == null) {
        return ApiResponse.failure('Could not load file.');
      }

      _downloadCache[fileId] = file;
      return ApiResponse(
        success: true,
        message: '',
        data: file,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse.fromDmsJson(data);
      }
      final status = e.response?.statusCode;
      if (status != null && status >= 400) {
        return ApiResponse.failure(
          _downloadHttpMessage(status),
          statusCode: '$status',
        );
      }
      return ApiResponse.failure(
        e.message ?? 'Could not download file.',
      );
    } catch (e) {
      return ApiResponse.failure('Unexpected error: $e');
    }
  }

  String _downloadHttpMessage(int statusCode) {
    switch (statusCode) {
      case 404:
        return 'File not found.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'You do not have permission to download this file.';
      default:
        return 'Download failed (HTTP $statusCode).';
    }
  }

  Future<ApiResponse<bool>> deleteDocument(int fileId) async {
    final deleteResult = await RepositoryHelper.execute<bool>(
      request: () => _apiClient.delete<Map<String, dynamic>>(
        ApiEndpoints.documentDelete(fileId),
      ),
      mapData: (body) => body['status'] as bool? ?? false,
    );

    if (deleteResult.success) {
      invalidateDownloadCache(fileId);
      return deleteResult;
    }

    final status = deleteResult.statusCode;
    if (status == '404' || status == '405') {
      final postResult = await RepositoryHelper.execute<bool>(
        request: () => _apiClient.post<Map<String, dynamic>>(
          ApiEndpoints.documentDeletePost(fileId),
        ),
        mapData: (body) => body['status'] as bool? ?? false,
      );
      if (postResult.success) {
        invalidateDownloadCache(fileId);
        return postResult;
      }
      if (postResult.message.isNotEmpty) return postResult;
    }

    return deleteResult;
  }

  Future<ApiResponse<List<ReportItemModel>>> getDailyReport({
    required DateTime from,
    required DateTime to,
  }) {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.reportsDaily,
        queryParameters: {
          'fromDate': from.toIso8601String(),
          'toDate': to.toIso8601String(),
        },
      ),
      mapData: (body) => DmsDataParser.mapList(
        body['data'],
        'Array0',
        ReportItemModel.fromJson,
      ),
    );
  }

  Future<ApiResponse<List<ReportItemModel>>> getMonthlyReport(int year) {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.reportsMonthly,
        queryParameters: {'year': year},
      ),
      mapData: (body) => DmsDataParser.mapList(
        body['data'],
        'Array0',
        ReportItemModel.fromJson,
      ),
    );
  }

  Future<ApiResponse<List<ReportItemModel>>> getUserWiseReport({
    DateTime? from,
    DateTime? to,
  }) {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.reportsUserWise,
        queryParameters: {
          if (from != null) 'fromDate': from.toIso8601String(),
          if (to != null) 'toDate': to.toIso8601String(),
        },
      ),
      mapData: (body) => DmsDataParser.mapList(
        body['data'],
        'Array0',
        ReportItemModel.fromJson,
      ),
    );
  }

  Future<ApiResponse<List<ReportItemModel>>> getCategoryWiseReport({
    DateTime? from,
    DateTime? to,
  }) {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.reportsCategoryWise,
        queryParameters: {
          if (from != null) 'fromDate': from.toIso8601String(),
          if (to != null) 'toDate': to.toIso8601String(),
        },
      ),
      mapData: (body) => DmsDataParser.mapList(
        body['data'],
        'Array0',
        ReportItemModel.fromJson,
      ),
    );
  }

  Future<ApiResponse<List<AuditLogModel>>> getAuditLogs({
    DateTime? from,
    DateTime? to,
    int? userId,
  }) {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.reportsAuditLogs,
        queryParameters: {
          if (from != null) 'fromDate': from.toIso8601String(),
          if (to != null) 'toDate': to.toIso8601String(),
          if (userId != null) 'userId': userId,
        },
      ),
      mapData: (body) => DmsDataParser.mapList(
        body['data'],
        'Array0',
        AuditLogModel.fromJson,
      ),
    );
  }
}
