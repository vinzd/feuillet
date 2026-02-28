import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

/// Metadata for a PDF file (works for both SAF URIs and local paths).
class PdfFileInfo {
  final String uri; // file path or content:// URI
  final String name;
  final int size;
  final DateTime lastModified;

  const PdfFileInfo({
    required this.uri,
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

/// Whether a path is a SAF content URI.
bool isSafUri(String path) => path.startsWith('content://');

/// Service that abstracts file I/O across platforms.
///
/// Routes to SAF platform channel for content:// URIs (Android),
/// dart:io for regular file paths (desktop/iOS).
class FileAccessService {
  FileAccessService._();

  static final FileAccessService instance = FileAccessService._();

  static const _channel = MethodChannel('com.feuillet.app/saf');

  /// Pick a directory. On Android uses SAF, on desktop uses FilePicker.
  Future<String?> pickDirectory() async {
    if (_isAndroid) {
      try {
        return await _channel.invokeMethod<String>('pickDirectory');
      } on PlatformException catch (e) {
        debugPrint('FileAccessService: SAF pickDirectory failed: $e');
        return null;
      }
    }
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select PDF Directory',
      lockParentWindow: true,
    );
  }

  /// List PDF files in a directory.
  Future<List<PdfFileInfo>> listPdfFiles(String directoryPath) async {
    if (isSafUri(directoryPath)) {
      return _listPdfFilesSaf(directoryPath);
    }
    return _listPdfFilesLocal(directoryPath);
  }

  Future<List<PdfFileInfo>> _listPdfFilesSaf(String treeUri) async {
    try {
      final result = await _channel.invokeListMethod<Map>('listPdfFiles', {
        'treeUri': treeUri,
      });
      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item);
        return PdfFileInfo(
          uri: map['uri'] as String,
          name: map['name'] as String,
          size: (map['size'] as num).toInt(),
          lastModified: DateTime.fromMillisecondsSinceEpoch(
            (map['lastModified'] as num).toInt(),
          ),
        );
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('FileAccessService: SAF listPdfFiles failed: $e');
      return [];
    }
  }

  Future<List<PdfFileInfo>> _listPdfFilesLocal(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final files = <PdfFileInfo>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
        final stat = await entity.stat();
        files.add(
          PdfFileInfo(
            uri: entity.path,
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
    if (isSafUri(filePath)) {
      return _readFileBytesSaf(filePath);
    }
    return File(filePath).readAsBytes();
  }

  Future<Uint8List> _readFileBytesSaf(String documentUri) async {
    final result = await _channel.invokeMethod<Uint8List>('readFileBytes', {
      'documentUri': documentUri,
    });
    if (result == null) {
      throw Exception('Failed to read file bytes via SAF: $documentUri');
    }
    return result;
  }

  /// Copy/write a file into a directory. Returns the new file's path/URI.
  Future<String> writeFileToDirectory(
    String directoryPath,
    String fileName,
    Uint8List bytes,
  ) async {
    if (isSafUri(directoryPath)) {
      return _writeFileSaf(directoryPath, fileName, bytes);
    }
    final destPath = '$directoryPath${Platform.pathSeparator}$fileName';
    await File(destPath).writeAsBytes(bytes);
    return destPath;
  }

  Future<String> _writeFileSaf(
    String treeUri,
    String fileName,
    Uint8List bytes,
  ) async {
    final result = await _channel.invokeMethod<String>('writeFile', {
      'treeUri': treeUri,
      'fileName': fileName,
      'bytes': bytes,
    });
    if (result == null) {
      throw Exception('Failed to write file via SAF');
    }
    return result;
  }

  /// Check if a file exists.
  Future<bool> fileExists(String filePath) async {
    if (isSafUri(filePath)) {
      try {
        final result = await _channel.invokeMethod<bool>('fileExists', {
          'documentUri': filePath,
        });
        return result ?? false;
      } on PlatformException {
        return false;
      }
    }
    return File(filePath).exists();
  }

  /// Get file metadata (size, lastModified).
  Future<FileMetadata> getFileMetadata(String filePath) async {
    if (isSafUri(filePath)) {
      return _getFileMetadataSaf(filePath);
    }
    final stat = await File(filePath).stat();
    return FileMetadata(size: stat.size, lastModified: stat.modified);
  }

  Future<FileMetadata> _getFileMetadataSaf(String documentUri) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getFileMetadata',
      {'documentUri': documentUri},
    );
    if (result == null) {
      throw Exception('Failed to get metadata via SAF: $documentUri');
    }
    return FileMetadata(
      size: (result['size'] as num).toInt(),
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        (result['lastModified'] as num).toInt(),
      ),
    );
  }

  /// Delete a file.
  Future<void> deleteFile(String filePath) async {
    if (isSafUri(filePath)) {
      await _channel.invokeMethod<bool>('deleteFile', {
        'documentUri': filePath,
      });
      return;
    }
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Check if a directory path is accessible.
  Future<bool> directoryExists(String path) async {
    if (isSafUri(path)) {
      // For SAF URIs, try listing files — if it works, the directory is accessible
      try {
        await _channel.invokeListMethod<Map>('listPdfFiles', {'treeUri': path});
        return true;
      } on PlatformException {
        return false;
      }
    }
    return Directory(path).exists();
  }

  /// Copy a SAF document to a local temporary file.
  /// Returns the local file path.
  Future<String> copyToLocal(String documentUri) async {
    final hash = documentUri.hashCode.toRadixString(16);
    final cacheDir = await getTemporaryDirectory();
    final destPath = '${cacheDir.path}/saf_cache/$hash.pdf';

    final result = await _channel.invokeMethod<String>('copyToLocal', {
      'documentUri': documentUri,
      'destPath': destPath,
    });
    if (result == null) {
      throw Exception('Failed to copy SAF file to local: $documentUri');
    }
    return result;
  }

  /// Open a PdfDocument from a path or bytes.
  Future<PdfDocument> openPdfDocument(
    String filePath, {
    Uint8List? pdfBytes,
  }) async {
    if (pdfBytes != null) {
      return PdfDocument.openData(pdfBytes);
    }
    if (isSafUri(filePath)) {
      final localPath = await copyToLocal(filePath);
      return PdfDocument.openFile(localPath);
    }
    return PdfDocument.openFile(filePath);
  }

  bool get _isAndroid => !kIsWeb && Platform.operatingSystem == 'android';
}
