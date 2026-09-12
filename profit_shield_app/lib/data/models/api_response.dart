/// Unified wrapper for ProfitShield API responses.
/// Backend uses `status`; some legacy code may use `success`.
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
    this.jsonString,
    this.token,
    this.errors = const [],
  });

  final bool success;
  final String message;
  final T? data;
  final String? statusCode;
  final String? jsonString;
  final String? token;
  final List<String> errors;

  factory ApiResponse.fromDmsJson(
    Map<String, dynamic> json, {
    T? Function(Map<String, dynamic> body)? mapData,
  }) {
    final statusRaw = json['status'];
    final success = statusRaw is bool
        ? statusRaw
        : json['success'] is bool
            ? json['success'] as bool
            : false;
    final message = json['message'] as String? ??
        json['title'] as String? ??
        '';
    final statusCode = json['statuscode'] as String?;
    final jsonString = json['jsonstring'] as String?;
    final token = json['token'] as String?;

    T? data;
    if (mapData != null) {
      data = mapData(json);
    }

    return ApiResponse(
      success: success,
      message: message,
      data: data,
      statusCode: statusCode,
      jsonString: jsonString,
      token: token,
    );
  }

  factory ApiResponse.failure(String message, {String? statusCode}) {
    return ApiResponse(
      success: false,
      message: message,
      statusCode: statusCode,
    );
  }

  /// Legacy parser — prefer [fromDmsJson].
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? fromJsonT,
  ) {
    final rawData = json['data'];
    return ApiResponse(
      success: json['status'] as bool? ?? json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      statusCode: json['statuscode'] as String?,
      jsonString: json['jsonstring'] as String?,
      token: json['token'] as String?,
      data: fromJsonT != null ? fromJsonT(rawData) : rawData as T?,
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  String get errorMessage {
    if (errors.isNotEmpty) return errors.join('\n');
    if (message.isNotEmpty) return message;
    return 'Request failed';
  }

  int? get intFromJsonString {
    final value = jsonString?.trim();
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }
}
