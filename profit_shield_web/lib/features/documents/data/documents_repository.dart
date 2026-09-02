import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/document_model.dart';

class DocumentsRepository {
  DocumentsRepository(this._api);

  final ApiClient _api;

  Future<({
    List<DocumentBusiness> businesses,
    List<DocumentCategoryOption> categories,
    List<String> statuses,
  })> fetchFilterOptions({String type = 'Documents'}) async {
    final response = await _api.get(
      '/documents/documentFilterOptions',
      query: {'type': type},
    );

    final businesses = response.array0
        .map(DocumentBusiness.fromJson)
        .where((item) => item.userId > 0 || item.displayName.isNotEmpty)
        .toList();
    final categories = response.array1
        .map(DocumentCategoryOption.fromJson)
        .where((item) => item.categoryId > 0 || item.categoryName.isNotEmpty)
        .toList();
    final statuses = response.array2
        .map((row) => '${row['Status'] ?? row['status'] ?? ''}'.trim())
        .where((status) => status.isNotEmpty)
        .toList();

    return (businesses: businesses, categories: categories, statuses: statuses);
  }

  Future<List<DocumentItem>> fetchHistory({
    int? clientId,
    int? categoryId,
    String searchFileName = '',
    String status = 'pending',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final resolvedStatus = status.trim().isEmpty ? 'pending' : status.trim();
    final response = await _api.get(
      '/documents/history',
      query: {
        if (clientId != null && clientId > 0) 'ClientId': '$clientId',
        if (categoryId != null && categoryId > 0) 'CategoryId': '$categoryId',
        if (fromDate != null) 'FromDate': _dateQuery(fromDate),
        if (toDate != null) 'ToDate': _dateQuery(toDate, endOfDay: true),
        if (searchFileName.trim().isNotEmpty) 'SearchFileName': searchFileName.trim(),
        'Status': resolvedStatus,
      },
    );

    final rows = _documentRows(response);
    return rows.map(DocumentItem.fromJson).where((doc) => doc.id > 0 || doc.fileName.isNotEmpty).toList();
  }

  Future<DocumentDownload> downloadDocument(DocumentItem document) async {
    final bytes = document.previewBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return DocumentDownload(
        fileName: document.fileName,
        contentType: document.resolvedContentType,
        bytes: bytes,
      );
    }
    return download(document.id);
  }

  Future<String> approveDocument(int fileId) {
    return setDocumentStatus(fileId: fileId, status: 'processes');
  }

  Future<String> deleteDocument(int fileId, {required String remarks}) {
    return setDocumentStatus(fileId: fileId, status: 'deleted', remarks: remarks);
  }

  Future<String> setDocumentStatus({
    required int fileId,
    required String status,
    String remarks = '',
  }) async {
    final comments = remarks.trim();
    final response = await _api.put(
      '/documents/document/status',
      body: {
        'fileId': fileId,
        'FileId': fileId,
        'status': status,
        'Status': status,
        'remarks': comments,
        'Remarks': comments,
      },
    );
    if (response.message.trim().isNotEmpty) return response.message.trim();
    return status.toLowerCase() == 'deleted' ? 'Document deleted.' : 'Document approved.';
  }

  Future<DocumentDownload> download(int documentId) async {
    final response = await _api.get('/documents/$documentId/download');
    final row = response.array0.isNotEmpty
        ? response.array0.first
        : (response.array1.isNotEmpty ? response.array1.first : <String, dynamic>{});

    final fileName = _firstNonEmpty(row, const [
      'OriginalFileName',
      'originalFileName',
      'FileName',
      'fileName',
    ], fallback: 'document');
    final contentType = _firstNonEmpty(row, const [
      'ContentType',
      'contentType',
      'MimeType',
      'mimeType',
    ], fallback: 'application/octet-stream');
    final encoded = _firstNonEmpty(row, const [
      'FileBase64',
      'fileBase64',
      'FileContent',
      'fileContent',
      'Base64',
      'base64',
      'FileBytes',
      'fileBytes',
      'Content',
      'content',
      'Data',
      'data',
    ]);

    if (encoded.isEmpty) {
      throw ApiException('Download payload was empty.');
    }

    final payload = encoded.contains(',') ? encoded.split(',').last : encoded;
    final normalized = payload.replaceAll(RegExp(r'\s'), '');
    var padded = normalized;
    final mod = padded.length % 4;
    if (mod > 0) {
      padded = padded.padRight(padded.length + (4 - mod), '=');
    }
    return DocumentDownload(
      fileName: fileName,
      contentType: contentType,
      bytes: base64Decode(padded),
    );
  }

  List<Map<String, dynamic>> _documentRows(ApiResponse response) {
    if (_looksLikeDocuments(response.array1)) return response.array1;
    if (_looksLikeDocuments(response.array0)) return response.array0;
    if (response.array1.isNotEmpty) return response.array1;
    return response.array0;
  }

  bool _looksLikeDocuments(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return false;
    final row = rows.first;
    const keys = [
      'OriginalFileName',
      'originalFileName',
      'FileName',
      'fileName',
      'FileId',
      'fileId',
      'DocumentId',
      'documentId',
      'DocumentName',
      'documentName',
    ];
    return keys.any(row.containsKey);
  }

  String _dateQuery(DateTime date, {bool endOfDay = false}) {
    final value = endOfDay
        ? DateTime(date.year, date.month, date.day, 23, 59, 59)
        : DateTime(date.year, date.month, date.day);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}T${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _firstNonEmpty(Map<String, dynamic> row, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = '$value'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }
}
