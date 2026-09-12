import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalUploadRecord {
  const LocalUploadRecord({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.fileName,
    required this.fileSize,
    required this.source,
    required this.status,
    required this.uploadDate,
  });

  final String id;
  final int categoryId;
  final String categoryName;
  final String fileName;
  final int fileSize;
  final String source;
  final String status;
  final DateTime uploadDate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'fileName': fileName,
        'fileSize': fileSize,
        'source': source,
        'status': status,
        'uploadDate': uploadDate.toIso8601String(),
      };

  factory LocalUploadRecord.fromJson(Map<String, dynamic> json) {
    return LocalUploadRecord(
      id: json['id'] as String,
      categoryId: (json['categoryId'] as num).toInt(),
      categoryName: json['categoryName'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? 'Camera',
      status: json['status'] as String? ?? 'Completed',
      uploadDate: DateTime.parse(json['uploadDate'] as String),
    );
  }
}

class LocalUploadStore {
  LocalUploadStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _key = 'local_upload_history';

  Future<List<LocalUploadRecord>> getAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => LocalUploadRecord.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
  }

  Future<void> add(LocalUploadRecord record) async {
    final items = await getAll();
    items.insert(0, record);
    await _storage.write(
      key: _key,
      value: jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<int> countForCategory(int categoryId) async {
    final items = await getAll();
    return items.where((e) => e.categoryId == categoryId).length;
  }

  Future<Map<int, int>> categoryCounts() async {
    final items = await getAll();
    final counts = <int, int>{};
    for (final item in items) {
      counts[item.categoryId] = (counts[item.categoryId] ?? 0) + 1;
    }
    return counts;
  }
}
