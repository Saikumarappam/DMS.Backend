import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/document_models.dart';
import '../auth/biometric_lock_guard.dart';

class DeviceSaveResult {
  const DeviceSaveResult({
    required this.message,
    this.openPath,
    this.openUri,
    this.savedFileName,
    this.publicStoragePath,
  });

  final String message;
  final String? openPath;
  final String? openUri;
  final String? savedFileName;
  final String? publicStoragePath;

  bool get canOpen =>
      (openPath != null && openPath!.isNotEmpty) ||
      (openUri != null && openUri!.isNotEmpty) ||
      (publicStoragePath != null && publicStoragePath!.isNotEmpty);
}

class DocumentFileHelper {
  DocumentFileHelper._();

  static String _safeFileName(DocumentDownloadModel file) {
    var name = file.displayName;
    final ext = file.resolvedExtension;

    if (name.isEmpty) {
      name = 'document$ext';
    }

    if (!name.toLowerCase().endsWith(ext)) {
      final dot = name.lastIndexOf('.');
      if (dot > 0) {
        name = name.substring(0, dot);
      }
      name = '$name$ext';
    }

    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static String _imageNameWithoutExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  static Future<String> saveToTemp(DocumentDownloadModel file) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${_safeFileName(file)}';
    await File(path).writeAsBytes(file.bytes, flush: true);
    return path;
  }

  static Future<DeviceSaveResult> saveToDevice(
    DocumentDownloadModel file, {
    int? sourceFileId,
  }) async {
    if (file.bytes.isEmpty) {
      throw Exception('File is empty. Please try again.');
    }

    if (Platform.isAndroid) {
      return _saveOnAndroid(file);
    }

    if (Platform.isIOS) {
      if (file.isImage) {
        return _saveImageToGallery(file);
      }
      final path = await _saveToPublicDownloads(file);
      return DeviceSaveResult(
        message: 'Saved to Downloads',
        openPath: path,
        publicStoragePath: path,
        savedFileName: _safeFileName(file),
      );
    }

    final path = await _saveToPublicDownloads(file);
    return DeviceSaveResult(
      message: 'Saved to Downloads/ProfitShield',
      openPath: path,
      publicStoragePath: path,
      savedFileName: _safeFileName(file),
    );
  }

  static Future<String?> _writeBytesToFolder(
    String folderPath,
    String fileName,
    List<int> bytes,
  ) async {
    try {
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final path = '${folder.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      if (await file.exists() && await file.length() > 0) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  static Future<DeviceSaveResult> _saveOnAndroid(DocumentDownloadModel file) async {
    final fileName = _safeFileName(file);
    final bytes = file.bytes;

    String? savedPath = await _writeBytesToFolder(
      '/storage/emulated/0/Download/ProfitShield',
      fileName,
      bytes,
    );

    if (savedPath == null) {
      try {
        final downloadsDir = await getDownloadsDirectory().timeout(const Duration(seconds: 3));
        if (downloadsDir != null) {
          savedPath = await _writeBytesToFolder(
            '${downloadsDir.path}/ProfitShield',
            fileName,
            bytes,
          );
        }
      } catch (_) {}
    }

    if (savedPath == null) {
      try {
        final externalDir = await getExternalStorageDirectory().timeout(const Duration(seconds: 3));
        if (externalDir != null) {
          savedPath = await _writeBytesToFolder(
            '${externalDir.path}/Download/ProfitShield',
            fileName,
            bytes,
          );
        }
      } catch (_) {}
    }

    if (savedPath == null && file.isImage) {
      try {
        return await _saveImageToGallery(file);
      } catch (_) {}
    }

    savedPath ??= await _saveToPublicDownloads(file);

    return DeviceSaveResult(
      message: 'Saved to Downloads › ProfitShield',
      openPath: savedPath,
      publicStoragePath: savedPath,
      savedFileName: fileName,
    );
  }

  static Future<DeviceSaveResult> _saveImageToGallery(DocumentDownloadModel file) async {
    final fileName = _safeFileName(file);

    try {
      await Gal.putImageBytes(
        Uint8List.fromList(file.bytes),
        album: 'ProfitShield',
        name: _imageNameWithoutExtension(fileName),
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw Exception('Gallery save timed out. Allow photos permission and try again.');
    } on GalException {
      final tempPath = await saveToTemp(file);
      try {
        await Gal.putImage(tempPath, album: 'ProfitShield')
            .timeout(const Duration(seconds: 10));
      } finally {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }

    return DeviceSaveResult(
      message: 'Image saved to Gallery › ProfitShield',
      savedFileName: fileName,
    );
  }

  static Future<String> _saveToPublicDownloads(DocumentDownloadModel file) async {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory().timeout(const Duration(seconds: 3));
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();

    final folder = Directory('${dir.path}/ProfitShield');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }

    final path = '${folder.path}/${_safeFileName(file)}';
    await File(path).writeAsBytes(file.bytes, flush: true);
    return path;
  }

  static Future<OpenResult> openFile(String path) async {
    BiometricLockGuard.suppressFor(const Duration(seconds: 15));
    return OpenFilex.open(path);
  }

  static Future<OpenResult> openSavedFile(DeviceSaveResult result) async {
    BiometricLockGuard.suppressFor(const Duration(seconds: 15));

    final candidates = <String>[
      if (result.publicStoragePath != null && result.publicStoragePath!.isNotEmpty)
        result.publicStoragePath!,
      if (result.openPath != null && result.openPath!.isNotEmpty) result.openPath!,
    ];

    for (final path in candidates) {
      if (await File(path).exists()) {
        final pathResult = await OpenFilex.open(path);
        if (pathResult.type == ResultType.done) {
          return pathResult;
        }
      }
    }

    if (result.openUri != null && result.openUri!.isNotEmpty) {
      return OpenFilex.open(result.openUri!);
    }

    return OpenResult(
      type: ResultType.fileNotFound,
      message: 'Saved file is no longer available to open.',
    );
  }
}
