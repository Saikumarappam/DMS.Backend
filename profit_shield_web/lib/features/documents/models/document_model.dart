import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class DocumentFilterChoice {
  const DocumentFilterChoice({required this.id, required this.label});

  static const allBusinesses = DocumentFilterChoice(id: '', label: 'All Businesses');
  static const selectBusiness = DocumentFilterChoice(id: '', label: 'Select Business Name');
  static const allCategories = DocumentFilterChoice(id: '', label: 'All Categories');
  static const all = DocumentFilterChoice(id: '', label: 'All');

  final String id;
  final String label;
}

class DocumentBusiness {
  const DocumentBusiness({
    required this.userId,
    required this.name,
    required this.businessName,
  });

  final int userId;
  final String name;
  final String businessName;

  String get displayName =>
      businessName.trim().isNotEmpty ? businessName.trim() : (name.trim().isNotEmpty ? name.trim() : 'Business $userId');

  factory DocumentBusiness.fromJson(Map<String, dynamic> json) {
    return DocumentBusiness(
      userId: _asInt(json['UserId'] ?? json['userId'] ?? json['ClientId'] ?? json['clientId']),
      name: _asString(json['Name'] ?? json['name']),
      businessName: _asString(json['BusinessName'] ?? json['businessName']),
    );
  }

  DocumentFilterChoice get asChoice =>
      DocumentFilterChoice(id: '$userId', label: displayName);
}

class DocumentCategoryOption {
  const DocumentCategoryOption({
    required this.categoryId,
    required this.categoryName,
  });

  final int categoryId;
  final String categoryName;

  factory DocumentCategoryOption.fromJson(Map<String, dynamic> json) {
    return DocumentCategoryOption(
      categoryId: _asInt(json['CategoryId'] ?? json['categoryId']),
      categoryName: _asString(
        json['CategoryName'] ?? json['categoryName'],
        fallback: 'Category',
      ),
    );
  }

  DocumentFilterChoice get asChoice =>
      DocumentFilterChoice(id: '$categoryId', label: categoryName);
}

enum DocumentFileType {
  pdf,
  spreadsheet,
  image,
  other;

  bool get isSpreadsheet => this == DocumentFileType.spreadsheet;
  bool get isImage => this == DocumentFileType.image;

  String get label {
    switch (this) {
      case DocumentFileType.pdf:
        return 'PDF';
      case DocumentFileType.spreadsheet:
        return 'XLSX';
      case DocumentFileType.image:
        return 'JPG';
      case DocumentFileType.other:
        return 'FILE';
    }
  }

  Color get accent {
    switch (this) {
      case DocumentFileType.pdf:
        return const Color(0xFFEF4444);
      case DocumentFileType.spreadsheet:
        return const Color(0xFF22C55E);
      case DocumentFileType.image:
        return const Color(0xFFF97316);
      case DocumentFileType.other:
        return const Color(0xFF64748B);
    }
  }

  Color get chipForeground {
    switch (this) {
      case DocumentFileType.pdf:
        return const Color(0xFFDC2626);
      case DocumentFileType.spreadsheet:
        return const Color(0xFF16A34A);
      case DocumentFileType.image:
        return const Color(0xFFEA580C);
      case DocumentFileType.other:
        return const Color(0xFF475569);
    }
  }

  Color get chipBackground => chipForeground.withValues(alpha: 0.12);

  IconData get glyph {
    switch (this) {
      case DocumentFileType.pdf:
        return Icons.picture_as_pdf_rounded;
      case DocumentFileType.spreadsheet:
        return Icons.grid_on_rounded;
      case DocumentFileType.image:
        return Icons.image_outlined;
      case DocumentFileType.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  static DocumentFileType fromFile({
    required String fileName,
    String? contentType,
    String? extension,
  }) {
    var ext = (extension ?? '').replaceFirst('.', '').toLowerCase().trim();
    if (ext.isEmpty && fileName.contains('.')) {
      ext = fileName.split('.').last.toLowerCase().trim();
    }
    final mime = (contentType ?? '').toLowerCase();
    const sheets = {'xlsx', 'xls', 'csv', 'ods'};
    const images = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'};
    if (sheets.contains(ext) || mime.contains('spreadsheet') || mime.contains('excel') || mime.contains('csv')) {
      return DocumentFileType.spreadsheet;
    }
    if (images.contains(ext) || mime.startsWith('image/')) {
      return DocumentFileType.image;
    }
    if (ext == 'pdf' || mime.contains('pdf')) {
      return DocumentFileType.pdf;
    }
    return DocumentFileType.other;
  }
}

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.fileName,
    required this.description,
    required this.categoryName,
    required this.uploadedOn,
    required this.uploaderPhone,
    required this.uploaderName,
    required this.businessName,
    required this.fileType,
    this.categoryId,
    this.contentType = '',
    this.status = '',
    this.extensionLabel = '',
    this.fileBase64 = '',
    this.gstin = '',
  });

  final int id;
  final String fileName;
  final String description;
  final String categoryName;
  final int? categoryId;
  final DateTime? uploadedOn;
  final String uploaderPhone;
  final String uploaderName;
  final String businessName;
  final DocumentFileType fileType;
  final String contentType;
  final String status;
  final String extensionLabel;
  final String fileBase64;
  final String gstin;

  bool get isDeleted => status.toLowerCase() == 'deleted';
  bool get isProcessed {
    final value = status.toLowerCase();
    return value == 'processed' || value == 'approved';
  }

  String get invoiceNumber {
    final name = fileName.trim();
    final dot = name.lastIndexOf('.');
    if (dot > 0) return name.substring(0, dot);
    return name.isEmpty ? '—' : name;
  }

  String get fileTypeLabel {
    final ext = extensionLabel.trim().replaceFirst('.', '').toUpperCase();
    if (ext.isNotEmpty) return ext;
    return fileType.label;
  }

  String get resolvedContentType {
    if (contentType.trim().isNotEmpty) return contentType.trim();
    final ext = extensionLabel.replaceFirst('.', '').toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'pdf' => 'application/pdf',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'xls' => 'application/vnd.ms-excel',
      'csv' => 'text/csv',
      _ => fileType.isImage ? 'image/jpeg' : 'application/octet-stream',
    };
  }

  Uint8List? get previewBytes {
    final encoded = fileBase64.trim();
    if (encoded.isEmpty || encoded.toLowerCase() == 'base64string') return null;
    try {
      final payload = encoded.contains(',') ? encoded.split(',').last : encoded;
      final normalized = payload.replaceAll(RegExp(r'\s'), '');
      var padded = normalized;
      final mod = padded.length % 4;
      if (mod > 0) {
        padded = padded.padRight(padded.length + (4 - mod), '=');
      }
      return Uint8List.fromList(base64Decode(padded));
    } catch (_) {
      return null;
    }
  }

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    final fileName = _asString(
      json['OriginalFileName'] ??
          json['originalFileName'] ??
          json['FileName'] ??
          json['fileName'] ??
          json['DocumentName'] ??
          json['documentName'],
      fallback: 'Document',
    );
    final contentType = _asString(
      json['ContentType'] ?? json['contentType'] ?? json['MimeType'] ?? json['mimeType'],
    );
    final extension = _extensionOf(fileName, json['FileExtension'] ?? json['fileExtension'] ?? json['FileType'] ?? json['fileType']);
    final description = _asString(
      json['Description'] ??
          json['description'] ??
          json['DocumentType'] ??
          json['documentType'] ??
          json['Source'] ??
          json['source'] ??
          json['Remarks'] ??
          json['remarks'],
    );
    final categoryName = _asString(
      json['CategoryName'] ?? json['categoryName'],
      fallback: 'Others',
    );

    return DocumentItem(
      id: _asInt(
        json['FileId'] ??
            json['fileId'] ??
            json['DocumentId'] ??
            json['documentId'] ??
            json['Id'] ??
            json['id'],
      ),
      fileName: fileName,
      description: description.isNotEmpty ? description : categoryName,
      categoryName: categoryName,
      categoryId: _asIntOrNull(json['CategoryId'] ?? json['categoryId']),
      uploadedOn: _asDate(
        json['UploadDate'] ??
            json['uploadDate'] ??
            json['UploadedOn'] ??
            json['uploadedOn'] ??
            json['CreatedDate'] ??
            json['createdDate'] ??
            json['CreatedOn'] ??
            json['createdOn'],
      ),
      uploaderPhone: _asString(
        json['MobileNumber'] ??
            json['mobileNumber'] ??
            json['PhoneNumber'] ??
            json['phoneNumber'] ??
            json['UploadedByMobile'] ??
            json['uploadedByMobile'] ??
            json['ContactNumber'] ??
            json['contactNumber'],
      ),
      uploaderName: _asString(
        json['UploadedBy'] ??
            json['uploadedBy'] ??
            json['UploadedByName'] ??
            json['uploadedByName'] ??
            json['UserName'] ??
            json['userName'] ??
            json['Name'] ??
            json['name'] ??
            json['ClientName'] ??
            json['clientName'],
      ),
      businessName: _asString(
        json['BusinessName'] ??
            json['businessName'] ??
            json['ClientBusinessName'] ??
            json['clientBusinessName'],
      ),
      fileType: DocumentFileType.fromFile(
        fileName: fileName,
        contentType: contentType,
        extension: extension,
      ),
      contentType: contentType,
      status: _asString(json['DocumentStatus'] ?? json['documentStatus'] ?? json['Status'] ?? json['status']),
      extensionLabel: extension,
      fileBase64: _asString(
        json['FileBase64'] ??
            json['fileBase64'] ??
            json['FileContent'] ??
            json['fileContent'] ??
            json['Base64'] ??
            json['base64'],
      ),
      gstin: _asString(json['GSTIN'] ?? json['gstin'] ?? json['GSTNumber'] ?? json['gstNumber']),
    );
  }
}

class DocumentDownload {
  const DocumentDownload({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final List<int> bytes;
}

Color categoryColorFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('sales') && n.contains('return')) return const Color(0xFF0D9488);
  if (n.contains('purchase') && n.contains('return')) return const Color(0xFF0891B2);
  if (n.contains('sales')) return const Color(0xFF2563EB);
  if (n.contains('purchase')) return const Color(0xFF16A34A);
  if (n.contains('expense')) return const Color(0xFFEA580C);
  if (n.contains('income')) return const Color(0xFFD97706);
  if (n.contains('bank')) return const Color(0xFF7C3AED);
  return const Color(0xFF6B7280);
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse('$value') ?? 0;
}

int? _asIntOrNull(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return null;
  final parsed = _asInt(value);
  return parsed == 0 && '$value' != '0' ? null : parsed;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = '$value'.trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  var text = '$value'.trim();
  if (text.isEmpty) return null;
  text = text.replaceFirst(' ', 'T');
  final match = RegExp(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.(\d+))?').firstMatch(text);
  if (match != null) {
    final fraction = match.group(3);
    if (fraction != null && fraction.length > 6) {
      text = '${match.group(1)}.${fraction.substring(0, 6)}';
    } else {
      text = match.group(0)!;
    }
  }
  return DateTime.tryParse(text);
}

String _extensionOf(String fileName, dynamic rawType) {
  final type = _asString(rawType).replaceFirst('.', '');
  if (type.isNotEmpty && !type.contains('/') && type.length <= 5) {
    return type.toUpperCase();
  }
  if (fileName.contains('.')) {
    final ext = fileName.split('.').last.trim().replaceFirst('.', '');
    if (ext.isNotEmpty && ext.length <= 5) return ext.toUpperCase();
  }
  if (type.contains('/')) {
    return type.split('/').last.toUpperCase();
  }
  return type.toUpperCase();
}
