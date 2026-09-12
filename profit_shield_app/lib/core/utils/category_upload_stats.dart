import '../../data/models/document_models.dart';

class CategoryUploadStats {
  CategoryUploadStats._();

  static bool _isValidUploadDate(DateTime date) =>
      date.millisecondsSinceEpoch > 0;

  static DateTime? latestUploadDate(
    DashboardCategoryItem category,
    List<DocumentModel> history,
  ) {
    return latestUploadDateForCategory(category.categoryId, history);
  }

  static DateTime? latestUploadDateForCategory(
    int categoryId,
    List<DocumentModel> history,
  ) {
    DateTime? latest;

    for (final doc in history) {
      if (doc.categoryId != categoryId) continue;
      if (!_isValidUploadDate(doc.uploadDate)) continue;
      if (latest == null || doc.uploadDate.isAfter(latest)) {
        latest = doc.uploadDate;
      }
    }

    return latest;
  }

  static int invoiceCount(
    DashboardCategoryItem category,
    List<DocumentModel> history,
  ) {
    if (category.filesCount > 0) return category.filesCount;
    return invoiceCountForCategory(category.categoryId, history);
  }

  static int invoiceCountForCategory(
    int categoryId,
    List<DocumentModel> history,
  ) {
    return history.where((doc) => doc.categoryId == categoryId).length;
  }
}
