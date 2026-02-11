import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../models/installation/installation_signoff.dart';
import 'pdf_styles.dart';

/// Generates a one-page PDF for a signed installation sign-off (receipt confirmation).
class InstallationSignoffPdfService {
  /// Generates PDF bytes for the signed installation sign-off.
  /// Call only when signoff.hasSigned is true.
  Future<Uint8List> generatePdfBytes(InstallationSignoff signoff) async {
    final pdf = pw.Document();
    pw.Font? signatureFont;

    try {
      final fontData = await rootBundle.load('fonts/DancingScript-Bold.ttf');
      signatureFont = pw.Font.ttf(fontData.buffer.asByteData());
    } catch (_) {
      // Use default font if Dancing Script not available
    }

    final dateFormat = DateFormat('MMMM dd, yyyy \'at\' hh:mm a');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'Installation Receipt Confirmation',
                style: PdfStyles.h1,
              ),
            ),
            pw.SizedBox(height: PdfStyles.spacingMedium),
            PdfStyles.thickDivider,
            pw.SizedBox(height: PdfStyles.spacingMedium),

            // Customer info
            pw.Text('Customer', style: PdfStyles.h3),
            pw.SizedBox(height: 8),
            _infoRow('Name', signoff.customerName),
            pw.SizedBox(height: 4),
            _infoRow('Email', signoff.email),
            pw.SizedBox(height: 4),
            _infoRow('Phone', signoff.phone),
            if (signoff.deliveryAddress != null &&
                signoff.deliveryAddress!.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              _infoRow('Address', signoff.deliveryAddress!),
            ],
            pw.SizedBox(height: PdfStyles.spacingLarge),

            // Signature section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: PdfStyles.certificateDecoration,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'RECEIPT CONFIRMED',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfStyles.primaryColor,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: PdfStyles.spacingMedium),
                  _infoRow(
                    'Confirmation ID',
                    signoff.digitalSignatureToken ?? 'N/A',
                  ),
                  pw.SizedBox(height: 8),
                  _infoRow(
                    'Signed',
                    signoff.signedAt != null
                        ? dateFormat.format(signoff.signedAt!)
                        : 'N/A',
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('Signature', style: PdfStyles.labelText),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    signoff.digitalSignature ?? 'N/A',
                    style: signatureFont != null
                        ? pw.TextStyle(
                            font: signatureFont,
                            fontSize: 28,
                            color: PdfStyles.textColor,
                          )
                        : pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfStyles.textColor,
                          ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: PdfStyles.spacingLarge),

            // Acknowledged items
            pw.Text('Acknowledged Items', style: PdfStyles.h3),
            pw.SizedBox(height: 8),
            ...signoff.items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  children: [
                    pw.Text('${item.name}', style: PdfStyles.bodyText),
                    pw.SizedBox(width: 8),
                    pw.Text('Qty: ${item.quantity}', style: PdfStyles.bodyText),
                  ],
                ),
              ),
            ),
            pw.Spacer(),
            _buildFooter(),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text('$label:', style: PdfStyles.labelText),
        ),
        pw.Expanded(child: pw.Text(value, style: PdfStyles.bodyText)),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        children: [
          pw.Container(height: 1, color: PdfStyles.lightGrayColor),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('MedWave RSA PTY LTD', style: PdfStyles.smallText),
              pw.Text('www.medwavegroup.com', style: PdfStyles.smallText),
            ],
          ),
        ],
      ),
    );
  }
}
