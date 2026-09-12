import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/network/dms_data_parser.dart';
import '../../core/utils/json_utils.dart';

List<int> decodeDocumentBase64(String raw) {
  if (raw.isEmpty) return const [];

  var value = raw.trim();
  final comma = value.indexOf(',');
  if (value.startsWith('data:') && comma != -1) {
    value = value.substring(comma + 1);
  }

  value = value.replaceAll(RegExp(r'\s'), '');
  if (value.isEmpty) return const [];

  try {
    return base64Decode(value);
  } catch (_) {
    return const [];
  }
}

Map<String, dynamic>? _parseDownloadResponseInIsolate(String rawBody) {
  try {
    final body = jsonDecode(rawBody) as Map<String, dynamic>;
    if (body['status'] != true) return null;

    final row = DmsDataParser.firstRow(body['data'], 'Array0');
    if (row == null) return null;

    final base64Raw = JsonUtils.pick(row, 'fileBase64') as String? ?? '';
    final bytes = decodeDocumentBase64(base64Raw);
    if (bytes.isEmpty) return null;

    return {
      'fileId': JsonUtils.parseInt(JsonUtils.pick(row, 'fileId')),
      'fileName': JsonUtils.pick(row, 'fileName') as String? ?? '',
      'originalFileName': JsonUtils.pick(row, 'originalFileName') as String? ?? '',
      'fileExtension': JsonUtils.pick(row, 'fileExtension') as String? ?? '',
      'fileSize': JsonUtils.parseInt(JsonUtils.pick(row, 'fileSize')),
      'contentType': JsonUtils.pick(row, 'contentType') as String? ?? '',
      'bytes': bytes,
    };
  } catch (_) {
    return null;
  }
}

class DocumentModel {
  const DocumentModel({
    required this.fileId,
    required this.clientId,
    required this.categoryId,
    required this.categoryName,
    required this.fileName,
    required this.originalFileName,
    required this.fileExtension,
    required this.fileSize,
    required this.source,
    required this.documentStatus,
    required this.uploadDate,
    this.clientName,
    this.businessName,
  });

  final int fileId;
  final int clientId;
  final int categoryId;
  final String categoryName;
  final String fileName;
  final String originalFileName;
  final String fileExtension;
  final int fileSize;
  final String source;
  final String documentStatus;
  final DateTime uploadDate;
  final String? clientName;
  final String? businessName;

  bool get isPending => documentStatus.toLowerCase() == 'pending';

  /// Exact file name from API (`OriginalFileName`, otherwise `FileName`).
  String get displayLabel =>
      originalFileName.isNotEmpty ? originalFileName : fileName;

  String get statusLabel {
    switch (documentStatus.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Processed';
      default:
        return documentStatus;
    }
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final uploadDateRaw = JsonUtils.pick(json, 'uploadDate');
    return DocumentModel(
      fileId: JsonUtils.parseInt(JsonUtils.pick(json, 'fileId')),
      clientId: JsonUtils.parseInt(JsonUtils.pick(json, 'clientId')),
      categoryId: JsonUtils.parseInt(JsonUtils.pick(json, 'categoryId')),
      categoryName: JsonUtils.pick(json, 'categoryName') as String? ?? '',
      fileName: JsonUtils.pick(json, 'fileName') as String? ?? '',
      originalFileName: JsonUtils.pick(json, 'originalFileName') as String? ?? '',
      fileExtension: JsonUtils.pick(json, 'fileExtension') as String? ?? '',
      fileSize: JsonUtils.parseInt(JsonUtils.pick(json, 'fileSize')),
      source: JsonUtils.pick(json, 'source') as String? ?? '',
      documentStatus: JsonUtils.pick(json, 'documentStatus') as String? ?? '',
      uploadDate: JsonUtils.parseDateTime(uploadDateRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      clientName: JsonUtils.pick(json, 'clientName') as String?,
      businessName: JsonUtils.pick(json, 'businessName') as String?,
    );
  }
}

class DocumentHistoryFilter {
  const DocumentHistoryFilter({
    this.clientId,
    this.categoryId = allCategoriesId,
    this.fromDate,
    this.toDate,
    this.searchFileName,
  });

  static const int allCategoriesId = 0;

  final int? clientId;
  final int categoryId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? searchFileName;

  Map<String, dynamic> toQuery() {
    final map = <String, dynamic>{
      'CategoryId': categoryId,
    };
    if (clientId != null) map['ClientId'] = clientId;
    if (fromDate != null) {
      map['FromDate'] = _formatQueryDate(fromDate!);
    }
    if (toDate != null) {
      map['ToDate'] = _formatQueryDate(toDate!);
    }
    if (searchFileName != null && searchFileName!.isNotEmpty) {
      map['SearchFileName'] = searchFileName;
    }
    return map;
  }

  static String _formatQueryDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class DashboardCategoryItem {
  const DashboardCategoryItem({
    required this.categoryId,
    required this.categoryName,
    required this.filesCount,
    this.description,
    this.isActive = true,
    this.createdDate,
    this.lastUploadDate,
  });

  final int categoryId;
  final String categoryName;
  final int filesCount;
  final String? description;
  final bool isActive;
  final DateTime? createdDate;
  final DateTime? lastUploadDate;

  factory DashboardCategoryItem.fromJson(Map<String, dynamic> json) {
    final createdRaw = JsonUtils.pick(json, 'createdDate');
    final lastUploadRaw = JsonUtils.pick(json, 'lastUploadDate') ??
        JsonUtils.pick(json, 'latestUploadDate') ??
        JsonUtils.pick(json, 'lastUploadedDate');
    return DashboardCategoryItem(
      categoryId: JsonUtils.parseInt(JsonUtils.pick(json, 'categoryId')),
      categoryName: JsonUtils.pick(json, 'categoryName') as String? ?? '',
      filesCount: JsonUtils.parseInt(JsonUtils.pick(json, 'filesCount')),
      description: JsonUtils.pick(json, 'description') as String?,
      isActive: JsonUtils.pick(json, 'isActive') as bool? ?? true,
      createdDate: JsonUtils.parseDateTime(createdRaw),
      lastUploadDate: JsonUtils.parseDateTime(lastUploadRaw),
    );
  }
}

class DocumentDownloadModel {
  const DocumentDownloadModel({
    required this.fileId,
    required this.fileName,
    required this.originalFileName,
    required this.fileExtension,
    required this.fileSize,
    required this.contentType,
    required this.bytes,
  });

  final int fileId;
  final String fileName;
  final String originalFileName;
  final String fileExtension;
  final int fileSize;
  final String contentType;
  final List<int> bytes;

  /// Exact file name from API (`OriginalFileName`, otherwise `FileName`).
  String get displayName =>
      originalFileName.isNotEmpty ? originalFileName : fileName;

  bool get isImage {
    if (contentType.toLowerCase().startsWith('image/')) return true;
    return _imageExtensions.contains(resolvedExtension.toLowerCase());
  }

  bool get isPdf {
    if (contentType.toLowerCase() == 'application/pdf') return true;
    return resolvedExtension.toLowerCase() == '.pdf';
  }

  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.heic',
    '.heif',
    '.bmp',
  };

  String get resolvedExtension {
    var ext = fileExtension.trim();
    if (ext.isNotEmpty) {
      if (!ext.startsWith('.')) ext = '.$ext';
      return ext.toLowerCase();
    }

    final lowerName = displayName.toLowerCase();
    for (final imageExt in _imageExtensions) {
      if (lowerName.endsWith(imageExt)) return imageExt;
    }
    if (lowerName.endsWith('.pdf')) return '.pdf';

    final type = contentType.toLowerCase();
    if (type.contains('jpeg') || type.contains('jpg')) return '.jpg';
    if (type.contains('png')) return '.png';
    if (type.contains('webp')) return '.webp';
    if (type.contains('gif')) return '.gif';
    if (type.contains('pdf')) return '.pdf';

    if (bytes.length >= 4) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return '.jpg';
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return '.png';
      if (bytes[0] == 0x25 && bytes[1] == 0x50) return '.pdf';
    }

    return '.bin';
  }

  factory DocumentDownloadModel.fromJson(Map<String, dynamic> json) {
    final base64Raw = JsonUtils.pick(json, 'fileBase64') as String? ?? '';
    return DocumentDownloadModel(
      fileId: JsonUtils.parseInt(JsonUtils.pick(json, 'fileId')),
      fileName: JsonUtils.pick(json, 'fileName') as String? ?? '',
      originalFileName: JsonUtils.pick(json, 'originalFileName') as String? ?? '',
      fileExtension: JsonUtils.pick(json, 'fileExtension') as String? ?? '',
      fileSize: JsonUtils.parseInt(JsonUtils.pick(json, 'fileSize')),
      contentType: JsonUtils.pick(json, 'contentType') as String? ?? '',
      bytes: decodeDocumentBase64(base64Raw),
    );
  }

  /// Parses the full download API body off the UI thread (JSON + base64 decode).
  static Future<DocumentDownloadModel?> parseFromResponseBody(String rawBody) async {
    if (rawBody.trim().isEmpty) return null;

    final parsed = await compute(_parseDownloadResponseInIsolate, rawBody);
    if (parsed == null) return null;

    return DocumentDownloadModel(
      fileId: parsed['fileId'] as int,
      fileName: parsed['fileName'] as String,
      originalFileName: parsed['originalFileName'] as String,
      fileExtension: parsed['fileExtension'] as String,
      fileSize: parsed['fileSize'] as int,
      contentType: parsed['contentType'] as String,
      bytes: List<int>.from(parsed['bytes'] as List),
    );
  }
}

class DashboardModel {
  const DashboardModel({
    required this.name,
    required this.categories,
    required this.totalDocuments,
    required this.pendingDocuments,
    required this.approvedDocuments,
    required this.recentUploads,
    this.businessName,
  });

  final String name;
  final String? businessName;
  final List<DashboardCategoryItem> categories;
  final int totalDocuments;
  final int pendingDocuments;
  final int approvedDocuments;
  final List<DocumentModel> recentUploads;

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      name: json['name'] as String? ?? '',
      businessName: json['businessName'] as String?,
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => DashboardCategoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDocuments: (json['totalDocuments'] as num?)?.toInt() ?? 0,
      pendingDocuments: (json['pendingDocuments'] as num?)?.toInt() ?? 0,
      approvedDocuments: (json['approvedDocuments'] as num?)?.toInt() ?? 0,
      recentUploads: (json['recentUploads'] as List<dynamic>? ?? [])
          .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReportItemModel {
  const ReportItemModel({
    required this.label,
    required this.documentCount,
    required this.totalSize,
    this.userId,
    this.categoryId,
  });

  final String label;
  final int documentCount;
  final int totalSize;
  final int? userId;
  final int? categoryId;

  factory ReportItemModel.fromJson(Map<String, dynamic> json) {
    return ReportItemModel(
      label: json['label'] as String? ?? '',
      documentCount: (json['documentCount'] as num?)?.toInt() ?? 0,
      totalSize: (json['totalSize'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt(),
      categoryId: (json['categoryId'] as num?)?.toInt(),
    );
  }
}

class AuditLogModel {
  const AuditLogModel({
    required this.auditLogId,
    required this.action,
    required this.entityName,
    required this.createdDate,
    this.userId,
    this.entityId,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.userName,
  });

  final int auditLogId;
  final int? userId;
  final String action;
  final String entityName;
  final String? entityId;
  final String? oldValues;
  final String? newValues;
  final String? ipAddress;
  final DateTime createdDate;
  final String? userName;

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      auditLogId: (json['auditLogId'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      action: json['action'] as String? ?? '',
      entityName: json['entityName'] as String? ?? '',
      entityId: json['entityId'] as String?,
      oldValues: json['oldValues'] as String?,
      newValues: json['newValues'] as String?,
      ipAddress: json['ipAddress'] as String?,
      createdDate: DateTime.parse(json['createdDate'] as String),
      userName: json['userName'] as String?,
    );
  }
}

class UploadFilePayload {
  const UploadFilePayload({
    required this.categoryId,
    required this.source,
    required this.fileName,
    required this.bytes,
  });

  final int categoryId;
  final String source;
  final String fileName;
  final List<int> bytes;
}
