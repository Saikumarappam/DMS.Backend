import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/saved_downloads_storage.dart';

final savedDownloadsProvider =
    AsyncNotifierProvider<SavedDownloadsNotifier, List<SavedDownloadEntry>>(
  SavedDownloadsNotifier.new,
);

class SavedDownloadsNotifier extends AsyncNotifier<List<SavedDownloadEntry>> {
  @override
  Future<List<SavedDownloadEntry>> build() => _load();

  Future<List<SavedDownloadEntry>> _load() {
    return ref.read(savedDownloadsStorageProvider).loadAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }
}
