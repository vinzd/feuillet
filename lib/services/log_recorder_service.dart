import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;

class LogRecorderService {
  static final LogRecorderService instance = LogRecorderService._();
  LogRecorderService._();

  bool _isRecording = false;
  final List<String> _entries = [];
  DateTime? _startedAt;
  DebugPrintCallback? _originalDebugPrint;

  bool get isRecording => _isRecording;
  int get entryCount => _entries.length;
  DateTime? get startedAt => _startedAt;

  void start() {
    if (_isRecording) return;

    _entries.clear();
    _startedAt = DateTime.now();
    _isRecording = true;

    _originalDebugPrint = debugPrint;
    debugPrint = _recordingDebugPrint;

    _record('=== Log recording started ===');
  }

  Future<void> stopAndShare() async {
    if (!_isRecording) return;

    _record('=== Log recording stopped ===');
    _isRecording = false;

    debugPrint = _originalDebugPrint!;
    _originalDebugPrint = null;

    final content = _entries.join('\n');
    final timestamp = _startedAt!.toIso8601String().replaceAll(':', '-');
    final fileName = 'feuillet-logs-$timestamp.txt';

    if (kIsWeb) {
      debugPrint(content);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = path.join(tempDir.path, fileName);
    await File(filePath).writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'text/plain')],
        subject: fileName,
      ),
    );
  }

  void _recordingDebugPrint(String? message, {int? wrapWidth}) {
    if (message == null) return;
    _record(message);
    _originalDebugPrint?.call(message, wrapWidth: wrapWidth);
  }

  void _record(String message) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    _entries.add('[$ts] $message');
  }
}
