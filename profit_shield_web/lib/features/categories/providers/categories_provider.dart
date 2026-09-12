import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/error/app_error_handler.dart';
import '../../documents/data/documents_repository.dart';
import '../../documents/models/document_model.dart';

class CategoriesProvider extends ChangeNotifier {
  CategoriesProvider(this._repository);

  final DocumentsRepository _repository;

  static const pageSize = 6;
  static const unselectedId = DocumentFilterChoice.unselectedId;

  List<DocumentBusiness> businesses = [];
  List<DocumentCategoryOption> voucherTypes = [];
  List<String> statuses = [];
  List<DocumentItem> documents = [];

  String pendingBusinessId = unselectedId;
  String pendingStatus = unselectedId;
  String pendingVoucherTypeId = unselectedId;
  DateTimeRange? pendingDateRange;

  String appliedBusinessId = unselectedId;
  String appliedStatus = unselectedId;
  String appliedVoucherTypeId = unselectedId;
  DateTimeRange? appliedDateRange;
  String searchQuery = '';
  int currentPage = 1;
  bool isLoading = false;
  bool isLoadingFilters = false;
  bool isActing = false;
  bool filtersApplied = false;
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
      if (id.isEmpty || id == 'all' || !seen.add(id)) continue;
      apiStatuses.add(DocumentFilterChoice(id: id, label: status));
    }
    final choices = [
      DocumentFilterChoice.selectStatus,
      ...apiStatuses,
    ];
    final selected = pendingStatus.isNotEmpty ? pendingStatus : appliedStatus;
    if (_isProcessedAlias(selected) && !choices.any((choice) => _isProcessedAlias(choice.id))) {
      choices.add(const DocumentFilterChoice(id: 'processes', label: 'Processes'));
    }
    return choices;
  }

  List<DocumentFilterChoice> get voucherTypeChoices => [
        DocumentFilterChoice.selectCategoryType,
        ...voucherTypes.map((item) => item.asChoice),
      ];

  bool get areRequiredFiltersSelected =>
      pendingBusinessId != unselectedId &&
      pendingStatus != unselectedId &&
      pendingVoucherTypeId != unselectedId &&
      pendingDateRange != null;

  String get historyStatus => appliedStatus.trim();

  int get processedCount =>
      filtersApplied ? documents.where((doc) => doc.isProcessed).length : 0;
  int get deletedCount =>
      filtersApplied ? documents.where((doc) => doc.isDeleted).length : 0;
  int get totalCount => filtersApplied ? documents.length : 0;

  int get totalPages {
    final count = documents.length;
    if (count == 0) return 1;
    return (count / pageSize).ceil();
  }

  List<DocumentItem> get pagedDocuments {
    if (!filtersApplied || documents.isEmpty) return const [];
    final start = (currentPage - 1) * pageSize;
    if (start >= documents.length) return const [];
    return documents.sublist(start, (start + pageSize).clamp(0, documents.length));
  }

  Future<void> initialize({String? status}) async {
    await loadFilters();
    if (status != null && status.trim().isNotEmpty) {
      pendingStatus = _sanitizePendingStatus(_normalizeStatus(status));
      notifyListeners();
    }
  }

  Future<void> load({String? status}) async {
    await initialize(status: status);
    if (filtersApplied) {
      await loadDocuments();
    }
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
      pendingBusinessId = _sanitizePending(pendingBusinessId, businessChoices);
      pendingStatus = _sanitizePendingStatus(pendingStatus);
      pendingVoucherTypeId = _sanitizePending(pendingVoucherTypeId, voucherTypeChoices);
      appliedBusinessId = _sanitizeApplied(appliedBusinessId, businessChoices);
      appliedStatus = _sanitizeAppliedStatus(appliedStatus);
      appliedVoucherTypeId = _sanitizeApplied(appliedVoucherTypeId, voucherTypeChoices);
    } catch (e) {
      errorMessage = AppErrorHandler.from(e);
    } finally {
      isLoadingFilters = false;
      notifyListeners();
    }
  }

  Future<void> loadDocuments({bool silent = false}) async {
    if (!filtersApplied) return;

    if (!silent) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }
    try {
      documents = await _repository.fetchHistory(
        clientId: int.tryParse(appliedBusinessId) ?? 0,
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

  Future<String?> applyFilters() async {
    if (!areRequiredFiltersSelected) {
      return 'Please select business name, status, category type, and date range.';
    }
    appliedBusinessId = pendingBusinessId;
    appliedStatus = pendingStatus;
    appliedVoucherTypeId = pendingVoucherTypeId;
    appliedDateRange = pendingDateRange;
    filtersApplied = true;
    await loadDocuments();
    return null;
  }

  Future<void> reset() async {
    pendingBusinessId = unselectedId;
    pendingStatus = unselectedId;
    pendingVoucherTypeId = unselectedId;
    pendingDateRange = null;
    appliedBusinessId = unselectedId;
    appliedStatus = unselectedId;
    appliedVoucherTypeId = unselectedId;
    appliedDateRange = null;
    filtersApplied = false;
    documents = [];
    searchQuery = '';
    currentPage = 1;
    errorMessage = null;
    notifyListeners();
  }

  void setPendingBusiness(String id) {
    pendingBusinessId = id;
    notifyListeners();
  }

  void setPendingStatus(String id) {
    pendingStatus = id;
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
    if (!filtersApplied) {
      notifyListeners();
      return;
    }
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

  static bool _isProcessedAlias(String id) {
    switch (id.trim().toLowerCase()) {
      case 'process':
      case 'processed':
      case 'processes':
      case 'approved':
        return true;
      default:
        return false;
    }
  }

  String _normalizeStatus(String status) {
    final value = status.trim().toLowerCase();
    if (value.isEmpty || value == 'all') return unselectedId;
    if (_isProcessedAlias(value)) return 'processes';
    return value;
  }

  String _sanitizePending(String id, List<DocumentFilterChoice> choices) {
    if (id == unselectedId) return unselectedId;
    return choices.any((choice) => choice.id == id) ? id : unselectedId;
  }

  String _sanitizeApplied(String id, List<DocumentFilterChoice> choices) {
    if (id == unselectedId) return unselectedId;
    return choices.any((choice) => choice.id == id) ? id : unselectedId;
  }

  String _sanitizePendingStatus(String id) {
    if (id == unselectedId) return unselectedId;
    final requested = id.toLowerCase();
    for (final choice in statusChoices) {
      if (choice.id.toLowerCase() == requested) return choice.id;
    }
    if (_isProcessedAlias(id)) {
      for (final choice in statusChoices) {
        if (_isProcessedAlias(choice.id)) return choice.id;
      }
      return 'processes';
    }
    return unselectedId;
  }

  String _sanitizeAppliedStatus(String id) {
    return _sanitizePendingStatus(id);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
