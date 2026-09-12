import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/upload_file_validator.dart';
import '../../data/models/document_models.dart';
import '../providers/category_provider.dart';
import '../providers/document_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/loading_overlay.dart';

class UploadDocumentScreen extends ConsumerStatefulWidget {
  const UploadDocumentScreen({super.key, this.initialCategoryId});

  final int? initialCategoryId;

  @override
  ConsumerState<UploadDocumentScreen> createState() =>
      _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends ConsumerState<UploadDocumentScreen> {
  int? _categoryId;
  String _source = 'FilePicker';
  String? _fileName;
  List<int>? _fileBytes;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    Future.microtask(() => ref.read(categoryProvider.notifier).load());
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _source = 'FilePicker';
      _fileName = file.name;
      _fileBytes = file.bytes;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(source: source);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _source = source == ImageSource.camera ? 'Camera' : 'Gallery';
      _fileName = image.name;
      _fileBytes = bytes;
    });
  }

  Future<void> _upload() async {
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    if (_fileBytes == null || _fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    final error = await ref.read(documentProvider.notifier).upload(
          UploadFilePayload(
            categoryId: _categoryId!,
            source: _source,
            fileName: _fileName!,
            bytes: _fileBytes!,
          ),
        );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document uploaded successfully')),
    );
    context.go('/history');
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final documents = ref.watch(documentProvider);
    final activeCategories =
        categories.categories.where((c) => c.isActive).toList();
    final selectedCategory = _categoryId == null
        ? null
        : activeCategories.where((c) => c.categoryId == _categoryId).firstOrNull;
    final showCamera = selectedCategory == null ||
        !UploadFileValidator.isBankStatements(selectedCategory.categoryName);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Document')),
      drawer: const AppDrawer(isAdmin: false),
      body: LoadingOverlay(
        isLoading: documents.isUploading || categories.isLoading,
        message: documents.isUploading ? 'Uploading...' : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 700 ? 640.0 : double.infinity;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: activeCategories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.categoryId,
                                child: Text(c.categoryName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _fileName ?? 'No file selected',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickFile,
                                    icon: const Icon(Icons.attach_file),
                                    label: const Text('Pick File'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library_outlined),
                                    label: const Text('Gallery'),
                                  ),
                                  if (showCamera)
                                    OutlinedButton.icon(
                                      onPressed: () => _pickImage(ImageSource.camera),
                                      icon: const Icon(Icons.camera_alt_outlined),
                                      label: const Text('Camera'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: documents.isUploading ? null : _upload,
                        child: const Text('Upload Document'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
