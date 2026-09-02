import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/error/app_error_handler.dart';
import '../../documents/data/documents_repository.dart';
import '../../documents/models/document_model.dart';

class CategoriesProvider extends ChangeNotifier {
  CategoriesProvider(this._repository);

  final DocumentsRepository _repository;

  static const pageSize = 6;
  static const allId = '';
  static const defaultStatus = 'pending';

  List<DocumentBusiness> businesses = [];
  List<DocumentCategoryOption> voucherTypes = [];
  List<String> statuses = [];
  List<DocumentItem> documents = [];

  String pendingBusinessId = allId;
  String pendingStatus = defaultStatus;
  String pendingVoucherTypeId = allId;
  DateTimeRange? pendingDateRange;

  String appliedBusinessId = allId;
  String appliedStatus = defaultStatus;
  String appliedVoucherTypeId = allId;
  DateTimeRange? appliedDateRange;
  String searchQuery = '';
  int currentPage = 1;
  bool isLoading = false;
  bool isLoadingFilters = false;
  bool isActing = false;
  String? errorMessage;
  Timer? _searchDebounce;

  List<DocumentFilterChoice> get businessChoices => [
        DocumentFilterChoice.selectBusiness,
        ...businesses.map((item) => item.asChoice),
      ];

  List<DocumentFilterChoice> get statusChoices {
    final seen = <String>{};
    final apiStatuses = <DocumentFilterChoice>[];
    for (final status in statuses) {
      final id = status.toLowerCase().trim();
      if (id.isEmpty || !seen.add(id)) continue;
      apiStatuses.add(DocumentFilterChoice(id: id, label: status));
    }
    final hasPending = apiStatuses.any((item) => item.id == defaultStatus);
    return [
      if (!hasPending) const DocumentFilterChoice(id: defaultStatus, label: 'Pending'),
      ...apiStatuses,
    ];
  }

  List<DocumentFilterChoice> get voucherTypeChoices => [
        DocumentFilterChoice.all,
        ...voucherTypes.map((item) => item.asChoice),
      ];

  String get historyStatus {
    final value = appliedStatus.trim();
    return value.isEmpty ? defaultStatus : value;
  }

  int get processedCount => documents.where((doc) => doc.isProcessed).length;
  int get deletedCount => documents.where((doc) => doc.isDeleted).length;
  int get totalCount => documents.length;

  int get totalPages {
    final count = documents.length;
    if (count == 0) return 1;
    return (count / pageSize).ceil();
  }

  List<DocumentItem> get pagedDocuments {
    if (documents.isEmpty) return const [];
    final start = (currentPage - 1) * pageSize;
    if (start >= documents.length) return const [];
    return documents.sublist(start, (start + pageSize).clamp(0, documents.length));
  }

  Future<void> load() async {
    await loadFilters();
    await loadDocuments();
  }

  Future<void> loadFilters() async {
    isLoadingFilters = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.fetchFilterOptions(type: 'Categories');
      businesses = result.businesses;
      voucherTypes = result.categories;
      statuses = result.statuses;
      pendingBusinessId = _sanitize(pendingBusinessId, businessChoices);
      pendingStatus = _sanitizeStatus(pendingStatus);
      pendingVoucherTypeId = _sanitize(pendingVoucherTypeId, voucherTypeChoices);
      appliedBusinessId = _sanitize(appliedBusinessId, businessChoices);
      appliedStatus = _sanitizeStatus(appliedStatus);
      appliedVoucherTypeId = _sanitize(appliedVoucherTypeId, voucherTypeChoices);
    } catch (e) {
      errorMessage = AppErrorHandler.from(e);
    } finally {
      isLoadingFilters = false;
      notifyListeners();
    }
  }

  Future<void> loadDocuments({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }
    try {
      documents = await _repository.fetchHistory(
        clientId: int.tryParse(appliedBusinessId),
        categoryId: int.tryParse(appliedVoucherTypeId),
        searchFileName: searchQuery,
        status: historyStatus,
        fromDate: appliedDateRange?.start,
        toDate: appliedDateRange?.end,
      );
      currentPage = 1;
    } catch (e) {
      errorMessage = AppErrorHandler.from(e);
      documents = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilters() async {
    appliedBusinessId = pendingBusinessId;
    appliedStatus = pendingStatus.isEmpty ? defaultStatus : pendingStatus;
    appliedVoucherTypeId = pendingVoucherTypeId;
    appliedDateRange = pendingDateRange;
    await loadDocuments();
  }

  Future<void> reset() async {
    pendingBusinessId = allId;
    pendingStatus = defaultStatus;
    pendingVoucherTypeId = allId;
    pendingDateRange = null;
    appliedBusinessId = allId;
    appliedStatus = defaultStatus;
    appliedVoucherTypeId = allId;
    appliedDateRange = null;
    searchQuery = '';
    currentPage = 1;
    notifyListeners();
    await loadDocuments();
  }

  void setPendingBusiness(String id) {
    pendingBusinessId = id;
    notifyListeners();
  }

  void setPendingStatus(String id) {
    pendingStatus = id.isEmpty ? defaultStatus : id;
    notifyListeners();
  }

  void setPendingVoucherType(String id) {
    pendingVoucherTypeId = id;
    notifyListeners();
  }

  void setPendingDateRange(DateTimeRange? range) {
    pendingDateRange = range;
    notifyListeners();
  }

  void setSearch(String value) {
    searchQuery = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), loadDocuments);
    notifyListeners();
  }

  void setPage(int page) {
    currentPage = page.clamp(1, totalPages);
    notifyListeners();
  }

  Future<DocumentDownload> download(DocumentItem document) {
    return _repository.downloadDocument(document);
  }

  Future<String?> approve(DocumentItem document) async {
    isActing = true;
    notifyListeners();
    try {
      await _repository.approveDocument(document.id);
      await loadDocuments(silent: true);
      return null;
    } catch (e) {
      return AppErrorHandler.from(e);
    } finally {
      isActing = false;
      notifyListeners();
    }
  }

  Future<String?> delete(DocumentItem document, {required String remarks}) async {
    isActing = true;
    notifyListeners();
    try {
      await _repository.deleteDocument(document.id, remarks: remarks);
      await loadDocuments(silent: true);
      return null;
    } catch (e) {
      return AppErrorHandler.from(e);
    } finally {
      isActing = false;
      notifyListeners();
    }
  }

  String _sanitize(String id, List<DocumentFilterChoice> choices) {
    return choices.any((choice) => choice.id == id) ? id : allId;
  }

  String _sanitizeStatus(String id) {
    final match = statusChoices.where((choice) => choice.id.toLowerCase() == id.toLowerCase());
    return match.isEmpty ? defaultStatus : match.first.id;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
