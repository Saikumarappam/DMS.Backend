import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/approval_user_model.dart';

class UserApprovalsRepository {
  UserApprovalsRepository(this._api);

  final ApiClient _api;

  Future<({UserApprovalCounts counts, List<ApprovalUser> users})> fetchUsers({
    required UserApprovalStatus status,
    String search = '',
  }) async {
    final response = await _api.get(
      '/users',
      query: {
        'status': userApprovalStatusToApi(status),
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final counts = response.array0.isNotEmpty
        ? UserApprovalCounts.fromJson(response.array0.first)
        : UserApprovalCounts.empty();

    final users = response.array1
        .map(ApprovalUser.fromJson)
        .where((user) => user.status == status)
        .toList();

    return (counts: counts, users: users);
  }

  Future<ApprovalUser> fetchUser(int userId) async {
    final response = await _api.get('/users/$userId');
    if (response.array0.isEmpty) {
      throw ApiException('User not found.');
    }
    return ApprovalUser.fromJson(response.array0.first);
  }

  Future<String> approveUser(int userId) async {
    final response = await _api.post(
      '/users/$userId/approval',
      body: {'Action': 'Approve'},
    );
    return response.message.isEmpty ? 'User approved.' : response.message;
  }

  Future<String> rejectUser(int userId, {String? comments}) async {
    final response = await _api.post(
      '/users/$userId/approval',
      body: {
        'Action': 'Reject',
        if (comments != null && comments.trim().isNotEmpty) 'Comments': comments.trim(),
      },
    );
    return response.message.isEmpty ? 'User rejected.' : response.message;
  }
}
