import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../models/icd10_code.dart';

class PDFGenerationService {
  static const String _logoPath = 'images/medwave_logo_black.png';
  
  /// Generate a clinical motivation report PDF
  static Future<File> generateClinicalMotivationPDF({
    required String reportContent,
    required Patient patient,
    required Session session,
    required String practitionerName,
    List<SelectedICD10Code> selectedCodes = const [],
    List<String> treatmentCodes = const [],
    String? additionalNotes,
  }) async {
    final pdf = pw.Document();
    
    // Load logo if available
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(_logoPath);
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo not available, continue without it
      print('Logo not found: $e');
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(logoImage, context),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildReportTitle(),
          pw.SizedBox(height: 20),
          _buildPatientSection(patient, session),
          pw.SizedBox(height: 15),
          _buildCodesSection(selectedCodes, treatmentCodes),
          pw.SizedBox(height: 20),
          _buildReportContent(reportContent),
          pw.SizedBox(height: 20),
          _buildSignatureSection(practitionerName),
          if (additionalNotes != null) ...[
            pw.SizedBox(height: 15),
            _buildAdditionalNotes(additionalNotes),
          ],
        ],
      ),
    );
    
    return await _savePDF(pdf, _generateFileName(patient, session));
  }
  
  /// Generate a simple report PDF from chat conversation
  static Future<File> generateChatReportPDF({
    required String reportContent,
    required Patient patient,
    required Session session,
    required String practitionerName,
  }) async {
    final pdf = pw.Document();
    
    // Load logo if available
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(_logoPath);
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Continue without logo
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(logoImage, context),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildReportTitle(title: 'AI Generated Clinical Report'),
          pw.SizedBox(height: 20),
          _buildPatientBasicInfo(patient),
          pw.SizedBox(height: 20),
          _buildChatReportContent(reportContent),
          pw.SizedBox(height: 20),
          _buildSignatureSection(practitionerName),
        ],
      ),
    );
    
    return await _savePDF(pdf, _generateChatFileName(patient));
  }
  
  static pw.Widget _buildHeader(pw.ImageProvider? logoImage, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logoImage != null) ...[
            pw.Image(logoImage, width: 80, height: 80),
            pw.SizedBox(width: 20),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MedWave Wound Care Clinic',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Advanced Wound Care Specialists',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Contact: wounds@hauteCare.co.za | 082 828 2476',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'DATE: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        children: [
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by MedWave AI Assistant',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Confidential Medical Document',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildReportTitle({String title = 'Clinical Motivation for Wound Care'}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Center(
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
      ),
    );
  }
  
  static pw.Widget _buildPatientSection(Patient patient, Session session) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(
              'PATIENT INFORMATION',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Column(
                      children: [
          _buildInfoRow('Patient Name:', '${patient.fullNames} ${patient.surname}'),
          _buildInfoRow('Medical Aid:', patient.medicalAidSchemeName.isEmpty ? 'Not specified' : patient.medicalAidSchemeName),
          _buildInfoRow('Membership No:', patient.medicalAidNumber.isEmpty ? 'Not specified' : patient.medicalAidNumber),
          _buildInfoRow('Referring Doctor:', patient.referringDoctorName ?? 'Not specified'),
                _buildInfoRow('Session Date:', DateFormat('dd/MM/yyyy').format(session.date)),
                _buildInfoRow('Session Number:', session.sessionNumber.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildPatientBasicInfo(Patient patient) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(
              'PATIENT INFORMATION',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Column(
                      children: [
          _buildInfoRow('Patient Name:', '${patient.fullNames} ${patient.surname}'),
          _buildInfoRow('Medical Aid:', patient.medicalAidSchemeName.isEmpty ? 'Not specified' : patient.medicalAidSchemeName),
          _buildInfoRow('Phone:', patient.patientCell),
                _buildInfoRow('Email:', patient.email ?? 'Not provided'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildCodesSection(List<SelectedICD10Code> selectedCodes, List<String> treatmentCodes) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.green100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(
              'CODING INFORMATION',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ICD-10 Codes:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                if (selectedCodes.isEmpty)
                  pw.Text('• To be determined based on clinical assessment', style: pw.TextStyle(fontSize: 11))
                else
                  ...selectedCodes.map((code) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      '• ${code.code.icd10Code}: ${code.code.whoFullDescription} (${code.type.displayName})',
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  )),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Treatment Codes:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                if (treatmentCodes.isEmpty)
                  pw.Text('• Standard wound care codes to be applied', style: pw.TextStyle(fontSize: 11))
                else
                  ...treatmentCodes.map((code) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text('• $code', style: pw.TextStyle(fontSize: 11)),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildReportContent(String content) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(
              'CLINICAL MOTIVATION REPORT',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Text(
              content,
              style: pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
              textAlign: pw.TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildChatReportContent(String content) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.purple100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(
              'AI GENERATED CLINICAL REPORT',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple800,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Text(
              content,
              style: pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
              textAlign: pw.TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildSignatureSection(String practitionerName) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(15),
        child: pw.Column(
          children: [
            pw.Text(
              'Kindly authorise the treatment for IN LIEU OF HOSPITALISATION.',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Sincerely,', style: pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 30),
                    pw.Container(
                      height: 1,
                      width: 200,
                      color: PdfColors.black,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      practitionerName.isNotEmpty ? practitionerName : 'Sr. Rene Lessing',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Wound Care Specialist',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Date:', style: pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 30),
                    pw.Container(
                      height: 1,
                      width: 100,
                      color: PdfColors.black,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  static pw.Widget _buildAdditionalNotes(String notes) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.orange300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(
              'ADDITIONAL NOTES',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.orange800,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Text(
              notes,
              style: pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
  
  static String _generateFileName(Patient patient, Session session) {
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final patientName = '${patient.fullNames}_${patient.surname}'.replaceAll(' ', '_');
    return 'Clinical_Motivation_${patientName}_Session${session.sessionNumber}_$dateStr.pdf';
  }
  
  static String _generateChatFileName(Patient patient) {
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final patientName = '${patient.fullNames}_${patient.surname}'.replaceAll(' ', '_');
    return 'AI_Report_${patientName}_$dateStr.pdf';
  }
  
  static Future<File> _savePDF(pw.Document pdf, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    final pdfBytes = await pdf.save();
    await file.writeAsBytes(pdfBytes);
    
    // Debug logging for testing
    print('📄 PDF Generated: ${file.path}');
    print('📊 PDF Size: ${(pdfBytes.length / 1024).toStringAsFixed(2)} KB');
    print('✅ PDF File Exists: ${await file.exists()}');
    
    return file;
  }
}
