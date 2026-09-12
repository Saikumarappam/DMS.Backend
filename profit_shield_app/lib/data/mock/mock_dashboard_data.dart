import '../models/document_models.dart';

class MockDashboardData {
  MockDashboardData._();

  static DashboardModel clientDashboard({required String name, String? businessName}) {
    final now = DateTime.now();
    return DashboardModel(
      name: name,
      businessName: businessName,
      categories: const [
        DashboardCategoryItem(
          categoryId: 1,
          categoryName: 'Sales Documents',
          filesCount: 12,
          lastUploadDate: null,
        ),
        DashboardCategoryItem(
          categoryId: 2,
          categoryName: 'Purchase Documents',
          filesCount: 6,
          lastUploadDate: null,
        ),
      ],
      totalDocuments: 24,
      pendingDocuments: 5,
      approvedDocuments: 19,
      recentUploads: [
        DocumentModel(
          fileId: 1,
          clientId: 1,
          categoryId: 1,
          categoryName: 'Invoices',
          fileName: 'invoice_march.pdf',
          originalFileName: 'Invoice_March_2026.pdf',
          fileExtension: '.pdf',
          fileSize: 245760,
          source: 'Mobile',
          documentStatus: 'Approved',
          uploadDate: now.subtract(const Duration(hours: 2)),
        ),
        DocumentModel(
          fileId: 2,
          clientId: 1,
          categoryId: 2,
          categoryName: 'Contracts',
          fileName: 'service_agreement.pdf',
          originalFileName: 'Service_Agreement.pdf',
          fileExtension: '.pdf',
          fileSize: 512000,
          source: 'Web',
          documentStatus: 'Pending',
          uploadDate: now.subtract(const Duration(days: 1)),
        ),
        DocumentModel(
          fileId: 3,
          clientId: 1,
          categoryId: 3,
          categoryName: 'Tax Documents',
          fileName: 'gst_return.pdf',
          originalFileName: 'GST_Return_Q1.pdf',
          fileExtension: '.pdf',
          fileSize: 189440,
          source: 'Mobile',
          documentStatus: 'Approved',
          uploadDate: now.subtract(const Duration(days: 3)),
        ),
      ],
    );
  }
}
