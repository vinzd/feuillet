import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import '../models/database.dart';

/// Metadata for a document file.
class DocumentFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime lastModified;

  const DocumentFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.lastModified,
  });
}

/// File metadata (size and last modified).
class FileMetadata {
  final int size;
  final DateTime lastModified;

  const FileMetadata({required this.size, required this.lastModified});
}

/// Service that abstracts file I/O using dart:io.
class FileAccessService {
  FileAccessService._();

  static final FileAccessService instance = FileAccessService._();

  /// Pick a directory using FilePicker.
  Future<String?> pickDirectory() async {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select PDF Directory',
      lockParentWindow: true,
    );
  }

  /// List document files in a directory.
  Future<List<DocumentFileInfo>> listDocumentFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final files = <DocumentFileInfo>[];
    await for (final entity in dir.list(recursive: true)) {
      final ext = entity.path.split('.').last.toLowerCase();
      if (entity is File && DocumentTypes.allExtensions.contains(ext)) {
        final stat = await entity.stat();
        files.add(
          DocumentFileInfo(
            path: entity.path,
            name: entity.uri.pathSegments.last,
            size: stat.size,
            lastModified: stat.modified,
          ),
        );
      }
    }
    return files;
  }

  /// Read file contents as bytes.
  Future<Uint8List> readFileBytes(String filePath) async {
    return File(filePath).readAsBytes();
  }

  /// Copy/write a file into a directory. Returns the new file's path.
  Future<String> writeFileToDirectory(
    String directoryPath,
    String fileName,
    Uint8List bytes,
  ) async {
    final destPath = '$directoryPath${Platform.pathSeparator}$fileName';
    await File(destPath).writeAsBytes(bytes);
    return destPath;
  }

  /// Check if a file exists.
  Future<bool> fileExists(String filePath) async {
    return File(filePath).exists();
  }

  /// Get file metadata (size, lastModified).
  Future<FileMetadata> getFileMetadata(String filePath) async {
    final stat = await File(filePath).stat();
    return FileMetadata(size: stat.size, lastModified: stat.modified);
  }

  /// Delete a file.
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Check if a directory path is accessible.
  Future<bool> directoryExists(String path) async {
    return Directory(path).exists();
  }

  /// Open a PdfDocument from a path or bytes.
  Future<PdfDocument> openPdfDocument(
    String filePath, {
    Uint8List? pdfBytes,
  }) async {
    if (pdfBytes != null) {
      return PdfDocument.openData(pdfBytes);
    }
    return PdfDocument.openFile(filePath);
  }
}
