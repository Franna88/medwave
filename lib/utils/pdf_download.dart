import 'dart:typed_data';

import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart'
    as impl;

/// Triggers a PDF file download. On web, uses blob URL and anchor.
/// On non-web, no-op; caller should check kIsWeb and show a message.
Future<void> downloadPdfBytes(Uint8List bytes, String fileName) {
  return impl.downloadPdfBytes(bytes, fileName);
}
