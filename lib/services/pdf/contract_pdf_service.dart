import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../models/contracts/contract.dart';
import 'pdf_styles.dart';

/// Service for generating contract PDFs
class ContractPdfService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Generate complete contract PDF document
  Future<pw.Document> generateContractPdf(Contract contract) async {
    final pdf = pw.Document();

    // Load logo
    final logoData = await rootBundle.load('images/medwave_logo_white.png');
    final logoBytes = logoData.buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    // Page 1: Header + Customer Info + Quote
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(logo),
            pw.SizedBox(height: PdfStyles.spacingLarge),
            _buildCustomerInfo(contract),
            pw.SizedBox(height: PdfStyles.spacingLarge),
            _buildQuoteSection(contract),
            pw.Spacer(),
            _buildFooter(),
          ],
        ),
      ),
    );

    // Page 2+: Contract Content
    final plainText = contract.contractContentData['plainText'] as String? ?? '';
    if (plainText.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Text(
              'Agreement Terms',
              style: PdfStyles.h2,
            ),
            PdfStyles.thickDivider,
            pw.Text(
              plainText,
              style: PdfStyles.bodyText,
              textAlign: pw.TextAlign.justify,
            ),
          ],
          footer: (context) => _buildFooter(),
        ),
      );
    }

    // Final Page: Signature Certificate
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildSignatureCertificate(contract),
            pw.Spacer(),
            _buildFooter(),
          ],
        ),
      ),
    );

    return pdf;
  }

  /// Generate PDF as bytes
  Future<Uint8List> generatePdfBytes(Contract contract) async {
    final pdf = await generateContractPdf(contract);
    return pdf.save();
  }

  /// Upload PDF to Firebase Storage
  Future<String> uploadPdfToStorage(
    Contract contract,
    Uint8List pdfBytes,
  ) async {
    try {
      final fileName = 'signed_contract_${contract.id}.pdf';
      final ref = _storage.ref().child('contracts/${contract.id}/$fileName');

      await ref.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'contractId': contract.id,
            'customerName': contract.customerName,
            'signedAt': contract.signedAt?.toIso8601String() ?? '',
          },
        ),
      );

      final downloadUrl = await ref.getDownloadURL();

      if (kDebugMode) {
        print('✅ PDF uploaded successfully: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error uploading PDF: $e');
      }
      rethrow;
    }
  }

  /// Build PDF header with logo and title
  pw.Widget _buildHeader(pw.MemoryImage logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: PdfStyles.headerDecoration,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, width: 120, height: 40),
          pw.Text(
            'Service Agreement',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Build customer information section
  pw.Widget _buildCustomerInfo(Contract contract) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: PdfStyles.cardDecoration,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Customer Information', style: PdfStyles.h3),
          pw.SizedBox(height: PdfStyles.spacingMedium),
          _buildInfoRow('Name:', contract.customerName),
          pw.SizedBox(height: PdfStyles.spacingSmall),
          _buildInfoRow('Email:', contract.email),
          pw.SizedBox(height: PdfStyles.spacingSmall),
          _buildInfoRow('Phone:', contract.phone),
          pw.SizedBox(height: PdfStyles.spacingSmall),
          _buildInfoRow(
            'Date:',
            DateFormat('MMMM dd, yyyy').format(contract.createdAt),
          ),
        ],
      ),
    );
  }

  /// Build quote/invoice section
  pw.Widget _buildQuoteSection(Contract contract) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: PdfStyles.cardDecoration,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Quote', style: PdfStyles.h3),
          pw.SizedBox(height: PdfStyles.spacingMedium),
          // Products
          ...contract.products.map((product) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(product.name, style: PdfStyles.bodyText),
                  ),
                  pw.Text(
                    'R ${product.price.toStringAsFixed(2)}',
                    style: PdfStyles.bodyTextBold,
                  ),
                ],
              ),
            );
          }).toList(),
          PdfStyles.divider,
          // Pricing summary - right aligned
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _buildPriceRow('Subtotal:', contract.subtotal),
              pw.SizedBox(height: 8),
              _buildPriceRow(
                'Initial Deposit (40%):',
                contract.depositAmount,
                isHighlighted: true,
              ),
              pw.SizedBox(height: 8),
              _buildPriceRow(
                'Remaining Balance (60%):',
                contract.remainingBalance,
                isSubdued: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build signature certificate section
  pw.Widget _buildSignatureCertificate(Contract contract) {
    final dateFormat = DateFormat('MMMM dd, yyyy \'at\' hh:mm a');

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: PdfStyles.certificateDecoration,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              'CERTIFICATE OF SIGNATURE',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfStyles.primaryColor,
              ),
            ),
          ),
          pw.SizedBox(height: PdfStyles.spacingLarge),
          // Reference Number
          pw.Text('REFERENCE NUMBER', style: PdfStyles.labelText),
          pw.SizedBox(height: 4),
          pw.Text(
            contract.digitalSignatureToken ?? 'N/A',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfStyles.primaryColor,
            ),
          ),
          pw.SizedBox(height: PdfStyles.spacingMedium),
          // Document Signed On
          pw.Text('DOCUMENT SIGNED ON', style: PdfStyles.labelText),
          pw.SizedBox(height: 4),
          pw.Text(
            contract.signedAt != null
                ? dateFormat.format(contract.signedAt!)
                : 'N/A',
            style: PdfStyles.bodyTextBold,
          ),
          pw.SizedBox(height: PdfStyles.spacingLarge),
          // Signer Details Box
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfStyles.primaryColor, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SIGNER',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfStyles.primaryColor,
                  ),
                ),
                PdfStyles.divider,
                _buildInfoRow('Name:', contract.customerName),
                pw.SizedBox(height: 8),
                _buildInfoRow('Email:', contract.email),
                pw.SizedBox(height: 8),
                _buildInfoRow(
                  'Signature:',
                  contract.digitalSignature ?? 'N/A',
                ),
                pw.SizedBox(height: 8),
                _buildInfoRow(
                  'Signed:',
                  contract.signedAt != null
                      ? dateFormat.format(contract.signedAt!)
                      : 'N/A',
                ),
                pw.SizedBox(height: 8),
                _buildInfoRow(
                  'IP Address:',
                  contract.ipAddress ?? 'N/A',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: PdfStyles.spacingLarge),
          // Legal Notice
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'This electronic signature has the same legal effect as a handwritten signature.',
                style: PdfStyles.smallText,
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build info row with label and value
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(label, style: PdfStyles.labelText),
        ),
        pw.Expanded(
          child: pw.Text(value, style: PdfStyles.bodyText),
        ),
      ],
    );
  }

  /// Build price row with label and amount
  pw.Widget _buildPriceRow(
    String label,
    double amount, {
    bool isHighlighted = false,
    bool isSubdued = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: isHighlighted
              ? PdfStyles.bodyTextBold
              : (isSubdued ? PdfStyles.smallText : PdfStyles.bodyText),
        ),
        pw.Text(
          'R ${amount.toStringAsFixed(2)}',
          style: isHighlighted
              ? pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfStyles.primaryColor,
                )
              : (isSubdued ? PdfStyles.smallText : PdfStyles.bodyTextBold),
        ),
      ],
    );
  }

  /// Build footer
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
              pw.Text(
                'MedWave™ RSA PTY LTD',
                style: PdfStyles.smallText,
              ),
              pw.Text(
                'www.medwavegroup.com',
                style: PdfStyles.smallText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

