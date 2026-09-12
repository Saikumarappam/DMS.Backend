import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/document_file_helper.dart';
import '../../data/mock/mock_category_data.dart';
import '../../data/models/category_models.dart';
import '../../data/models/document_models.dart';
import '../../data/repositories/document_repository.dart';
import '../providers/category_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/upload_flow_provider.dart';
import '../widgets/history_date_filter_sheet.dart';
import '../widgets/profit_shield_widgets.dart';
import 'document_viewer_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int? _loadingFileId;
  int? _downloadingFileId;
  int? _deletingFileId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      ref.read(categoryProvider.notifier).load();
      await ref.read(dashboardProvider.notifier).loadClientDashboard();
    });
  }

  String? _selectedCategoryName(HistoryFilterState filter, List<CategoryModel> categories) {
    if (filter.categoryId == null ||
        filter.categoryId == DocumentHistoryFilter.allCategoriesId) {
      return null;
    }
    for (final category in categories) {
      if (category.categoryId == filter.categoryId) return category.categoryName;
    }
    return null;
  }

  List<DocumentModel> _sort(List<DocumentModel> items) {
    final sorted = List<DocumentModel>.from(items);
    sorted.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    return sorted;
  }

  List<CategoryModel> _orderedCategories() {
    final dashboardCategories =
        ref.read(dashboardProvider).dashboard?.categories.where((c) => c.isActive).toList() ??
            const [];

    if (dashboardCategories.isNotEmpty) {
      return dashboardCategories
          .map(
            (c) => CategoryModel(
              categoryId: c.categoryId,
              categoryName: c.categoryName,
              isActive: c.isActive,
            ),
          )
          .toList();
    }

    final categories = ref.read(categoryProvider).categories.where((c) => c.isActive).toList()
      ..sort((a, b) => a.categoryId.compareTo(b.categoryId));
    return categories;
  }

  Future<void> _pickDateRange() async {
    final filter = ref.read(historyFilterProvider);
    final result = await showHistoryDateFilterSheet(
      context: context,
      initialFromDate: filter.fromDate,
      initialToDate: filter.toDate,
    );
    if (result == null || !result.hasFilter) return;

    ref.read(historyFilterProvider.notifier).state = filter.copyWith(
      fromDate: result.fromDate,
      toDate: result.toDate,
      clearToDate: result.toDate == null,
    );
  }

  String _dateRangeLabel(HistoryFilterState filter, DateFormat dayFormat) {
    if (filter.fromDate != null && filter.toDate != null) {
      return '${dayFormat.format(filter.fromDate!)} – ${dayFormat.format(filter.toDate!)}';
    }
    if (filter.fromDate != null) {
      return 'From ${dayFormat.format(filter.fromDate!)}';
    }
    return 'Date range';
  }

  void _clearDates() {
    ref.read(historyFilterProvider.notifier).state =
        ref.read(historyFilterProvider).copyWith(clearFromDate: true, clearToDate: true);
  }

  Future<void> _refreshHistory() async {
    ref.invalidate(documentHistoryProvider);
    ref.invalidate(documentFullHistoryProvider);
    await ref.read(dashboardProvider.notifier).loadClientDashboard();
  }

  Future<DocumentDownloadModel?> _fetchDocument(int fileId) async {
    setState(() => _loadingFileId = fileId);
    final result = await ref.read(documentRepositoryProvider).downloadDocument(fileId);
    if (!mounted) return null;
    setState(() => _loadingFileId = null);

    if (!result.success || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Could not load document.'),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }
    return result.data;
  }

  Future<void> _viewDocument(DocumentModel doc) async {
    final file = await _fetchDocument(doc.fileId);
    if (file == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerScreen(
          file: file,
          title: doc.displayLabel,
        ),
      ),
    );
  }

  Future<void> _downloadDocument(DocumentModel doc) async {
    setState(() => _downloadingFileId = doc.fileId);

    try {
      final result = await ref.read(documentRepositoryProvider).downloadDocument(doc.fileId);
      if (!mounted) return;

      if (!result.success || result.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Could not download file.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final saveResult = await DocumentFileHelper.saveToDevice(
        result.data!,
        sourceFileId: doc.fileId,
      );
      if (!mounted) return;

      final savedName = saveResult.savedFileName ?? doc.displayLabel;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('${saveResult.message}\n$savedName'),
          action: saveResult.canOpen
              ? SnackBarAction(
                  label: 'Open',
                  onPressed: () => DocumentFileHelper.openSavedFile(saveResult),
                )
              : null,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is Exception
                ? error.toString().replaceFirst('Exception: ', '')
                : 'Could not save file. Please try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingFileId = null);
    }
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    if (!doc.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only pending invoices can be deleted.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: Text(
          'Delete ${doc.displayLabel} permanently? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingFileId = doc.fileId);
    final result = await ref.read(documentRepositoryProvider).deleteDocument(doc.fileId);
    if (!mounted) return;
    setState(() => _deletingFileId = null);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Could not delete invoice.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    ref.read(uploadSuccessProvider.notifier).state = true;
    await _refreshHistory();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${doc.displayLabel}')),
    );
  }

  Widget _buildFilterChips({
    required HistoryFilterState filter,
    required List<CategoryModel> categories,
    required DateFormat dayFormat,
  }) {
    final hasDateFilter = filter.fromDate != null;

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _CategoryFilterChip(
              label: hasDateFilter ? _dateRangeLabel(filter, dayFormat) : 'Date',
              icon: Icons.calendar_today_outlined,
              selected: hasDateFilter,
              onTap: _pickDateRange,
            ),
          ),
          if (hasDateFilter)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _CategoryFilterChip(
                label: 'Clear',
                icon: Icons.close_rounded,
                selected: false,
                onTap: _clearDates,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _CategoryFilterChip(
              label: 'All',
              icon: Icons.apps_rounded,
              selected: filter.categoryId == null ||
                  filter.categoryId == DocumentHistoryFilter.allCategoriesId,
              onTap: () {
                ref.read(historyFilterProvider.notifier).state = filter.copyWith(
                  categoryId: DocumentHistoryFilter.allCategoriesId,
                );
              },
            ),
          ),
          ...categories.map((category) {
            final selected = filter.categoryId == category.categoryId;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _CategoryFilterChip(
                label: category.categoryName,
                icon: MockCategoryData.iconFor(category.categoryName),
                selected: selected,
                onTap: () {
                  ref.read(historyFilterProvider.notifier).state = filter.copyWith(
                    categoryId: category.categoryId,
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(documentHistoryProvider);
    final filter = ref.watch(historyFilterProvider);
    ref.watch(dashboardProvider);
    final categories = _orderedCategories();
    final dateFormat = DateFormat('dd MMM yyyy • HH:mm');
    final dayFormat = DateFormat('dd MMM');

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: const Text(
                'Upload History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            historyAsync.when(
              data: (items) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '${_sort(items).length} document(s)',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Loading...',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            _buildFilterChips(filter: filter, categories: categories, dayFormat: dayFormat),
            const SizedBox(height: 8),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          friendlyApiError(error),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _refreshHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  final sorted = _sort(items);
                  if (sorted.isEmpty) {
                    return _HistoryEmptyState(
                      categoryName: _selectedCategoryName(filter, categories),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _refreshHistory,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = sorted[index];
                        final isCamera = doc.source.toLowerCase() == 'camera';
                        final isLoading =
                            _loadingFileId == doc.fileId || _downloadingFileId == doc.fileId;
                        final isDeleting = _deletingFileId == doc.fileId;
                        return _HistoryCard(
                          index: index,
                          fileName: doc.displayLabel,
                          category: doc.categoryName,
                          date: dateFormat.format(doc.uploadDate),
                          statusLabel: doc.statusLabel,
                          isPending: doc.isPending,
                          icon: isCamera
                              ? Icons.camera_alt_outlined
                              : Icons.description_outlined,
                          isLoading: isLoading || isDeleting,
                          onView: () => _viewDocument(doc),
                          onDownload: () => _downloadDocument(doc),
                          onDelete: doc.isPending ? () => _deleteDocument(doc) : null,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary;
    final iconColor = selected ? Colors.white : AppColors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.sky,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({this.categoryName});

  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _HistoryEmptyIllustration(),
            const SizedBox(height: 28),
            const Text(
              'No documents here yet!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (categoryName != null)
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                  children: [
                    const TextSpan(
                      text: "It looks like you haven't uploaded any documents in ",
                    ),
                    TextSpan(
                      text: categoryName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: ' category.'),
                  ],
                ),
              )
            else
              const Text(
                "It looks like you haven't uploaded any documents yet.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmptyIllustration extends StatelessWidget {
  const _HistoryEmptyIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            bottom: 18,
            child: Container(
              width: 28,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 18,
                    height: 10,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 24,
            top: 18,
            child: Transform.rotate(
              angle: -0.3,
              child: Icon(
                Icons.send_rounded,
                size: 28,
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
          Container(
            width: 120,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF3B8BEB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B8BEB),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
              Container(
                width: 110,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -28,
                      left: 28,
                      child: Container(
                        width: 54,
                        height: 68,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 20,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.sky,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.textMuted, width: 1.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.textMuted, width: 1.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({
    required this.index,
    required this.fileName,
    required this.category,
    required this.date,
    required this.statusLabel,
    required this.isPending,
    required this.icon,
    required this.isLoading,
    required this.onView,
    required this.onDownload,
    this.onDelete,
  });

  final int index;
  final String fileName;
  final String category;
  final String date;
  final String statusLabel;
  final bool isPending;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback? onDelete;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    Future<void>.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sky),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon3D(icon: widget.icon, size: 18, padding: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.category,
                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.date,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.isPending
                          ? AppColors.gold.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: widget.isPending ? AppColors.goldDark : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionLink(
                    icon: Icons.visibility_outlined,
                    label: 'View',
                    onTap: widget.onView,
                  ),
                  const SizedBox(height: 2),
                  _ActionLink(
                    icon: Icons.download_outlined,
                    label: 'Download',
                    onTap: widget.onDownload,
                  ),
                  if (widget.onDelete != null) ...[
                    const SizedBox(height: 2),
                    _ActionLink(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: AppColors.error,
                      onTap: widget.onDelete!,
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
