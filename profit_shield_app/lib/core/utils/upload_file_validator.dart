enum UploadFileKind { image, pdf, excel }

class UploadFileValidator {
  UploadFileValidator._();

  static const int imageMaxBytes = 500 * 1024;
  static const int pdfMaxBytes = 1024 * 1024;
  static const int excelMaxBytes = 10 * 1024 * 1024;
  static const int bankStatementMaxBytes = 10 * 1024 * 1024;

  static bool isBankStatements(String categoryName) {
    return categoryName.toLowerCase().contains('bank');
  }

  static bool isExcelFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.xlsx') || lower.endsWith('.xls');
  }

  static UploadFileKind? kindFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return UploadFileKind.pdf;
    if (isExcelFileName(fileName)) return UploadFileKind.excel;
    return null;
  }

  static int maxBytes({
    required UploadFileKind kind,
    required String categoryName,
  }) {
    if (isBankStatements(categoryName)) return bankStatementMaxBytes;
    switch (kind) {
      case UploadFileKind.image:
        return imageMaxBytes;
      case UploadFileKind.pdf:
        return pdfMaxBytes;
      case UploadFileKind.excel:
        return excelMaxBytes;
    }
  }

  static String maxSizeLabel({
    required UploadFileKind kind,
    required String categoryName,
  }) {
    return '(max ${_format(maxBytes(kind: kind, categoryName: categoryName))})';
  }

  static String? validate({
    required int byteLength,
    required UploadFileKind kind,
    required String categoryName,
  }) {
    final limit = maxBytes(kind: kind, categoryName: categoryName);
    if (byteLength > limit) {
      return 'File must not exceed ${_format(limit)}. Current size: ${_format(byteLength)}.';
    }
    return null;
  }

  static String _format(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)}MB';
  }
}
