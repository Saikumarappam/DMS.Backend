import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/document_model.dart';
import 'document_pdf_preview.dart';

class DocumentPreviewImage extends StatelessWidget {
  const DocumentPreviewImage({
    super.key,
    required this.document,
    this.width,
    this.height = 52,
    this.large = false,
    this.fit,
    this.onTap,
  });

  final DocumentItem document;
  final double? width;
  final double height;
  final bool large;
  final BoxFit? fit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final boxHeight = large ? 220.0 : height;
    if (document.fileType == DocumentFileType.pdf) {
      return DocumentPdfPreview(
        document: document,
        width: large ? double.infinity : width,
        height: boxHeight,
        onTap: onTap,
      );
    }

    final bytes = document.previewBytes;
    final boxWidth = large ? double.infinity : (width ?? 88);

    Widget child;
    if (bytes != null && bytes.isNotEmpty) {
      child = Image.memory(
        bytes,
        fit: large ? BoxFit.contain : (fit ?? BoxFit.cover),
        width: large ? double.infinity : boxWidth,
        height: boxHeight,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    } else {
      child = _placeholder();
    }

    final box = Container(
      width: large ? double.infinity : boxWidth,
      height: boxHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );

    if (onTap == null) return box;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: box),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Icon(
        document.fileType.glyph,
        color: document.fileType.accent,
        size: large || height >= 160 ? 48 : 28,
      ),
    );
  }
}

class DocumentsEmptyState extends StatelessWidget {
  const DocumentsEmptyState({
    super.key,
    this.message = 'No documents found for the selected filters.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.folder_off_outlined, size: 42, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class DocumentsErrorState extends StatelessWidget {
  const DocumentsErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
