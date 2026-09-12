import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final savedDownloadsStorageProvider = Provider<SavedDownloadsStorage>((ref) {
  return SavedDownloadsStorage();
});

class SavedDownloadEntry {
  const SavedDownloadEntry({
    required this.id,
    required this.fileName,
    required this.appPath,
    this.publicPath,
    required this.savedAt,
    this.sourceFileId,
  });

  final String id;
  final String fileName;
  final String appPath;
  final String? publicPath;
  final DateTime savedAt;
  final int? sourceFileId;

  String get displayLocation {
    if (publicPath != null && publicPath!.isNotEmpty) {
      return 'Downloads/ProfitShield';
    }
    return 'App › My Downloads';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'appPath': appPath,
        'publicPath': publicPath,
        'savedAt': savedAt.toIso8601String(),
        'sourceFileId': sourceFileId,
      };

  factory SavedDownloadEntry.fromJson(Map<String, dynamic> json) {
    return SavedDownloadEntry(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      appPath: json['appPath'] as String,
      publicPath: json['publicPath'] as String?,
      savedAt: DateTime.parse(json['savedAt'] as String),
      sourceFileId: json['sourceFileId'] as int?,
    );
  }
}

class SavedDownloadsStorage {
  SavedDownloadsStorage();

  static const _recordsKey = 'ps_saved_download_records';

  Future<String> appDownloadsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/ProfitShield/Downloads');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder.path;
  }

  Future<String> saveToAppFolder({
    required List<int> bytes,
    required String fileName,
  }) async {
    final folderPath = await appDownloadsDirectory();
    final safeName = _uniqueName(folderPath, fileName);
    final path = '$folderPath/$safeName';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  String _uniqueName(String folderPath, String fileName) {
    var candidate = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!File('$folderPath/$candidate').existsSync()) return candidate;

    final dot = candidate.lastIndexOf('.');
    final base = dot > 0 ? candidate.substring(0, dot) : candidate;
    final ext = dot > 0 ? candidate.substring(dot) : '';

    var index = 1;
    while (File('$folderPath/$base ($index)$ext').existsSync()) {
      index++;
    }
    return '$base ($index)$ext';
  }

  Future<SavedDownloadEntry> addRecord({
    required String fileName,
    required String appPath,
    String? publicPath,
    int? sourceFileId,
  }) async {
    final entry = SavedDownloadEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fileName: fileName,
      appPath: appPath,
      publicPath: publicPath,
      savedAt: DateTime.now(),
      sourceFileId: sourceFileId,
    );

    final records = await loadAll();
    records.insert(0, entry);
    await _persist(records);
    return entry;
  }

  Future<List<SavedDownloadEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((item) => SavedDownloadEntry.fromJson(item as Map<String, dynamic>))
          .where((entry) => File(entry.appPath).existsSync())
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> removeRecord(String id) async {
    final records = await loadAll();
    records.removeWhere((entry) => entry.id == id);
    await _persist(records);
  }

  Future<void> _persist(List<SavedDownloadEntry> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(records.map((entry) => entry.toJson()).toList());
    await prefs.setString(_recordsKey, encoded);
  }
}
