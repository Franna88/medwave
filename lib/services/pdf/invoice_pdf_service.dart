import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../models/streams/order.dart' as order_models;
import 'pdf_styles.dart';

/// Service for generating invoice PDFs (without contract content)
/// Uses the EXACT same layout as the contract PDF invoice page
class InvoicePdfService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static final _moneyFormat = NumberFormat('#,##0.00', 'en_US');
  static String _formatMoney(double amount) => 'R ${_moneyFormat.format(amount)}';

  /// Generate invoice PDF document
  Future<pw.Document> generateInvoicePdf({
    required order_models.Order order,
    required double depositAmount,
    String? shippingAddress,
    String? businessName,
  }) async {
    final pdf = pw.Document();

    // Load grey logo (exact same as contract PDF)
    final greyLogoData = await rootBundle.load('images/medwave_logo_grey.png');
    final greyLogoBytes = greyLogoData.buffer.asUint8List();
    final greyLogo = pw.MemoryImage(greyLogoBytes);

    // Calculate totals (subtotal ex VAT, same as contract PDF)
    final subtotalExVat = order.items.fold<double>(
      0,
      (sum, item) => sum + ((item.price ?? 0) * item.quantity),
    );
    final vatAmount = subtotalExVat * 0.15;
    final totalInclVat = subtotalExVat + vatAmount;
    // Cap deposit at total and ensure balance is never negative
    final cappedDepositAmount = depositAmount > totalInclVat
        ? totalInclVat
        : depositAmount;
    final balanceDue = max(0.0, totalInclVat - cappedDepositAmount);

    // Invoice page (EXACT same layout as contract PDF page 2)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header: Logo and Title both centered (EXACT same as contract)
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

            // Two-column: Company info | Customer info (EXACT same as contract)
            _buildInvoiceInfoRow(
              order,
              shippingAddress,
              businessName: businessName,
            ),
            pw.SizedBox(height: 24),

            // Quote table (same layout as contract: Subtotal + VAT → Total, then Deposit + Balance due)
            _buildInvoiceQuoteTable(
              order,
              subtotalExVat,
              vatAmount,
              totalInclVat,
              cappedDepositAmount,
              balanceDue,
            ),
            pw.SizedBox(height: 24),

            // Payment info + Bank details (EXACT same as contract)
            _buildPaymentInfo(),

            pw.Spacer(),
            _buildFooter(),
          ],
        ),
      ),
    );

    return pdf;
  }

  /// Generate PDF as bytes
  Future<Uint8List> generatePdfBytes({
    required order_models.Order order,
    required double depositAmount,
    String? shippingAddress,
    String? businessName,
  }) async {
    final pdf = await generateInvoicePdf(
      order: order,
      depositAmount: depositAmount,
      shippingAddress: shippingAddress,
      businessName: businessName,
    );
    return await pdf.save();
  }

  /// Upload PDF to Firebase Storage
  Future<String> uploadPdfToStorage({
    required Uint8List pdfBytes,
    required String orderId,
  }) async {
    try {
      final fileName = 'invoice_$orderId.pdf';
      final ref = _storage.ref().child('invoices/$orderId/$fileName');

      await ref.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'orderId': orderId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final downloadUrl = await ref.getDownloadURL();

      if (kDebugMode) {
        print('✅ Invoice PDF uploaded successfully: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error uploading invoice PDF: $e');
      }
      rethrow;
    }
  }

  /// Build invoice info row (EXACT same as contract PDF)
  pw.Widget _buildInvoiceInfoRow(
    order_models.Order order,
    String? shippingAddress, {
    String? businessName,
  }) {
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
              _buildQuoteInfoLine(
                'Date:',
                DateFormat('yyyy-MM-dd').format(DateTime.now()),
              ),
              pw.SizedBox(height: 4),
              _buildQuoteInfoLine('Customer Name:', order.customerName),
              if (businessName != null && businessName.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                _buildQuoteInfoLine('Business Name:', businessName),
              ],
              pw.SizedBox(height: 4),
              _buildQuoteInfoLine('Customer Phone:', order.phone),
              pw.SizedBox(height: 4),
              _buildQuoteInfoLine('Customer Email:', order.email),
              if (shippingAddress != null && shippingAddress.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                _buildQuoteInfoLineWrapped(
                  'Shipping Address:',
                  shippingAddress,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Build info line for invoice quote section (same as contract PDF)
  pw.Widget _buildQuoteInfoLine(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('$label ', style: PdfStyles.quoteSectionLabel),
        pw.Expanded(child: pw.Text(value, style: PdfStyles.quoteSectionValue)),
      ],
    );
  }

  /// Build info line with wrapping value (e.g. shipping address). Label and value
  /// flow as one paragraph so wrapped lines align at the left margin.
  pw.Widget _buildQuoteInfoLineWrapped(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$label ', style: PdfStyles.quoteSectionLabel),
          pw.TextSpan(text: value, style: PdfStyles.quoteSectionValue),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceQuoteTable(
    order_models.Order order,
    double subtotalExVat,
    double vatAmount,
    double totalInclVat,
    double depositAmount,
    double balanceDue,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        children: [
          // Table header (EXACT same as contract)
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
          // Order items (EXACT same structure as contract products)
          ...order.items.map(
            (item) => pw.Container(
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
                    child: pw.Text(item.name, style: PdfStyles.bodyText),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      '${item.quantity}',
                      textAlign: pw.TextAlign.center,
                      style: PdfStyles.bodyText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Totals: Subtotal + VAT → Total (incl. VAT), then divider, then Deposit + Balance due (same as contract PDF)
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildTotalRow('Subtotal', subtotalExVat),
                pw.SizedBox(height: 4),
                _buildTotalRow('VAT (15%)', vatAmount),
                pw.Divider(),
                pw.SizedBox(height: 4),
                _buildTotalRow(
                  'Total (incl. VAT)',
                  totalInclVat,
                  isBold: true,
                  isLarge: true,
                ),
                pw.Divider(),
                pw.SizedBox(height: 8),
                _buildTotalRow('Deposit Allocate (10%)', depositAmount),
                pw.SizedBox(height: 4),
                _buildTotalRow('Balance due', balanceDue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build total row for invoice (EXACT same as contract PDF)
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
        pw.Text(_formatMoney(amount), style: style),
      ],
    );
  }

  /// Build payment info with bank details (EXACT same as contract PDF)
  pw.Widget _buildPaymentInfo() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 24),
        pw.Text(
          'Please complete the payment for the invoice amount. Payment instructions and confirmation will be sent via email.',
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

  /// Build bank info line with small label and bold value (EXACT same as contract PDF)
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

  /// Build footer (EXACT same as contract PDF)
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
