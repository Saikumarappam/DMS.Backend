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

  List<DocumentBusiness> businesses = [];
  List<DocumentCategoryOption> voucherTypes = [];
  List<String> statuses = [];
  List<DocumentItem> documents = [];

  String pendingBusinessId = allId;
  String pendingStatus = allId;
  String pendingVoucherTypeId = allId;
  DateTimeRange? pendingDateRange;

  String appliedBusinessId = allId;
  String appliedStatus = allId;
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
        DocumentFilterChoice.all,
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
      DocumentFilterChoice.all,
      ...apiStatuses,
    ];
    final selected = pendingStatus.isNotEmpty ? pendingStatus : appliedStatus;
    if (_isProcessedAlias(selected) && !choices.any((choice) => _isProcessedAlias(choice.id))) {
      choices.add(const DocumentFilterChoice(id: 'processes', label: 'Processes'));
    }
    return choices;
  }

  List<DocumentFilterChoice> get voucherTypeChoices => [
        DocumentFilterChoice.all,
        ...voucherTypes.map((item) => item.asChoice),
      ];

  String get historyStatus => appliedStatus.trim();

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

  Future<void> load({String? status}) async {
    await loadFilters();
    if (status != null) {
      appliedStatus = _sanitizeStatus(_normalizeStatus(status));
      pendingStatus = appliedStatus;
      notifyListeners();
    }
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

  Future<void> applyFilters() async {
    appliedBusinessId = pendingBusinessId;
    appliedStatus = pendingStatus;
    appliedVoucherTypeId = pendingVoucherTypeId;
    appliedDateRange = pendingDateRange;
    await loadDocuments();
  }

  Future<void> reset() async {
    pendingBusinessId = allId;
    pendingStatus = allId;
    pendingVoucherTypeId = allId;
    pendingDateRange = null;
    appliedBusinessId = allId;
    appliedStatus = allId;
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
    if (value.isEmpty || value == 'all') return allId;
    if (_isProcessedAlias(value)) return 'processes';
    return value;
  }

  String _sanitize(String id, List<DocumentFilterChoice> choices) {
    return choices.any((choice) => choice.id == id) ? id : allId;
  }

  String _sanitizeStatus(String id) {
    if (id.isEmpty) return allId;
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
    return allId;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
