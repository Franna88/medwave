import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../models/contracts/contract.dart' show Contract, ContractProduct;
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

    // Page 2+: Invoice-style layout (MultiPage so long quote tables can flow)
    // #region agent log
    final page2StartTime = DateTime.now().millisecondsSinceEpoch;
    // #endregion
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header: Logo and Title both centered
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Image(greyLogo, width: 150, height: 50)),
              pw.SizedBox(height: 16),
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
          _buildInvoiceInfoRow(contract),
          pw.SizedBox(height: 24),
          // Quote table as separate widgets so MultiPage can flow across pages
          ..._buildInvoiceQuoteTableWidgets(contract),
          pw.SizedBox(height: 24),
          _buildPaymentInfo(),
          _buildFooter(),
        ],
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
            // Paragraph can span pages; pw.Text cannot, so long contract text would overflow
            pw.Paragraph(
              text: plainText,
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

    // Load signature font for PDF
    final signatureFontData = await rootBundle.load(
      'fonts/DancingScript-Bold.ttf',
    );
    final signatureFontBytes = signatureFontData.buffer.asUint8List();
    final signatureFont = pw.Font.ttf(signatureFontBytes.buffer.asByteData());

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
            _buildSignatureCertificate(contract, signatureFont),
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
  pw.Widget _buildSignatureCertificate(
    Contract contract,
    pw.Font signatureFont,
  ) {
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
          // Signature Display - Large and Prominent
          pw.Text('SIGNATURE', style: PdfStyles.labelText),
          pw.SizedBox(height: 8),
          pw.Text(
            contract.digitalSignature ?? 'N/A',
            style: pw.TextStyle(
              font: signatureFont,
              fontSize: 32,
              color: PdfStyles.textColor,
            ),
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
              pw.Text(
                'Blaaukrans Office Park',
                style: pw.TextStyle(fontSize: 12, color: PdfStyles.textColor),
              ),
              pw.Text(
                'Jeffreys Bay, 6330',
                style: pw.TextStyle(fontSize: 12, color: PdfStyles.textColor),
              ),
              pw.Text(
                'Call: +27 79 427 2486',
                style: pw.TextStyle(fontSize: 12, color: PdfStyles.textColor),
              ),
              pw.Text(
                'info@medwavegroup.com',
                style: pw.TextStyle(fontSize: 12, color: PdfStyles.textColor),
              ),
              pw.Text(
                'www.medwavegroup.com',
                style: pw.TextStyle(fontSize: 12, color: PdfStyles.textColor),
              ),
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
              if (contract.shippingAddress != null &&
                  contract.shippingAddress!.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                _buildInfoLine('Shipping Address:', contract.shippingAddress!),
              ],
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
        pw.Text(
          '$label ',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfStyles.grayColor,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, color: PdfStyles.textColor),
          ),
        ),
      ],
    );
  }

  /// Build invoice quote table as list of widgets for MultiPage (avoids overflow when many products).
  List<pw.Widget> _buildInvoiceQuoteTableWidgets(Contract contract) {
    return [
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: _buildInvoiceQuoteTableHeader(),
      ),
      ...contract.products.map(
        (product) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: const pw.BorderSide(color: PdfColors.grey400),
              right: const pw.BorderSide(color: PdfColors.grey400),
              bottom: const pw.BorderSide(color: PdfColors.grey300),
            ),
          ),
          child: _buildInvoiceQuoteRow(product),
        ),
      ),
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: const pw.BorderSide(color: PdfColors.grey400),
            right: const pw.BorderSide(color: PdfColors.grey400),
            bottom: const pw.BorderSide(color: PdfColors.grey400),
          ),
        ),
        child: _buildInvoiceQuoteTotals(contract),
      ),
    ];
  }

  pw.Widget _buildInvoiceQuoteTableHeader() {
    return pw.Container(
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
    );
  }

  pw.Widget _buildInvoiceQuoteRow(ContractProduct product) {
    final isSubItem = product.isSubItem;
    return pw.Container(
      padding: pw.EdgeInsets.only(
        left: isSubItem ? 20 : 8,
        right: 8,
        top: 8,
        bottom: 8,
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              product.name,
              style: isSubItem
                  ? pw.TextStyle(
                      fontSize: 10,
                      color: PdfStyles.grayColor,
                    )
                  : PdfStyles.bodyText,
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              isSubItem ? '' : product.quantity.toString(),
              textAlign: pw.TextAlign.center,
              style: PdfStyles.bodyText,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceQuoteTotals(Contract contract) {
    // Net subtotal ex VAT (from products; discount lines are typically negative)
    double subtotalBeforeDiscount = 0;
    double discountTotal = 0;
    for (final p in contract.products) {
      if (p.lineType == 'discount') {
        discountTotal += p.lineTotal;
      } else {
        subtotalBeforeDiscount += p.lineTotal;
      }
    }
    final netSubtotalExVat = subtotalBeforeDiscount + discountTotal;
    final vatAmount = netSubtotalExVat * 0.15;
    final totalInclVat = netSubtotalExVat + vatAmount;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        children: [
          _buildSubtotalDiscountTotalRows(contract),
          pw.SizedBox(height: 4),
          _buildTotalRow('VAT (15%)', vatAmount),
          pw.SizedBox(height: 4),
          _buildTotalRow('Total (incl. VAT)', totalInclVat, isBold: true),
          pw.SizedBox(height: 4),
          _buildTotalRow(
            'Deposit Allocate',
            contract.depositAmount,
            isBold: true,
          ),
          pw.SizedBox(height: 4),
          _buildTotalRow(
            'Balance due',
            contract.remainingBalance,
            isBold: true,
          ),
        ],
      ),
    );
  }

  /// Build Subtotal and optional Discount rows from contract.products.
  pw.Widget _buildSubtotalDiscountTotalRows(Contract contract) {
    double subtotalBeforeDiscount = 0;
    double discountTotal = 0;
    for (final p in contract.products) {
      if (p.lineType == 'discount') {
        discountTotal += p.lineTotal;
      } else {
        subtotalBeforeDiscount += p.lineTotal;
      }
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildTotalRow('Subtotal', subtotalBeforeDiscount),
        if (discountTotal != 0) ...[
          pw.SizedBox(height: 4),
          _buildTotalRow('Discount', discountTotal, isBold: true),
        ],
      ],
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
  pw.Widget _buildInfoRow(
    String label,
    String value, {
    pw.Font? signatureFont,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(label, style: PdfStyles.labelText),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: signatureFont != null
                ? PdfStyles.signatureText(signatureFont)
                : PdfStyles.bodyText,
          ),
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
              pw.Text('MedWave RSA PTY LTD', style: PdfStyles.smallText),
              pw.Text('www.medwavegroup.com', style: PdfStyles.smallText),
            ],
          ),
        ],
      ),
    );
  }
}
