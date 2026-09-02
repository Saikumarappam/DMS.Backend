import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/web_file_download.dart';
import '../../dashboard/presentation/widgets/admin_shell.dart';
import '../../documents/models/document_model.dart';
import '../../documents/presentation/widgets/document_preview_image.dart';
import '../../user_approvals/presentation/widgets/admin_password_dialog.dart';
import '../providers/categories_provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoriesProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoriesProvider>();
    if (_searchController.text != provider.searchQuery && provider.searchQuery.isEmpty) {
      _searchController.clear();
    }

    final paged = provider.pagedDocuments;
    final startIndex = provider.documents.isEmpty
        ? 0
        : ((provider.currentPage - 1) * CategoriesProvider.pageSize);

    return AdminShell(
      selectedLabel: 'Categories',
      title: 'Categories',
      isLoading: (provider.isLoading || provider.isLoadingFilters) && provider.documents.isEmpty,
      onRefresh: () => provider.load(),
      child: RefreshIndicator(
        onRefresh: () => provider.load(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < Breakpoints.contentCompact;
            final stackFilters = width < 1100;
            final padding = compact ? 12.0 : 20.0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(padding, 8, padding, padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageHeader(compact: compact),
                  SizedBox(height: compact ? 16 : 20),
                  _FiltersCard(
                    compact: stackFilters,
                    enabled: !provider.isLoadingFilters,
                    busy: provider.isLoading,
                    businessId: provider.pendingBusinessId,
                    statusId: provider.pendingStatus,
                    voucherTypeId: provider.pendingVoucherTypeId,
                    dateRange: provider.pendingDateRange,
                    businesses: provider.businessChoices,
                    statuses: provider.statusChoices,
                    voucherTypes: provider.voucherTypeChoices,
                    onBusinessChanged: provider.setPendingBusiness,
                    onStatusChanged: provider.setPendingStatus,
                    onVoucherTypeChanged: provider.setPendingVoucherType,
                    onPickDates: () => _pickDates(context, provider),
                    onClearDates: () => provider.setPendingDateRange(null),
                    onApply: () => provider.applyFilters(),
                    onReset: () {
                      _searchController.clear();
                      provider.reset();
                    },
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  _SummaryRow(
                    compact: compact,
                    processed: provider.processedCount,
                    deleted: provider.deletedCount,
                    total: provider.totalCount,
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  _DocumentsListCard(
                    compact: compact,
                    contentWidth: width,
                    isLoading: provider.isLoading,
                    errorMessage: provider.errorMessage,
                    onRetry: () => provider.loadDocuments(),
                    searchController: _searchController,
                    onSearchChanged: provider.setSearch,
                    documents: paged,
                    startIndex: startIndex,
                    currentPage: provider.currentPage,
                    totalPages: provider.totalPages,
                    totalItems: provider.documents.length,
                    onPageChanged: provider.setPage,
                    onView: _showPreview,
                    onDownload: _download,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickDates(BuildContext context, CategoriesProvider provider) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: provider.pendingDateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) {
      provider.setPendingDateRange(picked);
    }
  }

  Future<void> _download(DocumentItem doc) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Downloading ${doc.fileName}…')));
    try {
      final file = await context.read<CategoriesProvider>().download(doc);
      saveBytesToFile(
        fileName: file.fileName.isNotEmpty ? file.fileName : doc.fileName,
        bytes: file.bytes,
        mimeType: file.contentType.isNotEmpty ? file.contentType : doc.resolvedContentType,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.from(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmApprove(DocumentItem doc) async {
    if (!await showAdminPasswordDialog(context)) return;
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Document'),
        content: Text('Approve ${doc.fileName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final error = await context.read<CategoriesProvider>().approve(doc);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document approved successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmDelete(DocumentItem doc) async {
    if (!await showAdminPasswordDialog(context)) return;
    if (!mounted) return;

    final remarksController = TextEditingController();
    var remarks = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? fieldError;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Delete Document'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete ${doc.fileName}?'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksController,
                    autofocus: true,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Remarks',
                      hintText: 'Enter remarks',
                      border: const OutlineInputBorder(),
                      errorText: fieldError,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                onPressed: () {
                  remarks = remarksController.text.trim();
                  if (remarks.isEmpty) {
                    setState(() => fieldError = 'Please enter remarks.');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
    remarksController.dispose();
    if (ok != true || !mounted) return;
    if (remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter remarks.')),
      );
      return;
    }

    final error = await context.read<CategoriesProvider>().delete(doc, remarks: remarks);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document deleted.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _showPreview(DocumentItem doc) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final dialogWidth = size.width < 520 ? size.width - 48.0 : 460.0;
        return AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(doc.fileName, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.65),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DocumentPreviewImage(document: doc, large: true),
                    const SizedBox(height: 16),
                    _MetaRow(label: 'Business', value: doc.businessName.isEmpty ? '—' : doc.businessName),
                    _MetaRow(label: 'Client', value: doc.uploaderName.isEmpty ? '—' : doc.uploaderName),
                    if (doc.gstin.isNotEmpty) _MetaRow(label: 'GSTIN', value: doc.gstin),
                    _MetaRow(label: 'Category', value: doc.categoryName),
                    _MetaRow(label: 'Status', value: doc.status.isEmpty ? 'Pending' : doc.status),
                    _MetaRow(
                      label: 'Created',
                      value: doc.uploadedOn == null
                          ? '—'
                          : DateFormat('dd MMM yyyy, hh:mm a').format(doc.uploadedOn!),
                    ),
                    _MetaRow(label: 'File Type', value: doc.fileTypeLabel),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actionsAlignment: MainAxisAlignment.start,
          actions: [
            _CategoryPreviewActions(
              onDelete: () {
                Navigator.pop(ctx);
                _confirmDelete(doc);
              },
              onApprove: () {
                Navigator.pop(ctx);
                _confirmApprove(doc);
              },
              onDownload: () {
                Navigator.pop(ctx);
                _download(doc);
              },
            ),
          ],
        );
      },
    );
  }
}

class _CategoryPreviewActions extends StatelessWidget {
  const _CategoryPreviewActions({
    required this.onDelete,
    required this.onApprove,
    required this.onDownload,
  });

  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final compactAction = ElevatedButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );

    return SizedBox(
      width: double.maxFinite,
      child: Row(
        children: [
          ElevatedButton(
            style: compactAction.copyWith(
              backgroundColor: const WidgetStatePropertyAll(AppColors.danger),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
            onPressed: onDelete,
            child: const Text('Delete'),
          ),
          // const SizedBox(width: 8),
          // ElevatedButton(
          //   style: compactAction.copyWith(
          //     backgroundColor: const WidgetStatePropertyAll(Color(0xFF16A34A)),
          //     foregroundColor: const WidgetStatePropertyAll(Colors.white),
          //   ),
          //   onPressed: onApprove,
          //   child: const Text('Approve'),
          // ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Close', style: TextStyle(color: AppColors.navy)),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: TextStyle(
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage and view processed, approved and deleted documents',
            style: TextStyle(fontSize: compact ? 13 : 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.compact,
    required this.enabled,
    required this.busy,
    required this.businessId,
    required this.statusId,
    required this.voucherTypeId,
    required this.dateRange,
    required this.businesses,
    required this.statuses,
    required this.voucherTypes,
    required this.onBusinessChanged,
    required this.onStatusChanged,
    required this.onVoucherTypeChanged,
    required this.onPickDates,
    required this.onClearDates,
    required this.onApply,
    required this.onReset,
  });

  final bool compact;
  final bool enabled;
  final bool busy;
  final String businessId;
  final String statusId;
  final String voucherTypeId;
  final DateTimeRange? dateRange;
  final List<DocumentFilterChoice> businesses;
  final List<DocumentFilterChoice> statuses;
  final List<DocumentFilterChoice> voucherTypes;
  final ValueChanged<String> onBusinessChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onVoucherTypeChanged;
  final VoidCallback onPickDates;
  final VoidCallback onClearDates;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final fields = [
      _FilterDropdown(
        label: 'Business Name',
        value: businessId,
        icon: Icons.business_outlined,
        items: businesses,
        enabled: enabled,
        onChanged: onBusinessChanged,
      ),
      _FilterDropdown(
        label: 'Status',
        value: statusId,
        icon: Icons.verified_user_outlined,
        items: statuses,
        enabled: enabled,
        onChanged: onStatusChanged,
      ),
      _FilterDropdown(
        label: 'Voucher Type',
        value: voucherTypeId,
        icon: Icons.description_outlined,
        items: voucherTypes,
        enabled: enabled,
        onChanged: onVoucherTypeChanged,
      ),
      _DateRangeField(dateRange: dateRange, onTap: onPickDates, onClear: onClearDates),
    ];

    final actions = _FilterActions(
      compact: compact,
      enabled: enabled && !busy,
      onApply: onApply,
      onReset: onReset,
    );

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: _cardDecoration,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  fields[i],
                ],
                const SizedBox(height: 16),
                actions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: fields[i]),
                ],
                const SizedBox(width: 12),
                actions,
              ],
            ),
    );
  }
}

class _FilterActions extends StatelessWidget {
  const _FilterActions({
    required this.compact,
    required this.onApply,
    required this.onReset,
    this.enabled = true,
  });

  final bool compact;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final apply = FilledButton.icon(
      onPressed: enabled ? onApply : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: Size(compact ? 0 : 108, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.filter_alt_outlined, size: 18),
      label: const Text('Apply'),
    );
    final reset = OutlinedButton.icon(
      onPressed: enabled ? onReset : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: Size(compact ? 0 : 108, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Reset'),
    );

    if (!compact) {
      return Row(children: [apply, const SizedBox(width: 10), reset]);
    }
    return Row(
      children: [
        Expanded(child: apply),
        const SizedBox(width: 10),
        Expanded(child: reset),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<DocumentFilterChoice> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selected = items.any((item) => item.id == value)
        ? value
        : (items.isNotEmpty ? items.first.id : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
              items: [
                for (final item in items)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: enabled
                  ? (choice) {
                      if (choice != null) onChanged(choice);
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.dateRange,
    required this.onTap,
    required this.onClear,
  });

  final DateTimeRange? dateRange;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = dateRange == null
        ? 'Select Date Range'
        : '${DateFormat('dd MMM yyyy').format(dateRange!.start)} – ${DateFormat('dd MMM yyyy').format(dateRange!.end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date Range',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 18),
              suffixIcon: dateRange == null
                  ? const Icon(Icons.date_range_outlined, color: AppColors.textSecondary, size: 20)
                  : IconButton(
                      tooltip: 'Clear dates',
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                color: dateRange == null ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.compact,
    required this.processed,
    required this.deleted,
    required this.total,
  });

  final bool compact;
  final int processed;
  final int deleted;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        title: 'Processed',
        value: '$processed',
        subtitle: 'Approved documents',
        icon: Icons.check_circle,
        iconColor: const Color(0xFF16A34A),
        background: const Color(0xFFECFDF3),
        border: const Color(0xFFBBF7D0),
      ),
      _SummaryCard(
        title: 'Deleted',
        value: '$deleted',
        subtitle: 'Deleted documents',
        icon: Icons.delete_outline,
        iconColor: const Color(0xFFDC2626),
        background: const Color(0xFFFEF2F2),
        border: const Color(0xFFFECACA),
      ),
      _SummaryCard(
        title: 'All Documents',
        value: '$total',
        subtitle: 'Total documents',
        icon: Icons.description_outlined,
        iconColor: const Color(0xFF2563EB),
        background: const Color(0xFFEFF6FF),
        border: const Color(0xFFBFDBFE),
      ),
    ];

    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            cards[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.border,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: iconColor)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsListCard extends StatelessWidget {
  const _DocumentsListCard({
    required this.compact,
    required this.contentWidth,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.searchController,
    required this.onSearchChanged,
    required this.documents,
    required this.startIndex,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPageChanged,
    required this.onView,
    required this.onDownload,
  });

  final bool compact;
  final double contentWidth;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<DocumentItem> documents;
  final int startIndex;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<DocumentItem> onView;
  final ValueChanged<DocumentItem> onDownload;

  @override
  Widget build(BuildContext context) {
    final useCards = contentWidth < 860;

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 20, compact ? 14 : 20, compact ? 14 : 20, 8),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ListToolbar(
            compact: compact || contentWidth < 980,
            searchController: searchController,
            onSearchChanged: onSearchChanged,
          ),
          if (isLoading && documents.isNotEmpty) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 16),
          if (isLoading && documents.isEmpty)
            const SizedBox(height: 280)
          else if (errorMessage != null)
            DocumentsErrorState(
              message: AppErrorHandler.getErrorMessage(errorMessage),
              onRetry: onRetry,
            )
          else if (documents.isEmpty)
            const DocumentsEmptyState()
          else if (useCards)
            Column(
              children: [
                for (var i = 0; i < documents.length; i++) ...[
                  _DocumentCard(
                    index: startIndex + i + 1,
                    document: documents[i],
                    onView: () => onView(documents[i]),
                    onDownload: () => onDownload(documents[i]),
                  ),
                  if (i != documents.length - 1) const SizedBox(height: 10),
                ],
              ],
            )
          else
            _DocumentsTable(
              documents: documents,
              startIndex: startIndex,
              onView: onView,
              onDownload: onDownload,
            ),
          if (errorMessage == null && documents.isNotEmpty)
            _PaginationBar(
              currentPage: currentPage,
              totalPages: totalPages,
              totalItems: totalItems,
              pageSize: CategoriesProvider.pageSize,
              compact: compact,
              onPageChanged: onPageChanged,
            ),
        ],
      ),
    );
  }
}

class _ListToolbar extends StatelessWidget {
  const _ListToolbar({
    required this.compact,
    required this.searchController,
    required this.onSearchChanged,
  });

  final bool compact;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final title = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents List',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        SizedBox(height: 2),
        Text(
          'Showing documents based on selected filters',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );

    final search = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 320, minWidth: 180),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by invoice number, business name...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 14),
          search,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        search,
      ],
    );
  }
}

class _DocumentsTable extends StatelessWidget {
  const _DocumentsTable({
    required this.documents,
    required this.startIndex,
    required this.onView,
    required this.onDownload,
  });

  final List<DocumentItem> documents;
  final int startIndex;
  final ValueChanged<DocumentItem> onView;
  final ValueChanged<DocumentItem> onDownload;

  static const _minWidth = 1140.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < _minWidth ? _minWidth : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                const _TableHeader(),
                for (var i = 0; i < documents.length; i++)
                  _TableRow(
                    index: startIndex + i + 1,
                    document: documents[i],
                    striped: i.isOdd,
                    onView: () => onView(documents[i]),
                    onDownload: () => onDownload(documents[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          _Cell(flex: 5, child: Text('#', style: style)),
          _Cell(flex: 18, child: Text('Business Name', style: style)),
          _Cell(flex: 14, child: Text('Invoice Number', style: style)),
          _Cell(flex: 12, child: Text('Category', style: style)),
          _Cell(flex: 10, child: Text('Status', style: style)),
          _Cell(flex: 12, child: Text('Created Date', style: style)),
          _Cell(flex: 8, child: Text('File Type', style: style)),
          _Cell(flex: 12, child: Text('Preview', style: style)),
          _Cell(flex: 10, child: Text('Action', style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.index,
    required this.document,
    required this.striped,
    required this.onView,
    required this.onDownload,
  });

  final int index;
  final DocumentItem document;
  final bool striped;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: striped ? const Color(0xFFFCFCFD) : Colors.white,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _Cell(flex: 5, child: Text('$index', style: const TextStyle(fontWeight: FontWeight.w600))),
          _Cell(flex: 18, child: _BusinessCell(document: document)),
          _Cell(
            flex: 14,
            child: Text(document.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          _Cell(flex: 12, child: _CategoryChip(name: document.categoryName)),
          _Cell(flex: 10, child: _StatusChip(status: document.status)),
          _Cell(flex: 12, child: _CreatedCell(date: document.uploadedOn)),
          _Cell(flex: 8, child: _FileTypeChip(type: document.fileTypeLabel)),
          _Cell(
            flex: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DocumentPreviewImage(document: document, onTap: onView),
            ),
          ),
          _Cell(
            flex: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundIconButton(icon: Icons.visibility_outlined, tooltip: 'View', onTap: onView),
                const SizedBox(width: 8),
                _RoundIconButton(icon: Icons.download_outlined, tooltip: 'Download', onTap: onDownload),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.index,
    required this.document,
    required this.onView,
    required this.onDownload,
  });

  final int index;
  final DocumentItem document;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$index', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              Expanded(child: _BusinessCell(document: document)),
              _FileTypeChip(type: document.fileTypeLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text(document.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CategoryChip(name: document.categoryName),
              _StatusChip(status: document.status),
            ],
          ),
          const SizedBox(height: 10),
          _CreatedCell(date: document.uploadedOn),
          const SizedBox(height: 10),
          DocumentPreviewImage(document: document, onTap: onView),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _RoundIconButton(icon: Icons.visibility_outlined, tooltip: 'View', onTap: onView),
              const SizedBox(width: 8),
              _RoundIconButton(icon: Icons.download_outlined, tooltip: 'Download', onTap: onDownload),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessCell extends StatelessWidget {
  const _BusinessCell({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          document.businessName.isNotEmpty
              ? document.businessName
              : (document.uploaderName.isNotEmpty ? document.uploaderName : '—'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        Text(
          document.gstin.isNotEmpty
              ? 'GSTIN: ${document.gstin}'
              : (document.uploaderName.isNotEmpty ? document.uploaderName : '—'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _CreatedCell extends StatelessWidget {
  const _CreatedCell({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const Text('—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('dd MMM yyyy').format(date!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(DateFormat('hh:mm a').format(date!), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final color = categoryColorFor(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        name,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status.trim().isEmpty ? 'Pending' : status;
    final color = switch (label.toLowerCase()) {
      'processed' || 'approved' => const Color(0xFF16A34A),
      'deleted' || 'rejected' => const Color(0xFFDC2626),
      'pending' => const Color(0xFFD97706),
      _ => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FileTypeChip extends StatelessWidget {
  const _FileTypeChip({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final fileType = DocumentFileType.fromFile(fileName: 'file.${type.toLowerCase()}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fileType.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(color: fileType.chipForeground, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 18, color: AppColors.navy),
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.compact,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final bool compact;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox(height: 12);

    final start = ((currentPage - 1) * pageSize) + 1;
    final end = (currentPage * pageSize).clamp(0, totalItems);
    final pages = _visiblePageNumbers(currentPage, totalPages);

    final summary = Text(
      'Showing $start to $end of $totalItems documents',
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          icon: Icon(Icons.chevron_left, color: currentPage > 1 ? AppColors.navy : AppColors.textMuted),
          visualDensity: VisualDensity.compact,
        ),
        for (final page in pages)
          if (page == -1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('…', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: page == currentPage ? AppColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => onPageChanged(page),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: page == currentPage ? AppColors.navy : AppColors.border),
                    ),
                    child: Text(
                      '$page',
                      style: TextStyle(
                        color: page == currentPage ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        IconButton(
          onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
          icon: Icon(Icons.chevron_right, color: currentPage < totalPages ? AppColors.navy : AppColors.textMuted),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: compact
          ? Column(
              children: [
                summary,
                const SizedBox(height: 10),
                FittedBox(child: controls),
              ],
            )
          : Row(
              children: [
                Expanded(child: summary),
                controls,
              ],
            ),
    );
  }

  List<int> _visiblePageNumbers(int current, int total) {
    if (total <= 5) return List.generate(total, (index) => index + 1);
    if (current <= 3) return [1, 2, 3, -1, total];
    if (current >= total - 2) return [1, -1, total - 2, total - 1, total];
    return [1, -1, current, -1, total];
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.border),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ],
);
