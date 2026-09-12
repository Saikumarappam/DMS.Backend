import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/invoice_number.dart';
import '../../data/models/document_models.dart';
import '../../data/repositories/document_repository.dart';
import 'dashboard_provider.dart';

class UploadFlowState {
  const UploadFlowState({
    this.categoryId,
    this.categoryName,
    this.fileName,
    this.bytes,
    this.source = 'Camera',
    this.isUploading = false,
  });

  final int? categoryId;
  final String? categoryName;
  final String? fileName;
  final List<int>? bytes;
  final String source;
  final bool isUploading;

  UploadFlowState copyWith({
    int? categoryId,
    String? categoryName,
    String? fileName,
    List<int>? bytes,
    String? source,
    bool? isUploading,
    bool clearFile = false,
  }) {
    return UploadFlowState(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      fileName: clearFile ? null : (fileName ?? this.fileName),
      bytes: clearFile ? null : (bytes ?? this.bytes),
      source: source ?? this.source,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class UploadFlowNotifier extends StateNotifier<UploadFlowState> {
  UploadFlowNotifier(this._repository) : super(const UploadFlowState());

  final DocumentRepository _repository;

  void setCategory(int id, String name) {
    state = state.copyWith(categoryId: id, categoryName: name, clearFile: true);
  }

  void setFile({
    required String fileName,
    required List<int> bytes,
    required String source,
  }) {
    state = state.copyWith(fileName: fileName, bytes: bytes, source: source);
  }

  Future<String?> submit() async {
    if (state.categoryId == null || state.bytes == null || state.fileName == null) {
      return 'Please select a file to upload.';
    }

    state = state.copyWith(isUploading: true);

    final result = await _repository.upload(
      UploadFilePayload(
        categoryId: state.categoryId!,
        source: state.source,
        fileName: state.fileName!,
        bytes: state.bytes!,
      ),
    );

    state = state.copyWith(isUploading: false);

    if (!result.success) {
      return result.errorMessage ?? 'Upload failed. Please try again.';
    }

    state = state.copyWith(clearFile: true);
    return null;
  }

  void reset() => state = const UploadFlowState();
}

final uploadFlowProvider =
    StateNotifierProvider<UploadFlowNotifier, UploadFlowState>((ref) {
  return UploadFlowNotifier(ref.read(documentRepositoryProvider));
});

final uploadSuccessProvider = StateProvider<bool>((ref) => false);

class HistoryFilterState {
  const HistoryFilterState({
    this.categoryId,
    this.fromDate,
    this.toDate,
  });

  final int? categoryId;
  final DateTime? fromDate;
  final DateTime? toDate;

  static HistoryFilterState initial() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return HistoryFilterState(
      categoryId: DocumentHistoryFilter.allCategoriesId,
      fromDate: today.subtract(const Duration(days: 7)),
      toDate: today,
    );
  }

  HistoryFilterState copyWith({
    int? categoryId,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearCategory = false,
    bool clearFromDate = false,
    bool clearToDate = false,
  }) {
    return HistoryFilterState(
      categoryId: clearCategory
          ? DocumentHistoryFilter.allCategoriesId
          : (categoryId ?? this.categoryId),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }
}

final historyFilterProvider =
    StateProvider<HistoryFilterState>((ref) => HistoryFilterState.initial());

DateTime? _startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime? _endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

final documentHistoryProvider = FutureProvider<List<DocumentModel>>((ref) async {
  ref.watch(uploadSuccessProvider);
  final filter = ref.watch(historyFilterProvider);

  final result = await ref.read(documentRepositoryProvider).getHistory(
        DocumentHistoryFilter(
          categoryId: filter.categoryId ?? DocumentHistoryFilter.allCategoriesId,
          fromDate: filter.fromDate != null ? _startOfDay(filter.fromDate!) : null,
          toDate: filter.toDate != null ? _endOfDay(filter.toDate!) : null,
        ),
      );
  if (!result.success) {
    final message = result.errorMessage.toLowerCase();
    if (message.contains('no data') ||
        message.contains('not found') ||
        message.contains('no record')) {
      return <DocumentModel>[];
    }
    throw Exception(result.errorMessage);
  }

  return result.data ?? [];
});

/// Full history (no filters) used for dashboard dates and invoice numbers.
final documentFullHistoryProvider =
    FutureProvider<List<DocumentModel>>((ref) async {
  ref.watch(uploadSuccessProvider);

  final result = await ref.read(documentRepositoryProvider).getHistory(
        const DocumentHistoryFilter(
          categoryId: DocumentHistoryFilter.allCategoriesId,
        ),
      );
  if (!result.success) {
    final message = result.errorMessage.toLowerCase();
    if (message.contains('no data') ||
        message.contains('not found') ||
        message.contains('no record')) {
      return <DocumentModel>[];
    }
    throw Exception(result.errorMessage);
  }

  return result.data ?? [];
});

/// Full history (no filters) used to assign stable per-category invoice numbers.
final documentInvoiceNumbersProvider =
    FutureProvider<Map<int, Map<int, int>>>((ref) async {
  final history = await ref.watch(documentFullHistoryProvider.future);
  return InvoiceNumberHelper.numbersByCategory(history);
});

/// Clears client session providers on logout.
void resetClientSession(WidgetRef ref) {
  ref.read(historyFilterProvider.notifier).state = HistoryFilterState.initial();
  ref.read(uploadFlowProvider.notifier).reset();
  ref.read(dashboardProvider.notifier).reset();
  ref.invalidate(documentHistoryProvider);
  ref.invalidate(documentFullHistoryProvider);
  ref.invalidate(documentInvoiceNumbersProvider);
}

String friendlyApiError(Object error) {
  return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}
