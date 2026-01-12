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

  /// Generate complete contract PDF document with cover page
  Future<pw.Document> generateContractPdf(Contract contract) async {
    // #region agent log
    final startTime = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode) {
      print(
        '🔍 [PDF-START] contractId=${contract.id}, products=${contract.products.length}, time=$startTime',
      );
    }
    // #endregion
    final pdf = pw.Document();

    // Load cover page image
    // #region agent log
    final coverStartTime = DateTime.now().millisecondsSinceEpoch;
    // #endregion
    final coverImageData = await rootBundle.load(
      'images/contract_cover_page.png',
    );
    final coverImageBytes = coverImageData.buffer.asUint8List();
    final coverImage = pw.MemoryImage(coverImageBytes);
    // #region agent log
    final coverEndTime = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode) {
      print(
        '🔍 [PDF-COVER] loaded cover image, size=${coverImageBytes.length} bytes, time=${coverEndTime - coverStartTime}ms',
      );
    }
    // #endregion

    // Page 1: Cover Page (Full page image)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero, // No margins for full-page image
        build: (context) => pw.Container(
          width: double.infinity,
          height: double.infinity,
          child: pw.Image(
            coverImage,
            fit: pw.BoxFit.cover, // Cover entire page
          ),
        ),
      ),
    );

    // Load grey logo for Page 2
    // #region agent log
    final logoStartTime = DateTime.now().millisecondsSinceEpoch;
    // #endregion
    final greyLogoData = await rootBundle.load('images/medwave_logo_grey.png');
    final greyLogoBytes = greyLogoData.buffer.asUint8List();
    final greyLogo = pw.MemoryImage(greyLogoBytes);
    // #region agent log
    final logoEndTime = DateTime.now().millisecondsSinceEpoch;
    final logoDuration = logoEndTime - logoStartTime;
    if (kDebugMode) print('🔍 [PDF-GREY-LOGO] load_time=${logoDuration}ms');
    // #endregion

    // Page 2: Invoice-style layout
    // #region agent log
    final page2StartTime = DateTime.now().millisecondsSinceEpoch;
    // #endregion
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header: Logo and Title both centered
            pw.Column(
              children: [
                // Logo centered
                pw.Center(child: pw.Image(greyLogo, width: 150, height: 50)),
                pw.SizedBox(height: 16),
                // Title centered
                pw.Center(
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: 'MedWave',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.TextSpan(
                          text: 'TM',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.TextSpan(
                          text: ' Device Invoice',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Two-column: Company info | Customer info
            _buildInvoiceInfoRow(contract),
            pw.SizedBox(height: 24),

            // Quote table
            _buildInvoiceQuoteTable(contract),
            pw.SizedBox(height: 24),

            // Payment info + Bank details
            _buildPaymentInfo(),

            pw.Spacer(),
            _buildFooter(),
          ],
        ),
      ),
    );
    // #region agent log
    final page2EndTime = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode)
      print('🔍 [PDF-PAGE2] build_time=${page2EndTime - page2StartTime}ms');
    // #endregion

    // Page 3+: Contract Content
    final plainText =
        contract.contractContentData['plainText'] as String? ?? '';
    if (plainText.isNotEmpty) {
      // #region agent log
      final contentStartTime = DateTime.now().millisecondsSinceEpoch;
      // #endregion
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Text('Agreement Terms', style: PdfStyles.h2),
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
      // #region agent log
      final contentEndTime = DateTime.now().millisecondsSinceEpoch;
      if (kDebugMode)
        print(
          '🔍 [PDF-CONTENT] build_time=${contentEndTime - contentStartTime}ms, text_length=${plainText.length}',
        );
      // #endregion
    }

    // Final Page: Signature Certificate
    // #region agent log
    final sigStartTime = DateTime.now().millisecondsSinceEpoch;
    // #endregion
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
    // #region agent log
    final sigEndTime = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode)
      print('🔍 [PDF-SIGNATURE] build_time=${sigEndTime - sigStartTime}ms');
    final totalTime = sigEndTime - startTime;
    if (kDebugMode)
      print(
        '🔍 [PDF-DOCUMENT-COMPLETE] total_time=${totalTime}ms with cover page',
      );
    // #endregion

    return pdf;
  }

  /// Generate PDF as bytes
  Future<Uint8List> generatePdfBytes(Contract contract) async {
    // #region agent log
    final bytesStartTime = DateTime.now().millisecondsSinceEpoch;
    // #endregion
    final pdf = await generateContractPdf(contract);
    // #region agent log
    final saveStartTime = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode) print('🔍 [PDF-SAVE-START] time=$saveStartTime (Hyp: D)');
    // #endregion
    final bytes = await pdf.save();
    // #region agent log
    final bytesEndTime = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode)
      print(
        '🔍 [PDF-BYTES] save_time=${bytesEndTime - saveStartTime}ms, total_time=${bytesEndTime - bytesStartTime}ms, size_bytes=${bytes.length} (Hyp: D)',
      );
    // #endregion
    return bytes;
  }

  /// Upload PDF to Firebase Storage
  Future<String> uploadPdfToStorage(
    Contract contract,
    Uint8List pdfBytes,
  ) async {
    try {
      // #region agent log
      final uploadStartTime = DateTime.now().millisecondsSinceEpoch;
      if (kDebugMode)
        print(
          '🔍 [STORAGE-UPLOAD-START] size_bytes=${pdfBytes.length}, time=$uploadStartTime (Hyp: E)',
        );
      // #endregion
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

      // #region agent log
      final urlStartTime = DateTime.now().millisecondsSinceEpoch;
      if (kDebugMode)
        print(
          '🔍 [STORAGE-UPLOAD-DONE] upload_time=${urlStartTime - uploadStartTime}ms (Hyp: E)',
        );
      // #endregion
      final downloadUrl = await ref.getDownloadURL();

      // #region agent log
      final uploadEndTime = DateTime.now().millisecondsSinceEpoch;
      if (kDebugMode)
        print(
          '🔍 [STORAGE-COMPLETE] get_url_time=${uploadEndTime - urlStartTime}ms, total_upload_time=${uploadEndTime - uploadStartTime}ms (Hyp: E)',
        );
      // #endregion

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
    // Calculate deposit percentage
    final depositPercentage = contract.subtotal > 0
        ? ((contract.depositAmount / contract.subtotal) * 100).toStringAsFixed(
            0,
          )
        : '40';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: PdfStyles.cardDecoration,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Quote', style: PdfStyles.h3),
          pw.SizedBox(height: PdfStyles.spacingMedium),
          // Products - without individual prices
          ...contract.products.map((product) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(product.name, style: PdfStyles.bodyText),
            );
          }).toList(),
          PdfStyles.divider,
          // Pricing summary - right aligned
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _buildPriceRow(
                'Total Amount:',
                contract.subtotal,
                isHighlighted: true,
              ),
              pw.SizedBox(height: 12),
              _buildPriceRow(
                'Deposit Allocation ($depositPercentage%):',
                contract.depositAmount,
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
                _buildInfoRow('Signature:', contract.digitalSignature ?? 'N/A'),
                pw.SizedBox(height: 8),
                _buildInfoRow(
                  'Signature Token:',
                  contract.digitalSignatureToken ?? 'N/A',
                ),
                pw.SizedBox(height: 8),
                _buildInfoRow(
                  'Signed:',
                  contract.signedAt != null
                      ? dateFormat.format(contract.signedAt!)
                      : 'N/A',
                ),
                pw.SizedBox(height: 8),
                _buildInfoRow('IP Address:', contract.ipAddress ?? 'N/A'),
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

  /// Build invoice-style two-column info row
  pw.Widget _buildInvoiceInfoRow(Contract contract) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left column: Company info
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'MedWave',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.TextSpan(
                      text: 'TM',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                    pw.TextSpan(
                      text: ' RSA PTY LTD',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Blaaukrans Office Park', style: PdfStyles.bodyText),
              pw.Text('Jeffreys Bay, 6330', style: PdfStyles.bodyText),
              pw.Text('Call: +27 79 427 2486', style: PdfStyles.bodyText),
              pw.Text('info@medwavegroup.com', style: PdfStyles.bodyText),
              pw.Text('www.medwavegroup.com', style: PdfStyles.bodyText),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        // Right column: Customer info
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoLine(
                'Date:',
                DateFormat('yyyy-MM-dd').format(contract.createdAt),
              ),
              pw.SizedBox(height: 4),
              _buildInfoLine('Customer Name:', contract.customerName),
              pw.SizedBox(height: 4),
              _buildInfoLine('Customer Phone:', contract.phone),
              pw.SizedBox(height: 4),
              _buildInfoLine('Customer Email:', contract.email),
            ],
          ),
        ),
      ],
    );
  }

  /// Build info line for invoice
  pw.Widget _buildInfoLine(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('$label ', style: PdfStyles.labelText),
        pw.Expanded(child: pw.Text(value, style: PdfStyles.bodyText)),
      ],
    );
  }

  /// Build invoice-style quote table
  pw.Widget _buildInvoiceQuoteTable(Contract contract) {
    // Calculate deposit percentage
    final depositPercentage = contract.subtotal > 0
        ? ((contract.depositAmount / contract.subtotal) * 100).toStringAsFixed(
            0,
          )
        : '40';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        children: [
          // Table header
          pw.Container(
            color: PdfColors.grey300,
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Text('Name', style: PdfStyles.bodyTextBold),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'QTY',
                    style: PdfStyles.bodyTextBold,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Products
          ...contract.products
              .map(
                (product) => pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(product.name, style: PdfStyles.bodyText),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text('1', textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          // Totals section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              children: [
                _buildTotalRow('Subtotal', contract.subtotal),
                pw.SizedBox(height: 4),
                _buildTotalRow(
                  'Deposit ($depositPercentage%)',
                  contract.depositAmount,
                  isBold: true,
                ),
                pw.Divider(),
                _buildTotalRow(
                  'Total',
                  contract.subtotal,
                  isBold: true,
                  isLarge: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build total row for invoice
  pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    final style = isBold
        ? pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: isLarge ? 16 : 12,
          )
        : PdfStyles.bodyText;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('$label: ', style: style),
        pw.SizedBox(width: 20),
        pw.Text('R ${amount.toStringAsFixed(2)}', style: style),
      ],
    );
  }

  /// Build payment info with bank details
  pw.Widget _buildPaymentInfo() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 24),
        pw.Text(
          'Please complete the deposit payment to proceed with your order. Payment instructions and confirmation will be sent via email.',
          style: pw.TextStyle(fontSize: 14),
        ),
        pw.SizedBox(height: 24),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey100),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Account holder and ID
              _buildBankInfoLine('Account holder:', 'MEDWAVE RSA PTY LTD'),
              pw.SizedBox(height: 4),
              _buildBankInfoLine('ID/Reg Number:', '2024/700802/07'),
              pw.SizedBox(height: 16),

              // Three-column layout for bank details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Column 1
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Standard Bank',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        _buildBankInfoLine('Branch:', 'JEFFREY\'S BAY'),
                      ],
                    ),
                  ),
                  // Column 2
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildBankInfoLine('Account type:', 'CURRENT'),
                        pw.SizedBox(height: 4),
                        _buildBankInfoLine('Branch code:', '000315'),
                      ],
                    ),
                  ),
                  // Column 3
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildBankInfoLine(
                          'Account number:',
                          '10 23 582 938 0',
                        ),
                        pw.SizedBox(height: 4),
                        _buildBankInfoLine('SWIFT code:', 'SBZAZAJJ'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build bank info line with small label and bold value
  pw.Widget _buildBankInfoLine(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label ',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
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
        pw.Expanded(child: pw.Text(value, style: PdfStyles.bodyText)),
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
              pw.Text('MedWave RSA PTY LTD', style: PdfStyles.smallText),
              pw.Text('www.medwavegroup.com', style: PdfStyles.smallText),
            ],
          ),
        ],
      ),
    );
  }
}
