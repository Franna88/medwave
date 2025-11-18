import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/bulk_export_service.dart';
import '../../providers/patient_provider.dart';
import '../../models/appointment.dart';

class BulkExportDialog extends StatefulWidget {
  final List<Appointment>? appointments;

  const BulkExportDialog({
    super.key,
    this.appointments,
  });

  @override
  State<BulkExportDialog> createState() => _BulkExportDialogState();
}

class _BulkExportDialogState extends State<BulkExportDialog> {
  final BulkExportService _exportService = BulkExportService();
  bool _isExporting = false;
  String _selectedExportType = 'patients';
  bool _useDateFilter = false;
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _performExport() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final patientProvider = context.read<PatientProvider>();

      if (_selectedExportType == 'patients') {
        final file = _useDateFilter && _startDate != null && _endDate != null
            ? await _exportService.exportPatientsWithDateRange(
                patientProvider.patients,
                _startDate!,
                _endDate!,
              )
            : await _exportService.exportPatientsToCSV(patientProvider.patients);

        if (file != null && mounted) {
          Navigator.of(context).pop();
          await _exportService.shareExportedFile(
            file,
            subject: 'MedWave Patients Export',
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Exported ${patientProvider.patients.length} patients'),
                backgroundColor: AppTheme.successColor,
                action: SnackBarAction(
                  label: 'Share Again',
                  textColor: Colors.white,
                  onPressed: () => _exportService.shareExportedFile(file),
                ),
              ),
            );
          }
        }
      } else if (_selectedExportType == 'appointments' && widget.appointments != null) {
        // Create patients map
        final patientsMap = {
          for (var patient in patientProvider.patients) patient.id: patient
        };

        final file = await _exportService.exportAppointmentsToCSV(
          widget.appointments!,
          patientsMap,
        );

        if (file != null && mounted) {
          Navigator.of(context).pop();
          await _exportService.shareExportedFile(
            file,
            subject: 'MedWave Appointments Export',
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Exported ${widget.appointments!.length} appointments'),
                backgroundColor: AppTheme.successColor,
                action: SnackBarAction(
                  label: 'Share Again',
                  textColor: Colors.white,
                  onPressed: () => _exportService.shareExportedFile(file),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.file_download,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Export',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Export data to CSV format',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Export type selection
            const Text(
              'What would you like to export?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),

            const SizedBox(height: 16),

            RadioListTile<String>(
              title: const Text('All Patients'),
              subtitle: const Text('Patient demographics and summary'),
              value: 'patients',
              groupValue: _selectedExportType,
              activeColor: AppTheme.primaryColor,
              onChanged: (value) {
                setState(() {
                  _selectedExportType = value!;
                });
              },
            ),

            if (widget.appointments != null)
              RadioListTile<String>(
                title: const Text('Appointments'),
                subtitle: const Text('Appointment schedule and details'),
                value: 'appointments',
                groupValue: _selectedExportType,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _selectedExportType = value!;
                  });
                },
              ),

            const SizedBox(height: 24),

            // Date filter option
            if (_selectedExportType == 'patients')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: const Text('Filter by date range'),
                    subtitle: const Text('Only export data within a specific period'),
                    value: _useDateFilter,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _useDateFilter = value ?? false;
                      });
                    },
                  ),

                  if (_useDateFilter) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _startDate != null && _endDate != null
                            ? '${DateFormat('MMM d, y').format(_startDate!)} - ${DateFormat('MMM d, y').format(_endDate!)}'
                            : 'Select Date Range',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 32),

            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.infoColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Exported files will be saved as CSV and can be opened in Excel or Google Sheets.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isExporting || (_useDateFilter && (_startDate == null || _endDate == null))
                        ? null
                        : _performExport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Export & Share',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

