import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../models/progress_metrics.dart';
import 'firebase/analytics_service.dart';

class ExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Export patient progress report to PDF
  static Future<File> exportPatientProgressPDF(
    Patient patient,
    List<ProgressDataPoint> progressData,
  ) async {
    final pdf = pw.Document();

    // Load fonts for better text rendering
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final fontData = font.buffer.asUint8List();
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Text(
                'Patient Progress Report',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            
            pw.SizedBox(height: 20),

            // Patient Information
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Patient Information',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Text('Name: ', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${patient.fullNames} ${patient.surname}', style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Text('ID Number: ', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                      pw.Text(patient.idNumber, style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Text('Date of Birth: ', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                      pw.Text(_dateFormat.format(patient.dateOfBirth), style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Text('Contact: ', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                      pw.Text(patient.patientCell, style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Progress Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Progress Summary',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Metric', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Baseline', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Current', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Change', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Weight (kg)', style: pw.TextStyle(font: ttf)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(patient.baselineWeight.toString(), style: pw.TextStyle(font: ttf)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text((patient.currentWeight ?? 0).toString(), style: pw.TextStyle(font: ttf)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${patient.weightChange?.toStringAsFixed(1) ?? 'N/A'}%', style: pw.TextStyle(font: ttf)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Session History
            pw.Text(
              'Session History',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),

            if (progressData.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Date', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Session #', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Weight', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('VAS Score', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  ...progressData.take(10).map((point) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(_dateFormat.format(point.date), style: pw.TextStyle(font: ttf, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(point.sessionNumber.toString(), style: pw.TextStyle(font: ttf, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text((point.weight ?? 0).toStringAsFixed(1), style: pw.TextStyle(font: ttf, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text((point.vasScore ?? 0).toStringAsFixed(0), style: pw.TextStyle(font: ttf, fontSize: 10)),
                      ),
                    ],
                  )),
                ],
              )
            else
              pw.Text(
                'No session data available',
                style: pw.TextStyle(font: ttf, fontStyle: pw.FontStyle.italic),
              ),

            pw.SizedBox(height: 20),

            // Footer
            pw.Text(
              'Report generated on ${_dateTimeFormat.format(DateTime.now())}',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ];
        },
      ),
    );

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/patient_${patient.id}_progress_report.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Export all patients data to CSV
  static Future<File> exportPatientsToCSV() async {
    try {
      final csvContent = await AnalyticsService.exportPatientsToCSV();
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/patients_export_${_dateFormat.format(DateTime.now())}.csv');
      
      await file.writeAsString(csvContent);
      return file;
    } catch (e) {
      throw Exception('Failed to export patients to CSV: $e');
    }
  }

  /// Export analytics summary to PDF
  static Future<File> exportAnalyticsSummaryPDF(
    DashboardAnalytics analytics,
    PatientStatistics patientStats,
    AppointmentAnalytics appointmentStats,
    SessionAnalytics sessionStats,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Text(
                'Practice Analytics Summary',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            
            pw.SizedBox(height: 20),

            // Dashboard Overview
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Practice Overview',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table.fromTextArray(
                    context: context,
                    data: <List<String>>[
                      <String>['Metric', 'Count'],
                      <String>['Total Patients', analytics.totalPatients.toString()],
                      <String>['Active Patients', analytics.activePatients.toString()],
                      <String>['Total Sessions', analytics.totalSessions.toString()],
                      <String>['Total Appointments', analytics.totalAppointments.toString()],
                      <String>['Completed Appointments', analytics.completedAppointments.toString()],
                    ],
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Patient Statistics
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Patient Demographics',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Age Distribution:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ...patientStats.ageDistribution.entries.map((entry) =>
                    pw.Text('${entry.key}: ${entry.value} patients')
                  ).toList(),
                  pw.SizedBox(height: 10),
                  pw.Text('Average Age: ${patientStats.averageAge.toStringAsFixed(1)} years'),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Appointment Statistics
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Appointment Statistics',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table.fromTextArray(
                    context: context,
                    data: <List<String>>[
                      <String>['Metric', 'Value'],
                      <String>['Completion Rate', '${appointmentStats.completionRate.toStringAsFixed(1)}%'],
                      <String>['Cancellation Rate', '${appointmentStats.cancellationRate.toStringAsFixed(1)}%'],
                      <String>['No-Show Rate', '${appointmentStats.noShowRate.toStringAsFixed(1)}%'],
                      <String>['Avg. Appointments/Day', appointmentStats.averageAppointmentsPerDay.toStringAsFixed(1)],
                    ],
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Progress Metrics
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Average Patient Progress',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table.fromTextArray(
                    context: context,
                    data: <List<String>>[
                      <String>['Metric', 'Average Change'],
                      <String>['Weight Change', '${analytics.averageWeightChange.toStringAsFixed(1)}%'],
                      <String>['Pain Reduction', '${analytics.averagePainReduction.toStringAsFixed(1)}%'],
                      <String>['Wound Healing', '${analytics.averageWoundHealing.toStringAsFixed(1)}%'],
                    ],
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Footer
            pw.SizedBox(height: 30),
            pw.Text(
              'Report generated on ${_dateTimeFormat.format(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ];
        },
      ),
    );

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/analytics_summary_${_dateFormat.format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Export session data to CSV for a specific patient
  static Future<File> exportPatientSessionsToCSV(Patient patient) async {
    try {
      final csvContent = StringBuffer();
      
      // Headers
      csvContent.writeln('Session Number,Date,Weight,VAS Score,Notes,Wound Count,Photos Count');

      // Data rows
      for (final session in patient.sessions) {
        csvContent.writeln('${session.sessionNumber},"${_dateFormat.format(session.date)}",'
            '${session.weight},${session.vasScore},"${session.notes.replaceAll('"', '""')}",'
            '${session.wounds.length},${session.photos.length}');
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/patient_${patient.id}_sessions_${_dateFormat.format(DateTime.now())}.csv');
      
      await file.writeAsString(csvContent.toString());
      return file;
    } catch (e) {
      throw Exception('Failed to export patient sessions to CSV: $e');
    }
  }

  /// Get shareable file path for exported documents
  static Future<String> getShareableFilePath(File file) async {
    // Return the file path for sharing
    return file.path;
  }
}
