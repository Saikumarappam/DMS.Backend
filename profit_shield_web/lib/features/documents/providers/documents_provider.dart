import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/error/app_error_handler.dart';
import '../data/documents_repository.dart';
import '../models/document_model.dart';

enum DocumentSort { newest, oldest, nameAsc, nameDesc }

class DocumentsProvider extends ChangeNotifier {
  DocumentsProvider(this._repository);

  final DocumentsRepository _repository;

  static const pageSize = 6;
  static const allId = '';
  static const defaultStatus = 'pending';

  List<DocumentBusiness> businesses = [];
  List<DocumentCategoryOption> categories = [];
  List<DocumentItem> documents = [];

  String pendingBusinessId = allId;
  String pendingCategoryId = allId;

  String appliedBusinessId = allId;
  String appliedCategoryId = allId;
  String searchQuery = '';
  DocumentSort sort = DocumentSort.newest;
  int currentPage = 1;
  int pendingCount = 0;
  bool isLoading = false;
  bool isLoadingFilters = false;
  bool isActing = false;
  String? errorMessage;
  Timer? _searchDebounce;
  bool _pendingCountRequested = false;

  bool get _isUnfilteredPending =>
      appliedBusinessId.isEmpty && appliedCategoryId.isEmpty && searchQuery.trim().isEmpty;

  List<DocumentFilterChoice> get businessChoices => [
        DocumentFilterChoice.allBusinesses,
        ...businesses.map((item) => item.asChoice),
      ];

  List<DocumentFilterChoice> get categoryChoices => [
        DocumentFilterChoice.allCategories,
        ...categories.map((item) => item.asChoice),
      ];

  List<DocumentItem> get sortedDocuments {
    final list = [...documents];
    list.sort((a, b) {
      switch (sort) {
        case DocumentSort.newest:
          return (b.uploadedOn ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.uploadedOn ?? DateTime.fromMillisecondsSinceEpoch(0));
        case DocumentSort.oldest:
          return (a.uploadedOn ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.uploadedOn ?? DateTime.fromMillisecondsSinceEpoch(0));
        case DocumentSort.nameAsc:
          return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
        case DocumentSort.nameDesc:
          return b.fileName.toLowerCase().compareTo(a.fileName.toLowerCase());
      }
    });
    return list;
  }

  int get totalPages {
    final count = sortedDocuments.length;
    if (count == 0) return 1;
    return (count / pageSize).ceil();
  }

  List<DocumentItem> get pagedDocuments {
    final items = sortedDocuments;
    if (items.isEmpty) return const [];
    final start = (currentPage - 1) * pageSize;
    if (start >= items.length) return const [];
    return items.sublist(start, (start + pageSize).clamp(0, items.length));
  }

  Future<void> load() async {
    await loadFilters();
    await loadDocuments();
  }

  Future<void> loadFilters() async {
    isLoadingFilters = true;
    notifyListeners();
    try {
      final result = await _repository.fetchFilterOptions();
      businesses = result.businesses;
      categories = result.categories;
      pendingBusinessId = _sanitizeChoice(pendingBusinessId, businessChoices);
      pendingCategoryId = _sanitizeChoice(pendingCategoryId, categoryChoices);
      appliedBusinessId = _sanitizeChoice(appliedBusinessId, businessChoices);
      appliedCategoryId = _sanitizeChoice(appliedCategoryId, categoryChoices);
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
        categoryId: int.tryParse(appliedCategoryId),
        searchFileName: searchQuery,
        status: defaultStatus,
      );
      currentPage = 1;
      if (_isUnfilteredPending) {
        pendingCount = documents.length;
        _pendingCountRequested = true;
      } else {
        unawaited(refreshPendingCount());
      }
    } catch (e) {
      errorMessage = AppErrorHandler.from(e);
      documents = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensurePendingCount() async {
    if (_pendingCountRequested) return;
    await refreshPendingCount();
  }

  Future<void> refreshPendingCount() async {
    _pendingCountRequested = true;
    try {
      final items = await _repository.fetchHistory(status: defaultStatus);
      pendingCount = items.length;
    } catch (_) {
      // Keep the last known count if the badge refresh fails.
    } finally {
      notifyListeners();
    }
  }

  Future<void> applyFilters() async {
    appliedBusinessId = pendingBusinessId;
    appliedCategoryId = pendingCategoryId;
    await loadDocuments();
  }

  Future<void> reset() async {
    pendingBusinessId = allId;
    pendingCategoryId = allId;
    appliedBusinessId = allId;
    appliedCategoryId = allId;
    searchQuery = '';
    sort = DocumentSort.newest;
    currentPage = 1;
    notifyListeners();
    await loadDocuments();
  }

  void setPendingBusiness(String id) {
    pendingBusinessId = id;
    notifyListeners();
  }

  void setPendingCategory(String id) {
    pendingCategoryId = id;
    notifyListeners();
  }

  void setSearch(String value) {
    searchQuery = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), loadDocuments);
    notifyListeners();
  }

  void setSort(DocumentSort value) {
    sort = value;
    currentPage = 1;
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
      await refreshPendingCount();
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
      await refreshPendingCount();
      return null;
    } catch (e) {
      return AppErrorHandler.from(e);
    } finally {
      isActing = false;
      notifyListeners();
    }
  }

  String _sanitizeChoice(String id, List<DocumentFilterChoice> choices) {
    final exists = choices.any((choice) => choice.id == id);
    return exists ? id : allId;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
