class ApiResponse {
  ApiResponse({
    required this.status,
    required this.statusCode,
    required this.message,
    this.data,
    this.token,
    this.refreshToken,
    this.expiresAt,
    this.jsonString,
  });

  final bool status;
  final String statusCode;
  final String message;
  final Map<String, dynamic>? data;
  final String? token;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? jsonString;

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    DateTime? expires;
    final rawExpires = json['expiresAt'];
    if (rawExpires is String && rawExpires.isNotEmpty) {
      expires = DateTime.tryParse(rawExpires);
    }

    Map<String, dynamic>? data;
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      data = rawData;
    } else if (json.containsKey('Array0') ||
        json.containsKey('array0') ||
        json.containsKey('Array1') ||
        json.containsKey('array1')) {
      data = json;
    }

    final hasRows = data != null &&
        ((data['Array0'] is List && (data['Array0'] as List).isNotEmpty) ||
            (data['array0'] is List && (data['array0'] as List).isNotEmpty) ||
            (data['Array1'] is List && (data['Array1'] as List).isNotEmpty) ||
            (data['array1'] is List && (data['array1'] as List).isNotEmpty));

    return ApiResponse(
      status: json['status'] == true || (json['status'] == null && (data != null || hasRows)),
      statusCode: '${json['statuscode'] ?? ''}',
      message: '${json['message'] ?? ''}',
      data: data,
      token: json['token'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: expires,
      jsonString: json['jsonstring'] as String?,
    );
  }

  List<Map<String, dynamic>> array(String key) {
    final lower = key.toLowerCase();
    final list = data?[key] ?? data?[lower];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> get array0 => array('Array0');
  List<Map<String, dynamic>> get array1 => array('Array1');
  List<Map<String, dynamic>> get array2 => array('Array2');
  List<Map<String, dynamic>> get array3 => array('Array3');
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final String? statusCode;

  @override
  String toString() => message;
}
