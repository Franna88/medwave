import 'dart:typed_data';

/// No-op on non-web platforms. Caller should check kIsWeb and show a message.
Future<void> downloadPdfBytes(Uint8List bytes, String fileName) async {
  // No-op: download is only supported on web (blob + anchor).
}
