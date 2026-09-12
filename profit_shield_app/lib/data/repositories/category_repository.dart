import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/dms_data_parser.dart';
import '../../core/network/repository_helper.dart';
import '../models/api_response.dart';
import '../models/category_models.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.read(apiClientProvider));
});

class CategoryRepository {
  CategoryRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ApiResponse<List<CategoryModel>>> getAll({
    bool includeInactive = false,
  }) {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.categories,
        queryParameters: {'includeInactive': includeInactive},
      ),
      mapData: (body) => DmsDataParser.mapList(
        body['data'],
        'Array0',
        CategoryModel.fromJson,
      ),
    );
  }

  Future<ApiResponse<int>> create(CreateCategoryRequest request) {
    return RepositoryHelper.execute(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.categories,
        data: request.toJson(),
      ),
      mapData: (body) => DmsDataParser.intFromBody(body),
    );
  }

  Future<ApiResponse<bool>> update(int id, UpdateCategoryRequest request) {
    return RepositoryHelper.execute<bool>(
      request: () => _apiClient.put<Map<String, dynamic>>(
        ApiEndpoints.categoryById(id),
        data: request.toJson(),
      ),
      mapData: (body) => body['status'] as bool? ?? false,
    );
  }

  Future<ApiResponse<bool>> delete(int id) {
    return RepositoryHelper.execute<bool>(
      request: () => _apiClient.delete<Map<String, dynamic>>(
        ApiEndpoints.categoryById(id),
      ),
      mapData: (body) => body['status'] as bool? ?? false,
    );
  }
}
