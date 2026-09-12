import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/storage/saved_downloads_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/document_file_helper.dart';
import '../providers/saved_downloads_provider.dart';

class SavedDownloadsScreen extends ConsumerWidget {
  const SavedDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(savedDownloadsProvider);
    final dateFormat = DateFormat('dd MMM yyyy • HH:mm');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Downloads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(
              'Files saved on this phone',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: downloadsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => _EmptyState(
          title: 'Could not load downloads',
          subtitle: 'Pull down to try again.',
          onRetry: () => ref.read(savedDownloadsProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState(
              title: 'No downloads yet',
              subtitle:
                  'Download a document from Upload History. It will appear here and also save to Downloads › ProfitShield on your phone.',
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(savedDownloadsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.skyLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.sky),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.folder_outlined, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Saved files are stored in Downloads › ProfitShield and inside this app under My Downloads.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final entry = items[index - 1];
                return _DownloadTile(
                  entry: entry,
                  savedLabel: dateFormat.format(entry.savedAt),
                  onOpen: () => DocumentFileHelper.openSavedFile(
                    DeviceSaveResult(
                      message: '',
                      openPath: entry.appPath,
                      openUri: entry.publicPath,
                      savedFileName: entry.fileName,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.entry,
    required this.savedLabel,
    required this.onOpen,
  });

  final SavedDownloadEntry entry;
  final String savedLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sky),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.skyLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.displayLocation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      savedLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_done_rounded, size: 56, color: AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
