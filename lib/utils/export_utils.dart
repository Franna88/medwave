import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../models/progress_metrics.dart';

class ExportUtils {
  static Future<File> exportPatientProgressToPdf(
    Patient patient,
    ProgressMetrics progress,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          _buildHeader(patient),
          _buildPatientInfo(patient),
          _buildProgressSummary(progress),
          _buildProgressCharts(progress),
          _buildSessionHistory(patient),
          _buildTreatmentTimeline(patient, progress),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/patient_progress_${patient.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildHeader(Patient patient) {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Patient Progress Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated on ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.Container(
            width: 60,
            height: 60,
            decoration: pw.BoxDecoration(
              color: PdfColors.blue100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(30)),
            ),
            child: pw.Center(
              child: pw.Text(
                patient.name.split(' ').map((n) => n[0]).take(2).join(),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPatientInfo(Patient patient) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20, bottom: 20),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Patient Information',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Name', patient.name),
                    _buildInfoRow('ID Number', patient.idNumber),
                    _buildInfoRow('Age', '${patient.age} years'),
                    _buildInfoRow('Contact', patient.patientCell),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Medical Aid', patient.medicalAidSchemeName),
                    _buildInfoRow('Member Number', patient.medicalAidNumber),
                    _buildInfoRow('Treatment Start', DateFormat('MMM d, yyyy').format(patient.createdAt)),
                    _buildInfoRow('Total Sessions', '${patient.sessions.length}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildProgressSummary(ProgressMetrics progress) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Progress Summary',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildProgressMetric(
                  'Pain Reduction',
                  '${progress.painReductionPercentage.toStringAsFixed(1)}%',
                  progress.painReductionPercentage > 0 ? PdfColors.green : PdfColors.red,
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _buildProgressMetric(
                  'Weight Change',
                  '${progress.weightChangePercentage.toStringAsFixed(1)}%',
                  progress.weightChangePercentage > 0 ? PdfColors.blue : PdfColors.orange,
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _buildProgressMetric(
                  'Wound Healing',
                  '${progress.woundHealingPercentage.toStringAsFixed(1)}%',
                  progress.woundHealingPercentage > 0 ? PdfColors.green : PdfColors.grey,
                ),
              ),
            ],
          ),
          if (progress.improvementSummary.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                progress.improvementSummary,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.green800,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildProgressMetric(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildProgressCharts(ProgressMetrics progress) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Progress Charts',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          if (progress.painHistory.isNotEmpty) ...[
            _buildDataTable(
              'Pain Score History',
              ['Session', 'Date', 'Pain Score', 'Notes'],
              progress.painHistory.map((p) => [
                'S${p.sessionNumber}',
                DateFormat('MMM d, yyyy').format(p.date),
                '${p.value.toInt()}/10',
                p.notes ?? '-',
              ]).toList(),
            ),
            pw.SizedBox(height: 16),
          ],
          if (progress.weightHistory.isNotEmpty) ...[
            _buildDataTable(
              'Weight History',
              ['Session', 'Date', 'Weight (kg)'],
              progress.weightHistory.map((p) => [
                'S${p.sessionNumber}',
                DateFormat('MMM d, yyyy').format(p.date),
                '${p.value.toStringAsFixed(1)}',
              ]).toList(),
            ),
            pw.SizedBox(height: 16),
          ],
          if (progress.woundSizeHistory.isNotEmpty) ...[
            _buildDataTable(
              'Wound Size History',
              ['Session', 'Date', 'Area (cm²)'],
              progress.woundSizeHistory.map((p) => [
                'S${p.sessionNumber}',
                DateFormat('MMM d, yyyy').format(p.date),
                '${p.value.toStringAsFixed(1)}',
              ]).toList(),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildDataTable(String title, List<String> headers, List<List<String>> data) {
    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              for (int i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: headers.map((header) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    header,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                )).toList(),
              ),
              // Data rows
              ...data.map((row) => pw.TableRow(
                children: row.map((cell) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    cell,
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                )).toList(),
              )).toList(),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSessionHistory(Patient patient) {
    final sessions = patient.sessions..sort((a, b) => b.date.compareTo(a.date));
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Recent Sessions',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(2),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Session', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Date', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Weight', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Pain', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Notes', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              // Data rows (limit to last 10 sessions)
              ...sessions.take(10).map((session) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('S${session.sessionNumber}', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(DateFormat('MMM d, yyyy').format(session.date), style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${session.weight.toStringAsFixed(1)}kg', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${session.vasScore}/10', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      session.notes.isNotEmpty ? session.notes : '-',
                      style: const pw.TextStyle(fontSize: 9),
                      maxLines: 2,
                    ),
                  ),
                ],
              )).toList(),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTreatmentTimeline(Patient patient, ProgressMetrics progress) {
    final milestones = <Map<String, dynamic>>[];
    
    // Add treatment start
    milestones.add({
      'date': patient.createdAt,
      'title': 'Treatment Started',
      'description': 'Initial assessment and baseline measurements',
    });

    // Add significant sessions
    for (int i = 0; i < patient.sessions.length; i++) {
      final session = patient.sessions[i];
      if (i % 5 == 0 || i == patient.sessions.length - 1) {
        milestones.add({
          'date': session.date,
          'title': 'Session ${session.sessionNumber}',
          'description': 'Pain: ${session.vasScore}/10, Weight: ${session.weight.toStringAsFixed(1)}kg',
        });
      }
    }

    // Sort by date
    milestones.sort((a, b) => a['date'].compareTo(b['date']));

    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Treatment Timeline',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          ...milestones.map((milestone) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  milestone['title'],
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  milestone['description'],
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  DateFormat('MMM d, yyyy').format(milestone['date']),
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}
