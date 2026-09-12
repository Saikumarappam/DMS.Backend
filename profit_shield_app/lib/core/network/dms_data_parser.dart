import 'dart:convert';

import '../utils/json_utils.dart';

/// Parses ProfitShield API `data` payloads shaped as `{ "Array0": [...], "Array1": [...] }`.
class DmsDataParser {
  DmsDataParser._();

  static Map<String, dynamic>? dataMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static List<Map<String, dynamic>> arrayAt(dynamic raw, String key) {
    final data = dataMap(raw);
    if (data == null) return const [];
    final array = data[key];
    if (array is! List) return const [];
    return array
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Map<String, dynamic>? firstRow(dynamic raw, [String key = 'Array0']) {
    final rows = arrayAt(raw, key);
    return rows.isEmpty ? null : rows.first;
  }

  static List<T> mapList<T>(
    dynamic raw,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return arrayAt(raw, key).map(fromJson).toList();
  }

  static Map<String, dynamic>? parseJsonString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static int? intFromBody(Map<String, dynamic> body) {
    final jsonString = body['jsonstring'] as String?;
    if (jsonString != null && jsonString.trim().isNotEmpty) {
      final parsed = int.tryParse(jsonString.trim());
      if (parsed != null) return parsed;
    }
    final data = body['data'];
    if (data is num) return data.toInt();
    return null;
  }
}
