import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/patient.dart';
import '../models/appointment.dart';

class BulkExportService {
  /// Export all patients to CSV
  Future<File?> exportPatientsToCSV(List<Patient> patients) async {
    try {
      List<List<dynamic>> rows = [];
      
      // Header row
      rows.add([
        'Patient ID',
        'First Name',
        'Last Name',
        'ID Number',
        'Date of Birth',
        'Age',
        'Gender',
        'Phone',
        'Email',
        'Address',
        'City',
        'Postal Code',
        'Medical Aid',
        'Medical Aid Number',
        'Treatment Type',
        'Total Sessions',
        'Created Date',
        'Last Session Date',
        'Status',
      ]);

      // Data rows
      for (final patient in patients) {
        rows.add([
          patient.id,
          patient.firstName,
          patient.lastName,
          patient.idNumber,
          patient.dateOfBirth != null ? DateFormat('yyyy-MM-dd').format(patient.dateOfBirth!) : '',
          patient.age?.toString() ?? '',
          patient.gender,
          patient.phoneNumber,
          patient.email,
          patient.address,
          patient.city,
          patient.postalCode,
          patient.medicalAid,
          patient.medicalAidNumber,
          patient.treatmentType,
          patient.totalSessions.toString(),
          patient.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(patient.createdAt!) : '',
          patient.lastSessionDate != null ? DateFormat('yyyy-MM-dd').format(patient.lastSessionDate!) : '',
          patient.status,
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final medwaveDir = Directory('${directory.path}/MedWave/Exports');
      if (!await medwaveDir.exists()) {
        await medwaveDir.create(recursive: true);
      }

      final fileName = 'patients_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${medwaveDir.path}/$fileName');
      await file.writeAsString(csv);

      print('✅ Patients exported to: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error exporting patients: $e');
      return null;
    }
  }

  /// Export patient sessions to CSV
  Future<File?> exportPatientSessionsToCSV(Patient patient, List<Session> sessions) async {
    try {
      List<List<dynamic>> rows = [];
      
      // Header row
      rows.add([
        'Session Number',
        'Date',
        'Session Type',
        'Duration (min)',
        'Treatment Type',
        'Chief Complaint',
        'Vital Signs - BP',
        'Vital Signs - HR',
        'Vital Signs - Temp',
        'Vital Signs - SpO2',
        'Pain Score',
        'Weight (kg)',
        'Notes',
        'Photos Count',
        'Wounds Count',
        'Follow-up Required',
        'Follow-up Date',
      ]);

      // Data rows
      for (final session in sessions) {
        rows.add([
          session.sessionNumber.toString(),
          DateFormat('yyyy-MM-dd HH:mm').format(session.date),
          session.sessionType,
          session.duration?.toString() ?? '',
          session.treatmentType,
          session.chiefComplaint,
          session.vitalSigns?.bloodPressure ?? '',
          session.vitalSigns?.heartRate?.toString() ?? '',
          session.vitalSigns?.temperature?.toString() ?? '',
          session.vitalSigns?.oxygenSaturation?.toString() ?? '',
          session.painScore?.toString() ?? '',
          session.weight?.toString() ?? '',
          session.notes,
          session.photos.length.toString(),
          session.wounds.length.toString(),
          session.followUpRequired ? 'Yes' : 'No',
          session.followUpDate != null ? DateFormat('yyyy-MM-dd').format(session.followUpDate!) : '',
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final medwaveDir = Directory('${directory.path}/MedWave/Exports');
      if (!await medwaveDir.exists()) {
        await medwaveDir.create(recursive: true);
      }

      final fileName = 'sessions_${patient.firstName}_${patient.lastName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${medwaveDir.path}/$fileName');
      await file.writeAsString(csv);

      print('✅ Sessions exported to: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error exporting sessions: $e');
      return null;
    }
  }

  /// Export appointments to CSV
  Future<File?> exportAppointmentsToCSV(List<Appointment> appointments, Map<String, Patient> patientsMap) async {
    try {
      List<List<dynamic>> rows = [];
      
      // Header row
      rows.add([
        'Appointment ID',
        'Patient Name',
        'Patient ID',
        'Date',
        'Time',
        'Duration (min)',
        'Type',
        'Status',
        'Title',
        'Notes',
        'Location',
        'Reminder Sent',
        'Created Date',
      ]);

      // Data rows
      for (final appointment in appointments) {
        final patient = patientsMap[appointment.patientId];
        rows.add([
          appointment.id,
          patient != null ? '${patient.firstName} ${patient.lastName}' : 'Unknown',
          appointment.patientId,
          DateFormat('yyyy-MM-dd').format(appointment.startTime),
          DateFormat('HH:mm').format(appointment.startTime),
          appointment.duration.toString(),
          appointment.type,
          appointment.status.name,
          appointment.title,
          appointment.notes ?? '',
          appointment.location ?? '',
          appointment.reminderSent ? 'Yes' : 'No',
          appointment.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(appointment.createdAt!) : '',
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final medwaveDir = Directory('${directory.path}/MedWave/Exports');
      if (!await medwaveDir.exists()) {
        await medwaveDir.create(recursive: true);
      }

      final fileName = 'appointments_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${medwaveDir.path}/$fileName');
      await file.writeAsString(csv);

      print('✅ Appointments exported to: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error exporting appointments: $e');
      return null;
    }
  }

  /// Export patients with date range filter
  Future<File?> exportPatientsWithDateRange(
    List<Patient> patients,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final filteredPatients = patients.where((patient) {
      if (patient.createdAt == null) return false;
      return patient.createdAt!.isAfter(startDate) && patient.createdAt!.isBefore(endDate);
    }).toList();

    return exportPatientsToCSV(filteredPatients);
  }

  /// Export sessions with date range filter
  Future<File?> exportSessionsWithDateRange(
    Patient patient,
    List<Session> sessions,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final filteredSessions = sessions.where((session) {
      return session.date.isAfter(startDate) && session.date.isBefore(endDate);
    }).toList();

    return exportPatientSessionsToCSV(patient, filteredSessions);
  }

  /// Share exported file
  Future<void> shareExportedFile(File file, {String? subject}) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject ?? 'MedWave Data Export',
        text: 'Exported data from MedWave. You can save this file to Downloads, Google Drive, or any location of your choice.',
      );
      print('✅ File shared successfully');
    } catch (e) {
      print('❌ Error sharing file: $e');
      rethrow;
    }
  }

  /// Get export directory path
  Future<String> getExportDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final medwaveDir = Directory('${directory.path}/MedWave/Exports');
    if (!await medwaveDir.exists()) {
      await medwaveDir.create(recursive: true);
    }
    return medwaveDir.path;
  }

  /// List all exported files
  Future<List<File>> listExportedFiles() async {
    try {
      final exportPath = await getExportDirectoryPath();
      final directory = Directory(exportPath);
      
      if (!await directory.exists()) {
        return [];
      }

      final files = directory.listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.csv'))
          .toList();

      // Sort by modification date (newest first)
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      return files;
    } catch (e) {
      print('❌ Error listing exported files: $e');
      return [];
    }
  }

  /// Delete exported file
  Future<bool> deleteExportedFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        print('✅ File deleted: ${file.path}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting file: $e');
      return false;
    }
  }

  /// Clear all exported files
  Future<int> clearAllExports() async {
    try {
      final files = await listExportedFiles();
      int deletedCount = 0;

      for (final file in files) {
        if (await deleteExportedFile(file)) {
          deletedCount++;
        }
      }

      print('✅ Cleared $deletedCount export files');
      return deletedCount;
    } catch (e) {
      print('❌ Error clearing exports: $e');
      return 0;
    }
  }
}

