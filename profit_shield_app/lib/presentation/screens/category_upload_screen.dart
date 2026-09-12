import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/upload_file_validator.dart';
import '../../data/mock/mock_category_data.dart';
import '../providers/category_provider.dart';
import '../providers/upload_flow_provider.dart';
import '../widgets/profit_shield_widgets.dart';

class CategoryUploadScreen extends ConsumerWidget {
  const CategoryUploadScreen({super.key, required this.categoryId});

  final int categoryId;

  String _categoryName(WidgetRef ref) {
    final categories = ref.watch(categoryProvider).categories;
    for (final category in categories) {
      if (category.categoryId == categoryId) return category.categoryName;
    }
    return MockCategoryData.nameForId(categoryId);
  }

  String _uploadFileName(String name, {required String fallbackExtension}) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'document$fallbackExtension';
  }

  Future<void> _pickImage(
    BuildContext context,
    WidgetRef ref, {
    required ImageSource source,
  }) async {
    final categoryName = _categoryName(ref);
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1400,
      maxHeight: 1400,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final error = UploadFileValidator.validate(
      byteLength: bytes.length,
      kind: UploadFileKind.image,
      categoryName: categoryName,
    );
    if (error != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    ref.read(uploadFlowProvider.notifier).setCategory(categoryId, categoryName);
    ref.read(uploadFlowProvider.notifier).setFile(
          fileName: _uploadFileName(image.name, fallbackExtension: '.jpg'),
          bytes: bytes,
          source: source == ImageSource.camera ? 'Camera' : 'Gallery',
        );

    if (context.mounted) {
      context.push('/upload/category/$categoryId/preview');
    }
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    final categoryName = _categoryName(ref);
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx', 'xls'],
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;

    final file = result.files.first;
    final bytes = file.bytes!;
    final kind = UploadFileValidator.kindFromFileName(file.name);
    if (kind == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only PDF and Excel files are supported.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    final error = UploadFileValidator.validate(
      byteLength: bytes.length,
      kind: kind,
      categoryName: categoryName,
    );
    if (error != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    ref.read(uploadFlowProvider.notifier).setCategory(categoryId, categoryName);
    ref.read(uploadFlowProvider.notifier).setFile(
          fileName: _uploadFileName(
            file.name,
            fallbackExtension: kind == UploadFileKind.excel ? '.xlsx' : '.pdf',
          ),
          bytes: bytes,
          source: 'File',
        );

    if (context.mounted) {
      context.push('/upload/category/$categoryId/preview');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryName = _categoryName(ref);
    final isBankDocuments = UploadFileValidator.isBankStatements(categoryName);
    final imageLimit = UploadFileValidator.maxSizeLabel(
      kind: UploadFileKind.image,
      categoryName: categoryName,
    );
    final pdfLimit = UploadFileValidator.maxSizeLabel(
      kind: UploadFileKind.pdf,
      categoryName: categoryName,
    );
    final excelLimit = UploadFileValidator.maxSizeLabel(
      kind: UploadFileKind.excel,
      categoryName: categoryName,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoryName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Text(
              'Upload a document',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.sky, AppColors.skyLight],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon3D(icon: Icons.cloud_upload_outlined, size: 36, padding: 14),
                const SizedBox(height: 14),
                const Text(
                  "Choose how you'd like to upload",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No minimum file size',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OptionTile(
            icon: Icons.photo_library_outlined,
            title: 'Upload from Gallery',
            subtitle: 'Pick an image from your library $imageLimit',
            onTap: () => _pickImage(context, ref, source: ImageSource.gallery),
          ),
          if (!isBankDocuments) ...[
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              subtitle: 'Use camera to capture document $imageLimit',
              onTap: () => _pickImage(context, ref, source: ImageSource.camera),
            ),
          ],
          const SizedBox(height: 10),
          _OptionTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Pick PDF / Excel',
            subtitle: 'PDF $pdfLimit · Excel $excelLimit',
            onTap: () => _pickFile(context, ref),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sky),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon3D(icon: icon, size: 20, padding: 9),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
