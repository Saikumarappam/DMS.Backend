import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/client_model.dart';

class ClientsRepository {
  ClientsRepository(this._api);

  final ApiClient _api;

  Future<List<ClientListItem>> fetchClients({String search = ''}) async {
    final response = await _api.get(
      '/users',
      query: {
        'status': 'Approved',
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    return response.array1
        .where((row) {
          final status = '${row['UserStatus'] ?? row['userStatus'] ?? ''}'
              .toLowerCase();
          final role = '${row['RoleName'] ?? row['roleName'] ?? ''}'
              .toLowerCase();
          return status == 'approved' && role == 'client';
        })
        .map(ClientListItem.fromJson)
        .where((client) => client.clientName != '—')
        .toList();
  }

  /// Admin update for a client — same body shape as `PUT /users/profile`.
  Future<String> updateClientProfile({
    required int userId,
    required ClientProfileUpdate profile,
  }) async {
    final response = await _api.put(
      '/users/profile/',
      // '/users/$userId',
      // body: profile.toJson(),
      body: {...profile.toJson(), 'userId': userId},
    );
    if (!response.status) {
      throw ApiException(response.message, statusCode: response.statusCode);
    }
    return response.message.isEmpty
        ? 'Client updated successfully.'
        : response.message;
  }

  Future<String> setClientActive({
    required int userId,
    required bool isActive,
  }) async {
    final response = await _api.post(
      '/users/$userId/status?isActive=$isActive',
    );
    if (!response.status) {
      throw ApiException(response.message, statusCode: response.statusCode);
    }
    return response.message.isEmpty
        ? 'Client status updated.'
        : response.message;
  }
}
