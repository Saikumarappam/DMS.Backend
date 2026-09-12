import '../../core/network/dms_data_parser.dart';
import '../../core/utils/json_utils.dart';
import 'auth_models.dart';
import 'document_models.dart';
import 'user_models.dart';

/// Maps ProfitShield `TokenResponse` / login payloads to [AuthResponse].
class AuthResponseParser {
  AuthResponseParser._();

  static AuthResponse? parse(Map<String, dynamic> body) {
    final success = body['status'] as bool? ?? false;
    if (!success) return null;

    var accessToken = body['token'] as String? ?? '';
    var refreshToken = body['refreshToken'] as String? ?? '';
    var expiresAt = _parseDate(body['expiresAt']);

    final jsonExtra = DmsDataParser.parseJsonString(body['jsonstring'] as String?);
    if (jsonExtra != null) {
      refreshToken = refreshToken.isEmpty
          ? jsonExtra['refreshToken'] as String? ?? ''
          : refreshToken;
      expiresAt ??= _parseDate(jsonExtra['expiresAt']);
    }

    final userJson = DmsDataParser.firstRow(body['data']);
    if (userJson == null || accessToken.isEmpty) return null;

    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
      user: UserModel.fromJson(userJson),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

/// Builds [DashboardModel] from dashboard API response.
/// Array0=user, Array1=stats, Array2=recent uploads.
class DashboardResponseParser {
  DashboardResponseParser._();

  static DashboardModel? parse(Map<String, dynamic> body) {
    if (body['status'] != true) return null;

    final data = body['data'];
    final user = DmsDataParser.firstRow(data, 'Array0');
    final stats = DmsDataParser.firstRow(data, 'Array1');
    final recent = DmsDataParser.mapList(
      data,
      'Array2',
      DocumentModel.fromJson,
    );

    return DashboardModel(
      name: JsonUtils.pick(user ?? {}, 'name') as String? ?? '',
      businessName: JsonUtils.pick(user ?? {}, 'businessName') as String?,
      categories: const [],
      totalDocuments: _intValue(stats, 'totalDocuments'),
      pendingDocuments: _intValue(stats, 'pendingDocuments'),
      approvedDocuments: _intValue(stats, 'approvedDocuments'),
      recentUploads: recent,
    );
  }

  static int _intValue(Map<String, dynamic>? json, String key) {
    if (json == null) return 0;
    final value = JsonUtils.pick(json, key);
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

/// Parses upload response — `jsonstring` or `data.Array0[0].fileId`.
class UploadResponseParser {
  UploadResponseParser._();

  static int? parseFileId(Map<String, dynamic> body) {
    if (body['status'] != true) return null;

    final fromJsonString = DmsDataParser.intFromBody(body);
    if (fromJsonString != null) return fromJsonString;

    final row = DmsDataParser.firstRow(body['data'], 'Array0');
    if (row == null) return null;
    return JsonUtils.parseInt(JsonUtils.pick(row, 'fileId'));
  }

  static String successMessage(Map<String, dynamic> body) {
    return body['message'] as String? ?? 'Document uploaded successfully.';
  }
}
