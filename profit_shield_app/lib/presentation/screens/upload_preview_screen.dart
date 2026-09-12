import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/upload_file_validator.dart';
import '../../data/mock/mock_category_data.dart';
import '../providers/dashboard_provider.dart';
import '../providers/upload_flow_provider.dart';
import '../widgets/profit_shield_widgets.dart';

class UploadPreviewScreen extends ConsumerStatefulWidget {
  const UploadPreviewScreen({super.key, required this.categoryId});

  final int categoryId;

  @override
  ConsumerState<UploadPreviewScreen> createState() => _UploadPreviewScreenState();
}

class _UploadPreviewScreenState extends ConsumerState<UploadPreviewScreen> {
  bool _isSending = false;

  Future<void> _send() async {
    setState(() => _isSending = true);
    final error = await ref.read(uploadFlowProvider.notifier).submit();
    if (!mounted) return;
    setState(() => _isSending = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }

    ref.read(dashboardProvider.notifier).loadClientDashboard();
    ref.invalidate(documentHistoryProvider);
    ref.invalidate(documentFullHistoryProvider);

    await showUploadSuccessDialog(context);
    if (!mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(uploadFlowProvider);
    final categoryName = flow.categoryName ?? MockCategoryData.nameForId(widget.categoryId);
    final fileName = flow.fileName?.trim().isNotEmpty == true ? flow.fileName!.trim() : 'Selected file';
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final bytes = flow.bytes;
    final fileNameLower = flow.fileName?.toLowerCase() ?? '';
    final isPdf = fileNameLower.endsWith('.pdf');
    final isExcel = UploadFileValidator.isExcelFileName(fileNameLower);
    final isImage = bytes != null && !isPdf && !isExcel;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _isSending ? null : () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoryName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Text(
              'Upload a document',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (bytes != null && isImage)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sky),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover),
            )
          else if (bytes != null)
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sky),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isExcel ? Icons.table_chart_outlined : Icons.picture_as_pdf,
                      size: 40,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isExcel ? 'Excel Document' : 'PDF Document',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sky),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Document reference is assigned after upload',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sky),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'File name',
                  value: fileName,
                ),
                const Divider(height: 1),
                _InfoRow(icon: Icons.sell_outlined, label: 'Category', value: categoryName),
                const Divider(height: 1),
                _InfoRow(icon: Icons.calendar_today_outlined, label: 'Upload Date', value: dateStr),
                const Divider(height: 1),
                _InfoRow(icon: Icons.access_time_rounded, label: 'Upload Time', value: timeStr),
                const Divider(height: 1),
                _InfoRow(icon: Icons.camera_alt_outlined, label: 'Source', value: flow.source),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 40,
                child: OutlinedButton(
                  onPressed: _isSending ? null : () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Change', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 14),
              SendButton3D(
                onPressed: _isSending ? null : _send,
                isLoading: _isSending,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
