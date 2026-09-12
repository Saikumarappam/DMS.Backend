/// Normalizes API JSON keys (PascalCase from SQL → camelCase for Dart models).
class JsonUtils {
  JsonUtils._();

  static Map<String, dynamic> normalizeMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      result[_toLowerCamel(entry.key)] = entry.value;
    }
    return result;
  }

  static String _toLowerCamel(String key) {
    if (key.isEmpty) return key;
    return key[0].toLowerCase() + key.substring(1);
  }

  /// Reads a field from API JSON supporting PascalCase (`UserId`, `PANNumber`) and camelCase.
  static dynamic pick(Map<String, dynamic> json, String camelKey) {
    final target = camelKey.toLowerCase();
    for (final entry in json.entries) {
      if (entry.key.toLowerCase() == target) return entry.value;
    }
    return null;
  }

  static int parseInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  /// Parses API date values without defaulting to the current time.
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    var raw = '$value'.trim();
    if (raw.isEmpty) return null;

    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;

    final normalized = raw.contains(' ') && !raw.contains('T')
        ? raw.replaceFirst(' ', 'T')
        : raw;
    final normalizedParse = DateTime.tryParse(normalized);
    if (normalizedParse != null) return normalizedParse;

    final slashMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$')
        .firstMatch(raw);
    if (slashMatch != null) {
      final day = int.parse(slashMatch.group(1)!);
      final month = int.parse(slashMatch.group(2)!);
      final year = int.parse(slashMatch.group(3)!);
      final hour = int.parse(slashMatch.group(4) ?? '0');
      final minute = int.parse(slashMatch.group(5) ?? '0');
      final second = int.parse(slashMatch.group(6) ?? '0');
      return DateTime(year, month, day, hour, minute, second);
    }

    final dotNetMatch = RegExp(r'/Date\((\d+)\)/').firstMatch(raw);
    if (dotNetMatch != null) {
      final millis = int.tryParse(dotNetMatch.group(1)!);
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
      }
    }

    return null;
  }
}
