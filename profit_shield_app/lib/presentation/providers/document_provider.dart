import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document_models.dart';
import '../../data/repositories/document_repository.dart';

class DocumentState {
  const DocumentState({
    this.documents = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.error,
    this.filter = const DocumentHistoryFilter(),
  });

  final List<DocumentModel> documents;
  final bool isLoading;
  final bool isUploading;
  final String? error;
  final DocumentHistoryFilter filter;

  DocumentState copyWith({
    List<DocumentModel>? documents,
    bool? isLoading,
    bool? isUploading,
    String? error,
    DocumentHistoryFilter? filter,
    bool clearError = false,
  }) {
    return DocumentState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
    );
  }
}

class DocumentNotifier extends StateNotifier<DocumentState> {
  DocumentNotifier(this._repository) : super(const DocumentState());

  final DocumentRepository _repository;

  Future<void> loadHistory([DocumentHistoryFilter? filter]) async {
    final activeFilter = filter ?? state.filter;
    state = state.copyWith(isLoading: true, clearError: true, filter: activeFilter);
    final result = await _repository.getHistory(activeFilter);
    if (!result.success) {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return;
    }
    state = state.copyWith(
      isLoading: false,
      documents: result.data ?? [],
    );
  }

  Future<String?> upload(UploadFilePayload payload) async {
    state = state.copyWith(isUploading: true, clearError: true);
    final result = await _repository.upload(payload);
    state = state.copyWith(isUploading: false);
    if (!result.success) return result.errorMessage;
    await loadHistory();
    return null;
  }

  Future<DocumentDownloadModel?> download(int fileId) async {
    final result = await _repository.downloadDocument(fileId);
    if (!result.success) return null;
    return result.data;
  }
}

final documentProvider =
    StateNotifierProvider<DocumentNotifier, DocumentState>((ref) {
  return DocumentNotifier(ref.read(documentRepositoryProvider));
});
