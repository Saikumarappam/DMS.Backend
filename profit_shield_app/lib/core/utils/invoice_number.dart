import '../../data/models/document_models.dart';

/// Per-category invoice numbers starting at 1 (oldest upload = 1).
class InvoiceNumberHelper {
  InvoiceNumberHelper._();

  static Map<int, int> numbersForCategory(List<DocumentModel> documents) {
    final inCategory = documents.toList()
      ..sort((a, b) => a.uploadDate.compareTo(b.uploadDate));

    return {
      for (var i = 0; i < inCategory.length; i++)
        inCategory[i].fileId: i + 1,
    };
  }

  static Map<int, Map<int, int>> numbersByCategory(List<DocumentModel> documents) {
    final grouped = <int, List<DocumentModel>>{};
    for (final doc in documents) {
      grouped.putIfAbsent(doc.categoryId, () => []).add(doc);
    }

    return {
      for (final entry in grouped.entries)
        entry.key: numbersForCategory(entry.value),
    };
  }

  static int? numberFor(
    List<DocumentModel> documents, {
    required int categoryId,
    required int fileId,
  }) {
    final map = numbersByCategory(documents);
    return map[categoryId]?[fileId];
  }

  static String label(int number) => 'Invoice number $number';

  static String extensionFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot >= fileName.length - 1) return '';
    return fileName.substring(dot);
  }

  static String uploadFileName({
    required int number,
    required String originalFileName,
    String fallbackExtension = '.pdf',
  }) {
    var ext = extensionFromFileName(originalFileName);
    if (ext.isEmpty) {
      ext = fallbackExtension;
    }
    return 'Invoice number $number$ext';
  }

  static String totalUploadedLabel(int count) {
    if (count <= 0) return 'No invoices uploaded';
    if (count == 1) return '1 invoice uploaded';
    return '$count invoices uploaded';
  }

  static String rangeLabel(int count) {
    if (count <= 0) return 'No invoices';
    if (count == 1) return 'Invoice number 1';
    return 'Invoice numbers 1–$count';
  }

  static int nextNumber(int existingCount) => existingCount + 1;
}
