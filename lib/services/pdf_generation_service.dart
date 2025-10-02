import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/patient.dart';
import 'firebase/patient_service.dart';
import '../models/icd10_code.dart';
import 'wound_management_service.dart';

class PDFGenerationService {
  
  /// Create a text style with proper Unicode support
  static pw.TextStyle _createTextStyle({
    double fontSize = 10,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor color = PdfColors.black,
    pw.FontStyle fontStyle = pw.FontStyle.normal,
  }) {
    return pw.TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontStyle: fontStyle,
      // Use font fallback to handle Unicode characters
      fontFallback: [
        pw.Font.helvetica(),
        pw.Font.courier(),
      ],
    );
  }

  /// Helper function to load images from URLs (adapted from tshwaelc project)
  static Future<List<Uint8List>> loadImages(List<String> urls) async {
    List<Uint8List> images = [];
    for (String url in urls) {
      try {
        if (url.startsWith('http')) {
          // Handle network images (Firebase URLs)
          print('🔄 Attempting to load Firebase image: $url');
          
          // Try multiple approaches for Firebase images
          http.Response? response;
          
          // Approach 1: Direct URL (works if public)
          response = await http.get(Uri.parse(url));
          
          if (response.statusCode == 200) {
            images.add(response.bodyBytes);
            print('✅ Successfully loaded network image for PDF: $url');
          } else if (response.statusCode == 403) {
            print('⚠️ Firebase image requires authentication (403): $url');
            // For now, skip the image but don't fail the PDF generation
            print('📝 Note: Image will not be included in PDF due to access restrictions');
          } else {
            print('❌ Failed to load network image (${response.statusCode}): $url');
          }
        } else {
          // Handle local file images
          final file = File(url);
          if (await file.exists()) {
            final imageBytes = await file.readAsBytes();
            images.add(imageBytes);
            print('✅ Successfully loaded local image for PDF: $url');
          } else {
            print('❌ Local file not found: $url');
          }
        }
      } catch (e) {
        print('❌ Error fetching image: $url, error: $e');
      }
    }
    return images;
  }

  /// Load single wound image for PDF inclusion
  static Future<pw.ImageProvider?> _loadWoundImage(String imagePath) async {
    try {
      final images = await loadImages([imagePath]);
      if (images.isNotEmpty) {
        return pw.MemoryImage(images.first);
      }
    } catch (e) {
      print('❌ Error loading image for PDF: $e');
    }
    return null;
  }

  /// Build wound images section for PDF with actual image display
  static Future<pw.Widget> _buildWoundImagesSection(List<String> currentPhotos, List<String> previousPhotos) async {
    // Load all images
    final allPhotoUrls = [...currentPhotos, ...previousPhotos];
    final imageData = await loadImages(allPhotoUrls);
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Remove duplicate section title - it's added in the main PDF structure
        
        // Display current session images
        if (currentPhotos.isNotEmpty && imageData.isNotEmpty) ...[
          pw.Text(
            'Current Session Images:',
            style: _createTextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: currentPhotos.asMap().entries.map((entry) {
              final index = entry.key;
              if (index < imageData.length) {
                return pw.Container(
                  width: 200,
                  height: 200,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(imageData[index]),
                    fit: pw.BoxFit.cover,
                  ),
                );
              }
              return pw.Container(); // Empty container if image failed to load
            }).toList(),
          ),
          pw.SizedBox(height: 16),
        ],
        
        // Display previous session images
        if (previousPhotos.isNotEmpty && imageData.length > currentPhotos.length) ...[
          pw.Text(
            'Previous Session Images (Comparison):',
            style: _createTextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: previousPhotos.asMap().entries.map((entry) {
              final index = entry.key + currentPhotos.length;
              if (index < imageData.length) {
                return pw.Container(
                  width: 200,
                  height: 200,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(imageData[index]),
                    fit: pw.BoxFit.cover,
                  ),
                );
              }
              return pw.Container(); // Empty container if image failed to load
            }).toList(),
          ),
          pw.SizedBox(height: 16),
        ],
        
        // Show message based on image loading status
        if (currentPhotos.isEmpty && previousPhotos.isEmpty)
          pw.Text(
            'No wound images documented for this session.',
            style: _createTextStyle(fontSize: 10, color: PdfColors.grey600),
          )
        else if (imageData.isEmpty && (currentPhotos.isNotEmpty || previousPhotos.isNotEmpty))
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange50,
              border: pw.Border.all(color: PdfColors.orange200),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '📷 Image Access Notice',
                  style: _createTextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${currentPhotos.length + previousPhotos.length} wound image(s) are available in the digital patient record but could not be embedded in this PDF due to security restrictions.',
                  style: _createTextStyle(fontSize: 9, color: PdfColors.orange800),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'High-resolution images can be accessed through the MedWave application for detailed clinical assessment.',
                  style: _createTextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.orange700),
                ),
              ],
            ),
          ),

      ],
    );
  }
  static const String _logoPath = 'images/medwave_logo_black.png';
  
  /// Generate a clinical motivation report PDF
  /// Enhanced PDF generation that intelligently handles single and multiple wounds
  static Future<File> generateEnhancedClinicalMotivationPDF({
    required String reportContent,
    required Patient patient,
    required Session session,
    required String practitionerName,
    List<SelectedICD10Code> selectedCodes = const [],
    List<String> treatmentCodes = const [],
    String? additionalNotes,
    Session? previousSession,
    String? practitionerContact,
  }) async {
    final isMultiWound = WoundManagementService.hasMultipleWounds(patient);
    
    if (isMultiWound) {
      return _generateMultiWoundPDF(
        reportContent: reportContent,
        patient: patient,
        session: session,
        practitionerName: practitionerName,
        selectedCodes: selectedCodes,
        treatmentCodes: treatmentCodes,
        additionalNotes: additionalNotes,
        previousSession: previousSession,
        practitionerContact: practitionerContact,
      );
    } else {
      return generateClinicalMotivationPDF(
        reportContent: reportContent,
        patient: patient,
        session: session,
        practitionerName: practitionerName,
        selectedCodes: selectedCodes,
        treatmentCodes: treatmentCodes,
        additionalNotes: additionalNotes,
        practitionerContact: practitionerContact,
      );
    }
  }

  static Future<File> generateClinicalMotivationPDF({
    required String reportContent,
    required Patient patient,
    required Session session,
    required String practitionerName,
    List<SelectedICD10Code> selectedCodes = const [],
    List<String> treatmentCodes = const [],
    String? additionalNotes,
    String? practitionerContact,
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
        header: (context) => _buildHeader(logoImage, context, practitionerName: practitionerName, practitionerContact: practitionerContact),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // 1. PATIENT INFORMATION SECTION (First Block)
          _buildPatientSection(patient, session),
          pw.SizedBox(height: 20),
          
          // 2. MOTIVATIONAL REPORT SECTION (Second Block)
          _buildReportTitle(),
          pw.SizedBox(height: 15),
          _buildReportContent(reportContent),
          pw.SizedBox(height: 20),
          
          // 3. ICD-10 CODES SECTION (Third Block)
          _buildCodesSection(selectedCodes, treatmentCodes),
          pw.SizedBox(height: 20),
          
          // Signature Section
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
  /// Generate an enhanced PDF report with photos and analytics
  static Future<File> generateEnhancedChatReportPDF({
    required String reportContent,
    required Patient patient,
    required Session session,
    required String practitionerName,
    List<SelectedICD10Code>? selectedCodes,
    String? practitionerContact,
  }) async {
    try {
      final pdf = pw.Document();
      
      // Progress analytics removed - no longer needed for PDF generation
      
      // Get current and previous session photos (with error handling)
      List<Session> sessions = [];
      try {
        sessions = await PatientService.getPatientSessions(patient.id);
      } catch (e) {
        print('⚠️ Warning: Could not load patient sessions: $e');
      }
      
      final currentSessionPhotos = session.photos;
      final previousSessionPhotos = sessions.length > 1 ? 
        sessions[sessions.length - 2].photos : <String>[];

      // Pre-load wound images section since it's now async
      final woundImagesSection = (currentSessionPhotos.isNotEmpty || previousSessionPhotos.isNotEmpty) 
          ? await _buildWoundImagesSection(currentSessionPhotos, previousSessionPhotos)
          : null;

      // Check if we have photos to determine where to put signature
      final hasPhotos = woundImagesSection != null && (currentSessionPhotos.isNotEmpty || previousSessionPhotos.isNotEmpty);

      // PAGE 1: Patient Details, ICD-10 Codes, Clinical Motivational Report
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (context) => pw.Column(
            children: [
              _buildHeader(null, context, practitionerName: practitionerName, practitionerContact: practitionerContact),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    // 1. PATIENT DETAILS SECTION
                    _buildPatientBasicInfo(patient),
                    pw.SizedBox(height: 15),
                    
                    // 2. ICD-10 SUMMARY SECTION
                    if (selectedCodes != null && selectedCodes.isNotEmpty) ...[
                      _buildICD10SummarySection(selectedCodes),
                      pw.SizedBox(height: 15),
                    ],
                    
                    // 3. CLINICAL MOTIVATIONAL REPORT
                    pw.Expanded(
                      child: _buildEnhancedChatReportContent(reportContent),
                    ),
                    
                    // Add signature here if no photos exist
                    if (!hasPhotos) ...[
                      pw.SizedBox(height: 20),
                      _buildSignatureSection(practitionerName),
                    ],
                  ],
                ),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      );

      // PAGE 2: Clinical Documentation Photos with Signatures (only if photos exist)
      if (hasPhotos) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(18),
            build: (context) => pw.Column(
              children: [
                _buildHeader(null, context, practitionerName: practitionerName, practitionerContact: practitionerContact),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Clinical Documentation Photos'),
                      pw.SizedBox(height: 15),
                      pw.Expanded(child: woundImagesSection),
                      pw.SizedBox(height: 20),
                      
                      // Add signature section below the images
                      _buildSignatureSection(practitionerName),
                    ],
                  ),
                ),
                _buildFooter(context),
              ],
            ),
          ),
        );
      }

      return await _savePDF(pdf, 'enhanced_ai_report_${patient.surname}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    } catch (e) {
      print('❌ Error generating enhanced PDF: $e');
      // Fallback to simplified version
      return await _generateSimplifiedEnhancedPDF(reportContent, patient, session, practitionerName, practitionerContact);
    }
  }

  static Future<File> generateChatReportPDF({
    required String reportContent,
    required Patient patient,
    required Session session,
    required String practitionerName,
    String? practitionerContact,
  }) async {
    try {
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
          header: (context) => _buildHeader(logoImage, context, practitionerName: practitionerName, practitionerContact: practitionerContact),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            // 1. PATIENT INFORMATION SECTION (First Block)
            _buildPatientBasicInfo(patient),
            pw.SizedBox(height: 20),
            
            // 2. MOTIVATIONAL REPORT SECTION (Second Block) 
            _buildReportTitle(title: 'Clinical Motivational Report'),
            pw.SizedBox(height: 10),
            _buildChatReportContent(reportContent),
            pw.SizedBox(height: 20),
            
            // Signature Section
            _buildSignatureSection(practitionerName),
          ],
        ),
      );
      
      return await _savePDF(pdf, _generateChatFileName(patient));
    } catch (e) {
      // If PDF generation fails, create a simplified version
      print('PDF generation failed: $e');
      if (e.toString().contains('TooManyPagesException') || e.toString().contains('too many pages')) {
        return await _generateSimplifiedPDF(reportContent, patient, practitionerName, practitionerContact);
      }
      rethrow;
    }
  }
  
  /// Generate a simplified PDF when the main generation fails
  static Future<File> _generateSimplifiedPDF(String reportContent, Patient patient, String practitionerName, String? practitionerContact) async {
    final pdf = pw.Document();
    
    // Very simple single page with just the essentials
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'MedWave Clinical Report',
              style: _createTextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Patient: ${patient.fullNames} ${patient.surname}', style: _createTextStyle(fontSize: 12)),
            pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: _createTextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.Text(
              'Clinical Report:',
              style: _createTextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.Text(
                reportContent.length > 2000 
                  ? '${reportContent.substring(0, 2000)}...\n\n[Content truncated - Please view full report in the app]'
                  : reportContent,
                style: _createTextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Practitioner: $practitionerName', style: _createTextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
    
    return await _savePDF(pdf, _generateChatFileName(patient));
  }

  /// Generate comprehensive multi-wound PDF report
  static Future<File> _generateMultiWoundPDF({
    required String reportContent,
    required Patient patient,
    required Session session,
    required String practitionerName,
    List<SelectedICD10Code> selectedCodes = const [],
    List<String> treatmentCodes = const [],
    String? additionalNotes,
    Session? previousSession,
    String? practitionerContact,
  }) async {
    final pdf = pw.Document();
    
    // Load logo if available
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(_logoPath);
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('Logo not found: $e');
    }
    
    // Page 1: Overview and Summary
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(logoImage, context, practitionerName: practitionerName, practitionerContact: practitionerContact),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Patient Information
          _buildPatientSection(patient, session),
          pw.SizedBox(height: 20),
          
          // Multi-Wound Overview
          _buildMultiWoundOverviewSection(session, previousSession),
          pw.SizedBox(height: 20),
          
          // Clinical Motivation Report
          _buildReportTitle(title: 'Clinical Motivation for Multi-Wound Care'),
          pw.SizedBox(height: 15),
          _buildReportContent(reportContent),
          pw.SizedBox(height: 20),
          
          // ICD-10 Codes
          _buildCodesSection(selectedCodes, treatmentCodes),
        ],
      ),
    );
    
    // Page 2+: Individual Wound Details
    for (int i = 0; i < session.wounds.length; i++) {
      final wound = session.wounds[i];
      final previousWound = previousSession?.wounds.where((w) => w.id == wound.id).firstOrNull;
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => _buildHeader(logoImage, context, practitionerName: practitionerName, practitionerContact: practitionerContact),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            _buildIndividualWoundSection(wound, previousWound, i + 1),
            pw.SizedBox(height: 20),
            if (wound.photos.isNotEmpty) ...[
              _buildWoundPhotosSection(wound.photos, 'Wound ${i + 1} Photos'),
              pw.SizedBox(height: 20),
            ],
          ],
        ),
      );
    }
    
    // Final page: Signature and notes
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(logoImage, context, practitionerName: practitionerName, practitionerContact: practitionerContact),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildTreatmentSummarySection(session.wounds, previousSession?.wounds),
          pw.SizedBox(height: 20),
          _buildSignatureSection(practitionerName),
          if (additionalNotes != null) ...[
            pw.SizedBox(height: 15),
            _buildAdditionalNotes(additionalNotes),
          ],
        ],
      ),
    );
    
    // Save and return file using the platform-aware save method
    final fileName = 'multi_wound_report_${patient.surname}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    return await _savePDF(pdf, fileName);
  }
  
  static pw.Widget _buildHeader(pw.ImageProvider? logoImage, pw.Context context, {String? practitionerName, String? practitionerContact}) {
    // Extract practitioner name and practice number if formatted as "Name (PracticeNumber)"
    String displayName = 'Wound Care Specialist';
    String subtitle = 'Advanced Wound Care Specialists';
    String contactInfo = 'Contact: wounds@hauteCare.co.za | 082 828 2476';
    
    if (practitionerName != null && practitionerName.isNotEmpty) {
      displayName = practitionerName;
      subtitle = 'Wound Care Specialist';
      
      if (practitionerContact != null && practitionerContact.isNotEmpty) {
        contactInfo = 'Contact: $practitionerContact';
      }
    }
    
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
                  displayName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  contactInfo,
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
                _buildInfoRow('Email:', patient.email.isEmpty ? 'Not provided' : patient.email),
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
    // Limit content length to prevent TooManyPagesException
    const maxContentLength = 4000; // Roughly 2-3 pages worth of text
    String processedContent = content;
    
    if (content.length > maxContentLength) {
      processedContent = content.substring(0, maxContentLength);
      // Try to end at a complete sentence
      final lastPeriod = processedContent.lastIndexOf('.');
      if (lastPeriod > maxContentLength - 200) {
        processedContent = processedContent.substring(0, lastPeriod + 1);
      }
      processedContent += '\n\n[Content truncated for PDF export - Full report available in app]';
    }
    
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
              'CLINICAL MOTIVATIONAL REPORT',
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
              processedContent,
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
    if (kIsWeb) {
      // Web platform: Show helpful message instead of failing
      throw UnsupportedError(
        'PDF generation is currently not supported on web browsers. '
        'Please use the mobile app for PDF report generation. '
        'This feature requires native file system access which is not available in web browsers.'
      );
    } else {
      // Mobile/desktop platforms: save to file system
      final pdfBytes = await pdf.save();
      return _saveMobilePDF(pdfBytes, fileName);
    }
  }

  /// Save PDF on mobile/desktop platforms to file system
  static Future<File> _saveMobilePDF(Uint8List pdfBytes, String fileName) async {
    try {
      // Request storage permissions on Android
      if (Platform.isAndroid) {
        var permission = await Permission.storage.status;
        if (!permission.isGranted) {
          permission = await Permission.storage.request();
          if (!permission.isGranted) {
            print('⚠️ Storage permission denied, using app directory');
          }
        }
      }

      // Try to save to a more accessible location
      Directory directory;
      
      if (Platform.isAndroid) {
        try {
          // First try to use the public Downloads directory
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            // Create MedWave subfolder in Downloads
            directory = Directory('${downloadsDir.path}/MedWave');
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }
            print('📁 Using Downloads/MedWave directory: ${directory.path}');
          } else {
            // Fallback to external storage
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              directory = Directory('${externalDir.path}/Downloads');
              if (!await directory.exists()) {
                await directory.create(recursive: true);
              }
              print('📁 Using external storage directory: ${directory.path}');
            } else {
              throw Exception('No external storage available');
            }
          }
        } catch (e) {
          print('⚠️ Could not access external storage: $e');
          // Fallback to documents directory
          directory = await getApplicationDocumentsDirectory();
          print('📁 Using app documents directory: ${directory.path}');
        }
      } else {
        // On iOS, use Documents directory (accessible via Files app)
        directory = await getApplicationDocumentsDirectory();
        print('📁 Using iOS documents directory: ${directory.path}');
      }

      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      
      // Debug logging for testing
      print('📄 PDF Generated: ${file.path}');
      print('📊 PDF Size: ${(pdfBytes.length / 1024).toStringAsFixed(2)} KB');
      print('✅ PDF File Exists: ${await file.exists()}');
      
      return file;
    } catch (e) {
      print('❌ Error saving PDF: $e');
      // Fallback to app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      
      print('📄 PDF Generated (Fallback): ${file.path}');
      return file;
    }
  }

  /// Open the generated PDF file for viewing
  static Future<bool> openPDF(File pdfFile) async {
    if (kIsWeb) {
      // On web, PDF generation is not supported
      print('ℹ️ PDF opening not available on web platform');
      return false;
    }
    
    try {
      print('📱 Attempting to open PDF: ${pdfFile.path}');
      
      if (!await pdfFile.exists()) {
        print('❌ PDF file does not exist');
        return false;
      }

      final result = await OpenFilex.open(pdfFile.path);
      print('📱 OpenFilex result: ${result.type} - ${result.message}');
      
      if (result.type == ResultType.done) {
        print('✅ PDF opened successfully');
        return true;
      } else {
        print('⚠️ PDF open result: ${result.message}');
        return false;
      }
    } catch (e) {
      print('❌ Error opening PDF: $e');
      return false;
    }
  }

  /// Share the PDF file via system share sheet
  static Future<bool> sharePDF(File pdfFile, {String? subject}) async {
    if (kIsWeb) {
      // On web, PDF generation is not supported
      print('ℹ️ PDF sharing not available on web platform');
      return false;
    }
    
    try {
      print('📤 Attempting to share PDF: ${pdfFile.path}');
      
      if (!await pdfFile.exists()) {
        print('❌ PDF file does not exist for sharing');
        return false;
      }

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: subject ?? 'MedWave Clinical Report',
        text: 'Please find the attached clinical report.',
      );
      
      print('✅ PDF shared successfully');
      return true;
    } catch (e) {
      print('❌ Error sharing PDF: $e');
      return false;
    }
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue800,
        ),
      ),
    );
  }

  /// Create a comprehensive 4-paragraph summary from the full clinical report
  static String _createFourParagraphSummary(String content) {
    // Split content into sentences for intelligent summarization
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
    
    if (sentences.length <= 16) {
      // If manageable length, distribute evenly into 4 paragraphs
      final quarter = (sentences.length / 4).ceil();
      final paragraph1 = sentences.take(quarter).join(' ');
      final paragraph2 = sentences.skip(quarter).take(quarter).join(' ');
      final paragraph3 = sentences.skip(quarter * 2).take(quarter).join(' ');
      final paragraph4 = sentences.skip(quarter * 3).join(' ');
      return '$paragraph1\n\n$paragraph2\n\n$paragraph3\n\n$paragraph4';
    }
    
    // For longer content, create focused 4-paragraph structure with 4 sentences each
    final paragraph1 = sentences.take(4).join(' '); // Patient identification & presentation
    final paragraph2 = sentences.skip(4).take(4).join(' '); // Clinical assessment & findings
    final paragraph3 = sentences.skip(8).take(4).join(' '); // Treatment & interventions
    final paragraph4 = sentences.skip(sentences.length - 4).take(4).join(' '); // Authorization & conclusion
    
    return '$paragraph1\n\n$paragraph2\n\n$paragraph3\n\n$paragraph4';
  }

  static pw.Widget _buildEnhancedChatReportContent(String content) {
    // Optimized for 4 paragraphs with 4 lines each to fill page 1 space
    String processedContent = _createFourParagraphSummary(content);
    
    // Ensure maximum 4 paragraphs by limiting content further
    final paragraphs = processedContent.split('\n\n');
    if (paragraphs.length > 4) {
      processedContent = paragraphs.take(4).join('\n\n');
    }
    
    // Generous limit for 4 comprehensive paragraphs
    const maxContentLength = 3000; // Increased for 4 detailed paragraphs
    if (processedContent.length > maxContentLength) {
      processedContent = processedContent.substring(0, maxContentLength);
      final lastPeriod = processedContent.lastIndexOf('.');
      if (lastPeriod > maxContentLength - 100) {
        processedContent = processedContent.substring(0, lastPeriod + 1);
      }
    }
    
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.purple400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10), // Reduced padding
            decoration: pw.BoxDecoration(
              color: PdfColors.purple100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              'CLINICAL MOTIVATIONAL REPORT',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple800,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10), // Reduced padding
            child: pw.Text(
              processedContent,
              style: pw.TextStyle(fontSize: 10, lineSpacing: 1.1), // Slightly tighter line spacing
              textAlign: pw.TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBeforeAfterPhotosSection(List<String> previousPhotos, List<String> currentPhotos) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (previousPhotos.isNotEmpty) ...[
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'BEFORE (Previous Session)',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        height: 120,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'Previous Session Photo\n(${previousPhotos.length} photo${previousPhotos.length > 1 ? 's' : ''})',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
              ],
              if (currentPhotos.isNotEmpty) ...[
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'AFTER (Current Session)',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        height: 120,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'Current Session Photo\n(${currentPhotos.length} photo${currentPhotos.length > 1 ? 's' : ''})',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (previousPhotos.isEmpty && currentPhotos.isEmpty)
            pw.Center(
              child: pw.Text(
                'No photos available for comparison',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Note: Photo files are stored securely and referenced in the patient management system.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }



  /// Build ICD10 codes summary section for quick admin reference
  static pw.Widget _buildICD10SummarySection(List<SelectedICD10Code> selectedCodes) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.orange400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              'ICD-10 DIAGNOSTIC CODES SUMMARY',
              style: _createTextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.orange800,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Group codes by type
                ...selectedCodes.where((c) => c.type == ICD10CodeType.primary).map((code) => 
                  _buildCodeRow('PRIMARY', code.code.icd10Code, code.code.whoFullDescription, code.code.isPmbEligible)
                ),
                ...selectedCodes.where((c) => c.type == ICD10CodeType.secondary).map((code) => 
                  _buildCodeRow('SECONDARY', code.code.icd10Code, code.code.whoFullDescription, code.code.isPmbEligible)
                ),
                ...selectedCodes.where((c) => c.type == ICD10CodeType.externalCause).map((code) => 
                  _buildCodeRow('EXTERNAL CAUSE', code.code.icd10Code, code.code.whoFullDescription, code.code.isPmbEligible)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual code row for ICD10 summary
  static pw.Widget _buildCodeRow(String type, String code, String description, bool isPmb) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 80,
            child: pw.Text(
              type,
              style: _createTextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Container(
            width: 60,
            child: pw.Text(
              code,
              style: _createTextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              description,
              style: _createTextStyle(fontSize: 9),
            ),
          ),
          if (isPmb) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColors.green,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'PMB',
                style: _createTextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<File> _generateSimplifiedEnhancedPDF(String reportContent, Patient patient, Session session, String practitionerName, String? practitionerContact) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Enhanced Clinical Report (Simplified)',
              style: _createTextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              reportContent.length > 2000 
                ? '${reportContent.substring(0, 2000)}...\n\n[Content truncated due to PDF generation constraints]'
                : reportContent,
              style: _createTextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Note: Full enhanced report with photos and analytics requires additional processing.',
              style: _createTextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      ),
    );

    return await _savePDF(pdf, 'simplified_enhanced_ai_report_${patient.surname}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
  }

  /// Build multi-wound overview section for PDF
  static pw.Widget _buildMultiWoundOverviewSection(Session session, Session? previousSession) {
    final totalArea = session.wounds.fold<double>(0, (sum, wound) => sum + wound.area);
    final totalVolume = session.wounds.fold<double>(0, (sum, wound) => sum + wound.volume);
    
    double? previousTotalArea;
    if (previousSession != null && previousSession.wounds.isNotEmpty) {
      previousTotalArea = previousSession.wounds.fold<double>(0, (sum, wound) => sum + wound.area);
    }
    
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
              'MULTI-WOUND OVERVIEW',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Column(
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildMetricBox('Total Wounds', '${session.wounds.length}', PdfColors.blue),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: _buildMetricBox('Combined Area', '${totalArea.toStringAsFixed(1)} cm²', PdfColors.green),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: _buildMetricBox('Combined Volume', '${totalVolume.toStringAsFixed(1)} cm³', PdfColors.orange),
                    ),
                  ],
                ),
                if (previousTotalArea != null) ...[
                  pw.SizedBox(height: 15),
                  _buildProgressIndicator(previousTotalArea, totalArea),
                ],
                pw.SizedBox(height: 15),
                _buildWoundStageDistribution(session.wounds),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual wound section for PDF
  static pw.Widget _buildIndividualWoundSection(Wound wound, Wound? previousWound, int woundNumber) {
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
              'WOUND $woundNumber: ${wound.location.toUpperCase()}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple800,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Basic wound information
                pw.Row(
                  children: [
                    pw.Expanded(child: _buildInfoRow('Type:', wound.type)),
                    pw.Expanded(child: _buildInfoRow('Stage:', _getStageDescription(wound.stage))),
                  ],
                ),
                pw.SizedBox(height: 10),
                
                // Current measurements
                pw.Text(
                  'Current Measurements:',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    pw.Expanded(child: _buildMeasurementRow('Length:', '${wound.length.toStringAsFixed(1)} cm')),
                    pw.Expanded(child: _buildMeasurementRow('Width:', '${wound.width.toStringAsFixed(1)} cm')),
                    pw.Expanded(child: _buildMeasurementRow('Depth:', '${wound.depth.toStringAsFixed(1)} cm')),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    pw.Expanded(child: _buildMeasurementRow('Area:', '${wound.area.toStringAsFixed(1)} cm²')),
                    pw.Expanded(child: _buildMeasurementRow('Volume:', '${wound.volume.toStringAsFixed(1)} cm³')),
                    pw.Expanded(child: pw.Container()), // Empty space
                  ],
                ),
                
                // Progress comparison if available
                if (previousWound != null) ...[
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'Progress Since Last Session:',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  _buildWoundProgressTable(wound, previousWound),
                ],
                
                // Description
                if (wound.description.isNotEmpty) ...[
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'Assessment Notes:',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(
                      wound.description,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build treatment summary section
  static pw.Widget _buildTreatmentSummarySection(List<Wound> currentWounds, List<Wound>? previousWounds) {
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
              'TREATMENT SUMMARY & RECOMMENDATIONS',
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
                  'Overall Assessment:',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Patient presents with ${currentWounds.length} wounds requiring continued wound care management. Individual wound assessments and progress tracking indicate varying stages of healing.',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 10),
                
                pw.Text(
                  'Treatment Recommendations:',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  '• Continue specialized wound care treatment for all ${currentWounds.length} wounds\n'
                  '• Regular monitoring and assessment of healing progress\n'
                  '• Individual wound-specific treatment protocols\n'
                  '• Follow-up sessions as clinically indicated\n'
                  '• Patient education on wound care management',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                
                if (previousWounds != null && previousWounds.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Progress Summary:',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    _generateProgressSummary(currentWounds, previousWounds),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build wound photos section
  static pw.Widget _buildWoundPhotosSection(List<String> photos, String title) {
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
              color: PdfColors.orange100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.orange800,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Text(
              photos.isNotEmpty
                  ? '${photos.length} photo(s) are available in the digital patient record.'
                  : 'No photos documented for this wound.',
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to build metric boxes
  static pw.Widget _buildMetricBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: color,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build progress indicator
  static pw.Widget _buildProgressIndicator(double previousArea, double currentArea) {
    final change = ((previousArea - currentArea) / previousArea * 100);
    final isImproving = change > 0;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: isImproving ? PdfColors.green50 : PdfColors.red50,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(
          color: isImproving ? PdfColors.green300 : PdfColors.red300,
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            isImproving ? '↗ ' : '↘ ',
            style: pw.TextStyle(
              fontSize: 16,
              color: isImproving ? PdfColors.green800 : PdfColors.red800,
            ),
          ),
          pw.Text(
            'Overall Progress: ${change.abs().toStringAsFixed(1)}% ${isImproving ? 'improvement' : 'increase'} in total wound area',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: isImproving ? PdfColors.green800 : PdfColors.red800,
            ),
          ),
        ],
      ),
    );
  }

  /// Build wound stage distribution
  static pw.Widget _buildWoundStageDistribution(List<Wound> wounds) {
    final stageCount = <WoundStage, int>{};
    for (final wound in wounds) {
      stageCount[wound.stage] = (stageCount[wound.stage] ?? 0) + 1;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Wound Stage Distribution:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        ...stageCount.entries.map((entry) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              '• ${_getStageDescription(entry.key)}: ${entry.value} wound${entry.value != 1 ? 's' : ''}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        }).toList(),
      ],
    );
  }

  /// Build wound progress table
  static pw.Widget _buildWoundProgressTable(Wound current, Wound previous) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Measurement', isHeader: true),
            _buildTableCell('Previous', isHeader: true),
            _buildTableCell('Current', isHeader: true),
            _buildTableCell('Change', isHeader: true),
          ],
        ),
        _buildProgressTableRow('Length (cm)', previous.length, current.length),
        _buildProgressTableRow('Width (cm)', previous.width, current.width),
        _buildProgressTableRow('Depth (cm)', previous.depth, current.depth),
        _buildProgressTableRow('Area (cm²)', previous.area, current.area),
        _buildProgressTableRow('Volume (cm³)', previous.volume, current.volume),
      ],
    );
  }

  /// Build progress table row
  static pw.TableRow _buildProgressTableRow(String label, double previous, double current) {
    final change = current - previous;
    final isImproving = change < 0; // Smaller is better for wounds
    
    return pw.TableRow(
      children: [
        _buildTableCell(label),
        _buildTableCell(previous.toStringAsFixed(1)),
        _buildTableCell(current.toStringAsFixed(1)),
        _buildTableCell(
          '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}',
          color: isImproving ? PdfColors.green800 : PdfColors.red800,
        ),
      ],
    );
  }

  /// Build table cell
  static pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Build measurement row
  static pw.Widget _buildMeasurementRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text('$label ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  /// Get stage description
  static String _getStageDescription(WoundStage stage) {
    switch (stage) {
      case WoundStage.stage1:
        return 'Stage I';
      case WoundStage.stage2:
        return 'Stage II';
      case WoundStage.stage3:
        return 'Stage III';
      case WoundStage.stage4:
        return 'Stage IV';
      case WoundStage.unstageable:
        return 'Unstageable';
      case WoundStage.deepTissueInjury:
        return 'Deep Tissue Injury';
    }
  }

  /// Generate progress summary
  static String _generateProgressSummary(List<Wound> current, List<Wound> previous) {
    int improving = 0;
    int stable = 0;
    int worsening = 0;
    
    for (final currentWound in current) {
      final previousWound = previous.where((w) => w.id == currentWound.id).firstOrNull;
      if (previousWound != null) {
        final areaChange = (previousWound.area - currentWound.area) / previousWound.area;
        if (areaChange > 0.1) {
          improving++;
        } else if (areaChange < -0.1) {
          worsening++;
        } else {
          stable++;
        }
      }
    }
    
    return 'Of ${current.length} wounds assessed: $improving showing improvement, $stable stable, $worsening requiring additional attention.';
  }
}
