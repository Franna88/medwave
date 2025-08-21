import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/appointment.dart';
import '../../../models/patient.dart';
import '../../../providers/appointment_provider.dart';
import '../../../theme/app_theme.dart';
import 'patient_selector.dart';

class AddAppointmentDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Function(Appointment) onAppointmentAdded;

  const AddAppointmentDialog({
    super.key,
    required this.selectedDate,
    required this.onAppointmentAdded,
  });

  @override
  State<AddAppointmentDialog> createState() => _AddAppointmentDialogState();
}

class _AddAppointmentDialogState extends State<AddAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _practitionerController = TextEditingController();

  Patient? _selectedPatient;
  String _manualPatientName = '';
  AppointmentType _selectedType = AppointmentType.consultation;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  Duration _duration = const Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _practitionerController.text = 'Dr. Smith'; // Default practitioner
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _practitionerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, color: Colors.white),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Schedule Appointment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Form content
          Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient selection
                      PatientSelector(
                        selectedPatient: _selectedPatient,
                        onPatientSelected: (patient) {
                          setState(() {
                            _selectedPatient = patient;
                            _manualPatientName = '';
                            if (patient != null) {
                              _titleController.text = '${_selectedType.displayName} - ${patient.name}';
                            }
                          });
                        },
                        onManualPatientAdded: (name) {
                          setState(() {
                            _selectedPatient = null;
                            _manualPatientName = name;
                            _titleController.text = '${_selectedType.displayName} - $name';
                          });
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Appointment type
                      const Text(
                        'Type *',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<AppointmentType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.category),
                        ),
                        isExpanded: true,
                        onChanged: (type) {
                          setState(() {
                            _selectedType = type!;
                            if (_selectedPatient != null) {
                              _titleController.text = '${type.displayName} - ${_selectedPatient!.name}';
                            } else if (_manualPatientName.isNotEmpty) {
                              _titleController.text = '${type.displayName} - $_manualPatientName';
                            }
                          });
                        },
                        items: AppointmentType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Title
                      const Text(
                        'Title *',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: 'Enter appointment title',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Date selection
                      const Text(
                        'Date *',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Duration selection
                      const Text(
                        'Duration',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Duration>(
                        value: _duration,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        isExpanded: true,
                        onChanged: (duration) {
                          setState(() {
                            _duration = duration!;
                            _endTime = TimeOfDay.fromDateTime(
                              DateTime(2023, 1, 1, _startTime.hour, _startTime.minute)
                                  .add(_duration),
                            );
                          });
                        },
                        items: const [
                          DropdownMenuItem(
                            value: Duration(minutes: 30),
                            child: Text('30 minutes'),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 1),
                            child: Text('1 hour'),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 1, minutes: 30),
                            child: Text('1.5 hours'),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 2),
                            child: Text('2 hours'),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Start time selection
                      const Text(
                        'Start Time *',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectStartTime,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_startTime.format(context)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // End time display
                      const Text(
                        'End Time',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: BorderRadius.circular(8),
                          color: AppTheme.cardColor,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(_endTime.format(context)),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Location
                      const Text(
                        'Location',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          hintText: 'Room or location',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Practitioner
                      const Text(
                        'Practitioner',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _practitionerController,
                        decoration: const InputDecoration(
                          hintText: 'Practitioner name',
                          prefixIcon: Icon(Icons.medical_services),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Additional notes or description',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      const SizedBox(height: 20),
                      
                      // Conflict check
                      Consumer<AppointmentProvider>(
                        builder: (context, provider, child) {
                          final startDateTime = DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                            _startTime.hour,
                            _startTime.minute,
                          );
                          final endDateTime = startDateTime.add(_duration);
                          
                          final hasConflict = provider.hasConflict(startDateTime, endDateTime);
                          
                          if (hasConflict) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.errorColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: AppTheme.errorColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Time conflict detected with existing appointment',
                                      style: TextStyle(
                                        color: AppTheme.errorColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          return const SizedBox.shrink();
                        },
                      ),
                      
                      // Add bottom padding for floating action button
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
            
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAppointment,
        icon: const Icon(Icons.save),
        label: const Text('Schedule'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    
    if (time != null) {
      setState(() {
        _startTime = time;
        _endTime = TimeOfDay.fromDateTime(
          DateTime(2023, 1, 1, time.hour, time.minute).add(_duration),
        );
      });
    }
  }

  void _saveAppointment() {
    // Validate patient selection
    if (_selectedPatient == null && _manualPatientName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient or enter a patient name'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      
      final endDateTime = startDateTime.add(_duration);
      
      // Check for conflicts
      final provider = context.read<AppointmentProvider>();
      if (provider.hasConflict(startDateTime, endDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Time conflict with existing appointment'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      // Determine patient info
      final patientId = _selectedPatient?.id ?? 'manual_${DateTime.now().millisecondsSinceEpoch}';
      final patientName = _selectedPatient?.name ?? _manualPatientName.trim();
      
      final appointment = Appointment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: patientId,
        patientName: patientName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        type: _selectedType,
        status: AppointmentStatus.scheduled,
        practitionerName: _practitionerController.text.trim().isEmpty 
            ? null 
            : _practitionerController.text.trim(),
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        notes: _selectedPatient == null ? ['Manual patient entry'] : [],
        createdAt: DateTime.now(),
      );
      
      widget.onAppointmentAdded(appointment);
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedPatient == null 
                ? 'Appointment scheduled for $patientName (new patient)'
                : 'Appointment scheduled successfully'
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }
}
