import 'dart:typed_data';

/// Stub for native platforms - download handled via share_plus
void downloadPdf(Uint8List bytes, String fileName) {
  // On native platforms, we use share_plus instead of download
  // This function should not be called on native platforms
  throw UnsupportedError('downloadPdf is only supported on web');
}
