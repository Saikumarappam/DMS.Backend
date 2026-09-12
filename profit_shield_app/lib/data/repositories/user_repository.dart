import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/dms_data_parser.dart';
import '../../core/network/repository_helper.dart';
import '../models/api_response.dart';
import '../models/user_models.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(apiClientProvider));
});

class UserRepository {
  UserRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ApiResponse<UserModel>> getProfile() {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.usersProfile,
      ),
      mapData: (body) {
        final row = DmsDataParser.firstRow(body['data']);
        return row == null ? null : UserModel.fromJson(row);
      },
    );
  }

  Future<ApiResponse<bool>> updateProfile(UpdateProfileRequest request) {
    return RepositoryHelper.execute<bool>(
      request: () => _apiClient.put<Map<String, dynamic>>(
        ApiEndpoints.usersProfile,
        data: request.toJson(),
      ),
      mapData: (body) => body['status'] as bool? ?? false,
    );
  }

  Future<ApiResponse<List<UserModel>>> getUsers({
    String? status,
    String? search,
  }) {
    return RepositoryHelper.execute(
      request: () => _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.users,
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      ),
      mapData: (body) => DmsDataParser.mapList(
        body['data'],
        'Array0',
        UserModel.fromJson,
      ),
    );
  }

  Future<ApiResponse<bool>> approveReject(
    int userId,
    UserApprovalRequest request,
  ) {
    return RepositoryHelper.execute<bool>(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.userApproval(userId),
        data: request.toJson(),
      ),
      mapData: (body) => body['status'] as bool? ?? false,
    );
  }

  Future<ApiResponse<bool>> setStatus(int userId, bool isActive) {
    return RepositoryHelper.execute<bool>(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.userStatus(userId),
        queryParameters: {'isActive': isActive},
      ),
      mapData: (body) => body['status'] as bool? ?? false,
    );
  }
}
