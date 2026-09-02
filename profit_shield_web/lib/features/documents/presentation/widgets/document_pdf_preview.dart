import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/document_model.dart';

class DocumentPdfPreview extends StatelessWidget {
  const DocumentPdfPreview({
    super.key,
    required this.document,
    required this.height,
    this.width,
    this.onTap,
  });

  final DocumentItem document;
  final double height;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = document.previewBytes;
    final boxWidth = width ?? double.infinity;

    if (bytes == null || bytes.isEmpty) {
      return _PdfFrame(
        width: boxWidth,
        height: height,
        onTap: onTap,
        child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 48),
      );
    }

    return _PdfFrame(
      width: boxWidth,
      height: height,
      onTap: onTap,
      child: PdfDocumentViewBuilder(
        documentRef: PdfDocumentRefData(
          bytes,
          sourceName: 'preview-${document.id}',
          useProgressiveLoading: false,
        ),
        loadingBuilder: (_) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, _, _) => const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 48),
        builder: (context, pdf) {
          if (pdf == null) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final pages = pdf.pages.length;
          return Stack(
            fit: StackFit.expand,
            children: [
              PdfPageView(
                document: pdf,
                pageNumber: 1,
                alignment: Alignment.center,
                backgroundColor: const Color(0xFFF8FAFC),
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                maximumDpi: 160,
              ),
              if (pages > 1)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$pages pages',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PdfFrame extends StatelessWidget {
  const _PdfFrame({
    required this.width,
    required this.height,
    required this.child,
    this.onTap,
  });

  final double width;
  final double height;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
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
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(child: box),
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}
