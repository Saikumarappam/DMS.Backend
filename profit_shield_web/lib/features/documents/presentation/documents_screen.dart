import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/web_file_download.dart';
import '../../dashboard/presentation/widgets/admin_shell.dart';
import '../models/document_model.dart';
import '../providers/documents_provider.dart';
import 'widgets/document_preview_image.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().load(status: widget.initialStatus);
    });
  }

  @override
  void didUpdateWidget(covariant DocumentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      context.read<DocumentsProvider>().load(status: widget.initialStatus);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentsProvider>();
    if (_searchController.text != provider.searchQuery && provider.searchQuery.isEmpty) {
      _searchController.clear();
    }

    final paged = provider.pagedDocuments;
    final startIndex = provider.sortedDocuments.isEmpty
        ? 0
        : ((provider.currentPage - 1) * DocumentsProvider.pageSize);

    return AdminShell(
      selectedLabel: 'Documents',
      title: 'Documents',
      isLoading: (provider.isLoading || provider.isLoadingFilters) && provider.documents.isEmpty,
      onRefresh: () => provider.load(),
      child: RefreshIndicator(
        onRefresh: () => provider.load(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < Breakpoints.contentCompact;
            final stackFilters = width < Breakpoints.contentComfortable;
            final padding = compact ? 12.0 : 20.0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(padding, 8, padding, padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DocumentsHeader(compact: compact),
                  SizedBox(height: compact ? 16 : 20),
                  _FiltersCard(
                    compact: stackFilters,
                    enabled: !provider.isLoadingFilters,
                    busy: provider.isLoading || provider.isActing,
                    businessId: provider.pendingBusinessId,
                    categoryId: provider.pendingCategoryId,
                    businesses: provider.businessChoices,
                    categories: provider.categoryChoices,
                    onBusinessChanged: provider.setPendingBusiness,
                    onCategoryChanged: provider.setPendingCategory,
                    onApply: () => provider.applyFilters(),
                    onReset: () {
                      _searchController.clear();
                      provider.reset();
                    },
                  ),
                  SizedBox(height: compact ? 16 : 20),
                  _DocumentsListCard(
                    compact: compact,
                    contentWidth: width,
                    isLoading: provider.isLoading,
                    errorMessage: provider.errorMessage,
                    onRetry: () => provider.loadDocuments(),
                    searchController: _searchController,
                    onSearchChanged: provider.setSearch,
                    sort: provider.sort,
                    onSortChanged: provider.setSort,
                    documents: paged,
                    startIndex: startIndex,
                    currentPage: provider.currentPage,
                    totalPages: provider.totalPages,
                    totalItems: provider.sortedDocuments.length,
                    pageSize: DocumentsProvider.pageSize,
                    onPageChanged: provider.setPage,
                    acting: provider.isActing,
                    onView: _showPreview,
                    onDownload: _download,
                    onApprove: (doc) => _confirmApprove(doc),
                    onDelete: (doc) => _confirmDelete(doc),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmApprove(DocumentItem doc) async {
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

    final error = await context.read<DocumentsProvider>().approve(doc);
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

  Future<void> _download(DocumentItem doc) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Downloading ${doc.fileName}…')));
    try {
      final file = await context.read<DocumentsProvider>().download(doc);
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

  Future<void> _confirmDelete(DocumentItem doc) async {
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
              width: formDialogWidthOf(ctx, max: 360),
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

    final error = await context.read<DocumentsProvider>().delete(doc, remarks: remarks);
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
      builder: (ctx) => _DocumentPreviewDialog(
        document: doc,
        onDownload: () {
          Navigator.pop(ctx);
          _download(doc);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDelete(doc);
        },
        onApprove: () {
          Navigator.pop(ctx);
          _confirmApprove(doc);
        },
      ),
    );
  }
}

class _DocumentPreviewDialog extends StatelessWidget {
  const _DocumentPreviewDialog({
    required this.document,
    required this.onDownload,
    required this.onDelete,
    required this.onApprove,
  });

  final DocumentItem document;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = previewDialogWidthOf(context);
    final inset = previewDialogInsetOf(context);
    final bytes = document.previewBytes;
    if (document.fileType == DocumentFileType.pdf && bytes != null && bytes.isNotEmpty) {
      return AlertDialog(
        insetPadding: inset,
        constraints: BoxConstraints(minWidth: 280, maxWidth: dialogWidth),
        titlePadding: const EdgeInsets.fromLTRB(14, 8, 4, 0),
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        title: _dialogTitle(context),
        content: SizedBox(
          width: dialogWidth,
          height: size.height * 0.50,
          child: PdfDocumentViewBuilder(
            documentRef: PdfDocumentRefData(
              bytes,
              sourceName: 'preview-${document.id}',
              useProgressiveLoading: false,
            ),
            loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, _, _) => _singlePagePreview(context, size),
            builder: (context, pdf) {
              if (pdf == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (pdf.pages.length > 1) {
                return PdfViewer.data(
                  bytes,
                  sourceName: 'full-${document.id}',
                  params: const PdfViewerParams(
                    margin: 8,
                    backgroundColor: Color(0xFFF3F4F6),
                  ),
                );
              }
              return _singlePagePreview(context, size);
            },
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsAlignment: MainAxisAlignment.start,
        actions: [_actionBar(context)],
      );
    }

    return AlertDialog(
      insetPadding: inset,
      constraints: BoxConstraints(minWidth: 280, maxWidth: dialogWidth),
      titlePadding: const EdgeInsets.fromLTRB(14, 8, 4, 0),
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      title: _dialogTitle(context),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.42),
          child: _singlePagePreview(context, size),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsAlignment: MainAxisAlignment.start,
      actions: [_actionBar(context)],
    );
  }

  Widget _dialogTitle(BuildContext context) {
    return Row(
      children: [
        _FileGlyph(type: document.fileType, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(document.fileName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(document.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _singlePagePreview(BuildContext context, Size size) {
    final uploadedBy = [
      if (document.uploaderPhone.isNotEmpty) document.uploaderPhone,
      if (document.uploaderName.isNotEmpty) document.uploaderName,
      if (document.businessName.isNotEmpty) document.businessName,
    ].join('\n');

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DocumentPreviewImage(
            document: document,
            width: double.infinity,
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          _PreviewMeta(label: 'Business', value: document.businessName.isEmpty ? '—' : document.businessName),
          _PreviewMeta(
            label: 'Uploaded On',
            value: document.uploadedOn == null
                ? '—'
                : DateFormat('dd MMM yyyy, hh:mm a').format(document.uploadedOn!),
          ),
          _PreviewMeta(label: 'Uploaded By', value: uploadedBy.isEmpty ? '—' : uploadedBy),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    final compactAction = ElevatedButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );

    return SizedBox(
      width: double.maxFinite,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                style: compactAction.copyWith(
                  backgroundColor: const WidgetStatePropertyAll(AppColors.danger),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                ),
                onPressed: onDelete,
                child: const Text('Delete'),
              ),
              ElevatedButton(
                style: compactAction.copyWith(
                  backgroundColor: const WidgetStatePropertyAll(Color(0xFF16A34A)),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                ),
                onPressed: onApprove,
                child: const Text('Approve'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentsHeader extends StatelessWidget {
  const _DocumentsHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documents',
                  style: TextStyle(
                    fontSize: AppScale.of(context).pageTitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'View and manage all uploaded documents',
                  style: TextStyle(
                    fontSize: AppScale.of(context).body,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('3 unread notifications')),
              );
            },
            icon: Badge(
              label: const Text('3'),
              backgroundColor: AppColors.danger,
              child: Icon(
                Icons.notifications_outlined,
                color: AppColors.navy,
                size: compact ? 24 : 26,
              ),
            ),
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
    required this.categoryId,
    required this.businesses,
    required this.categories,
    required this.onBusinessChanged,
    required this.onCategoryChanged,
    required this.onApply,
    required this.onReset,
  });

  final bool compact;
  final bool enabled;
  final bool busy;
  final String businessId;
  final String categoryId;
  final List<DocumentFilterChoice> businesses;
  final List<DocumentFilterChoice> categories;
  final ValueChanged<String> onBusinessChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final businessField = _LabeledDropdown(
      label: 'Business Name',
      value: businessId,
      icon: Icons.business_outlined,
      items: businesses,
      enabled: enabled,
      onChanged: onBusinessChanged,
    );
    final categoryField = _LabeledDropdown(
      label: 'Category',
      value: categoryId,
      icon: Icons.folder_outlined,
      items: categories,
      enabled: enabled,
      onChanged: onCategoryChanged,
    );
    final actions = _FilterActions(
      compact: compact,
      enabled: enabled && !busy,
      onApply: onApply,
      onReset: onReset,
    );

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: _cardDecoration,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                businessField,
                const SizedBox(height: 12),
                categoryField,
                const SizedBox(height: 16),
                actions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: businessField),
                const SizedBox(width: 16),
                Expanded(child: categoryField),
                const SizedBox(width: 16),
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

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
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
    final selected = items.any((item) => item.id == value) ? value : (items.isNotEmpty ? items.first.id : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
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

class _DocumentsListCard extends StatelessWidget {
  const _DocumentsListCard({
    required this.compact,
    required this.contentWidth,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.searchController,
    required this.onSearchChanged,
    required this.sort,
    required this.onSortChanged,
    required this.documents,
    required this.startIndex,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    required this.acting,
    required this.onView,
    required this.onDownload,
    required this.onApprove,
    required this.onDelete,
  });

  final bool compact;
  final double contentWidth;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final DocumentSort sort;
  final ValueChanged<DocumentSort> onSortChanged;
  final List<DocumentItem> documents;
  final int startIndex;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final bool acting;
  final ValueChanged<DocumentItem> onView;
  final ValueChanged<DocumentItem> onDownload;
  final ValueChanged<DocumentItem> onApprove;
  final ValueChanged<DocumentItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final columns = contentWidth >= 720 ? 2 : 1;

    return Container(
      decoration: _cardDecoration,
      padding: EdgeInsets.fromLTRB(compact ? 14 : 20, compact ? 14 : 20, compact ? 14 : 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ListToolbar(
            compact: compact || contentWidth < 980,
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            sort: sort,
            onSortChanged: onSortChanged,
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
          else
            _DocumentsPreviewGrid(
              columns: columns,
              documents: documents,
              startIndex: startIndex,
              acting: acting,
              onView: onView,
              onDownload: onDownload,
              onApprove: onApprove,
              onDelete: onDelete,
            ),
          if (errorMessage == null && documents.isNotEmpty)
            _DocumentsPagination(
              currentPage: currentPage,
              totalPages: totalPages,
              totalItems: totalItems,
              pageSize: pageSize,
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
    required this.sort,
    required this.onSortChanged,
  });

  final bool compact;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final DocumentSort sort;
  final ValueChanged<DocumentSort> onSortChanged;

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
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 280, minWidth: 180),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search documents by name...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          suffixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
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

    final sortField = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 210),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text('Sort by', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
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
              child: DropdownButton<DocumentSort>(
                value: sort,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                items: const [
                  DropdownMenuItem(value: DocumentSort.newest, child: Text('Uploaded On (Newest)')),
                  DropdownMenuItem(value: DocumentSort.oldest, child: Text('Uploaded On (Oldest)')),
                  DropdownMenuItem(value: DocumentSort.nameAsc, child: Text('Name (A-Z)')),
                  DropdownMenuItem(value: DocumentSort.nameDesc, child: Text('Name (Z-A)')),
                ],
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 14),
          search,
          const SizedBox(height: 12),
          sortField,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: title),
        search,
        const SizedBox(width: 12),
        sortField,
      ],
    );
  }
}

class _DocumentsPreviewGrid extends StatelessWidget {
  const _DocumentsPreviewGrid({
    required this.columns,
    required this.documents,
    required this.startIndex,
    required this.acting,
    required this.onView,
    required this.onDownload,
    required this.onApprove,
    required this.onDelete,
  });

  final int columns;
  final List<DocumentItem> documents;
  final int startIndex;
  final bool acting;
  final ValueChanged<DocumentItem> onView;
  final ValueChanged<DocumentItem> onDownload;
  final ValueChanged<DocumentItem> onApprove;
  final ValueChanged<DocumentItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < documents.length; i += columns) {
      final rowItems = <Widget>[];
      for (var col = 0; col < columns; col++) {
        final index = i + col;
        if (col > 0) rowItems.add(const SizedBox(width: 12));
        if (index < documents.length) {
          rowItems.add(
            Expanded(
              child: _DocumentCard(
                index: startIndex + index + 1,
                document: documents[index],
                acting: acting,
                onView: () => onView(documents[index]),
                onDownload: () => onDownload(documents[index]),
                onApprove: () => onApprove(documents[index]),
                onDelete: () => onDelete(documents[index]),
              ),
            ),
          );
        } else {
          rowItems.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowItems));
    }
    return Column(children: rows);
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.index,
    required this.document,
    required this.acting,
    required this.onView,
    required this.onDownload,
    required this.onApprove,
    required this.onDelete,
  });

  final int index;
  final DocumentItem document;
  final bool acting;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onApprove;
  final VoidCallback onDelete;

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
          DocumentPreviewImage(
            document: document,
            width: double.infinity,
            height: AppScale.of(context).isMobile ? 160 : 220,
            fit: BoxFit.contain,
            onTap: onView,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$index',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(child: _DocumentNameCell(document: document)),
              _RoundIconButton(icon: Icons.visibility_outlined, tooltip: 'View', onTap: onView),
              const SizedBox(width: 8),
              _RoundIconButton(icon: Icons.download_outlined, tooltip: 'Download', onTap: onDownload),
            ],
          ),
          const SizedBox(height: 10),
          _UploadedOnCell(date: document.uploadedOn),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: acting ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Approve', overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: acting ? null : onDelete,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete', overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentNameCell extends StatelessWidget {
  const _DocumentNameCell({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FileGlyph(type: document.fileType),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              Text(
                document.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UploadedOnCell extends StatelessWidget {
  const _UploadedOnCell({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const Text('—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('dd MMM yyyy').format(date!),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          DateFormat('hh:mm a').format(date!),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _FileGlyph extends StatelessWidget {
  const _FileGlyph({required this.type, this.size = 34});

  final DocumentFileType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: type.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: type == DocumentFileType.image
          ? Icon(type.glyph, color: Colors.white, size: size * 0.52)
          : type == DocumentFileType.other
              ? Icon(type.glyph, color: Colors.white, size: size * 0.52)
              : Text(
                  type == DocumentFileType.spreadsheet ? 'X' : 'PDF',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: type == DocumentFileType.spreadsheet ? size * 0.42 : size * 0.26,
                    letterSpacing: type == DocumentFileType.pdf ? -0.3 : 0,
                  ),
                ),
    );
  }
}

class _DocumentsPagination extends StatelessWidget {
  const _DocumentsPagination({
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
        _PageIcon(
          icon: Icons.chevron_left,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        for (final page in pages)
          if (page == -1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('…', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            )
          else
            _PageNumber(
              page: page,
              selected: page == currentPage,
              onTap: () => onPageChanged(page),
            ),
        _PageIcon(
          icon: Icons.chevron_right,
          enabled: currentPage < totalPages,
          onTap: () => onPageChanged(currentPage + 1),
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

class _PageNumber extends StatelessWidget {
  const _PageNumber({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final int page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected ? AppColors.navy : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? AppColors.navy : AppColors.border),
            ),
            child: Text(
              '$page',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIcon extends StatelessWidget {
  const _PageIcon({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, color: enabled ? AppColors.navy : AppColors.textMuted),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PreviewMeta extends StatelessWidget {
  const _PreviewMeta({required this.label, required this.value});

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
