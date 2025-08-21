import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../models/appointment.dart';
import '../../../models/patient.dart';
import '../../../providers/patient_provider.dart';
import '../../../theme/app_theme.dart';

class CompleteAppointmentDialog extends StatefulWidget {
  final Appointment appointment;
  final Function(Appointment, Session?) onCompleted;

  const CompleteAppointmentDialog({
    super.key,
    required this.appointment,
    required this.onCompleted,
  });

  @override
  State<CompleteAppointmentDialog> createState() => _CompleteAppointmentDialogState();
}

class _CompleteAppointmentDialogState extends State<CompleteAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  final _woundDescriptionController = TextEditingController();
  final _woundLengthController = TextEditingController();
  final _woundWidthController = TextEditingController();
  final _woundDepthController = TextEditingController();
  
  int _vasScore = 5;
  List<String> _sessionPhotos = [];
  String _selectedWoundLocation = 'Left ankle';
  WoundStage _selectedWoundStage = WoundStage.stage1;
  bool _hasWoundUpdates = false;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    _woundDescriptionController.dispose();
    _woundLengthController.dispose();
    _woundWidthController.dispose();
    _woundDepthController.dispose();
    super.dispose();
  }

  void _initializeData() {
    final patientProvider = context.read<PatientProvider>();
    final patient = patientProvider.patients.firstWhere(
      (p) => p.id == widget.appointment.patientId,
      orElse: () => Patient(
        id: widget.appointment.patientId,
        surname: widget.appointment.patientName.split(' ').last,
        fullNames: widget.appointment.patientName.split(' ').first,
        idNumber: '0000000000000',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 30)),
        patientCell: '',
        email: '',
        responsiblePersonSurname: widget.appointment.patientName.split(' ').last,
        responsiblePersonFullNames: widget.appointment.patientName.split(' ').first,
        responsiblePersonIdNumber: '0000000000000',
        responsiblePersonDateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 30)),
        responsiblePersonCell: '',
        medicalAidSchemeName: '',
        medicalAidNumber: '',
        mainMemberName: '',
        medicalConditions: {},
        medicalConditionDetails: {},
        isSmoker: false,
        createdAt: DateTime.now(),
        baselineWeight: 70.0,
        baselineVasScore: 8,
        baselineWounds: [],
        baselinePhotos: [],
        currentWounds: [],
        sessions: [],
      ),
    );

    // Initialize with patient's last recorded data
    _weightController.text = (patient.currentWeight ?? patient.baselineWeight).toString();
    _vasScore = patient.currentVasScore ?? patient.baselineVasScore;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.medical_services),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Complete Appointment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.greenColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient and appointment info header
                    _buildHeaderCard(),
                    
                    const SizedBox(height: 24),
                    
                    // Vital signs section
                    _buildVitalSignsCard(),
                    
                    const SizedBox(height: 20),
                    
                    // Wound assessment section
                    _buildWoundAssessmentCard(),
                    
                    const SizedBox(height: 20),
                    
                    // Session photos section
                    _buildPhotosCard(),
                    
                    const SizedBox(height: 20),
                    
                    // Session notes section
                    _buildNotesCard(),
                    
                    const SizedBox(height: 20),
                    
                    // Motivation form button
                    _buildMotivationFormButton(),
                    
                    const SizedBox(height: 100), // Space for floating button
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _completeAppointment,
        icon: const Icon(Icons.check_circle),
        label: const Text('Complete Session'),
        backgroundColor: AppTheme.greenColor,
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.greenColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.greenColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.greenColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.appointment.patientName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                    Text(
                      widget.appointment.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.greenColor, size: 16),
              const SizedBox(width: 6),
              Text(
                DateFormat('EEEE, MMMM d, yyyy \'at\' h:mm a').format(widget.appointment.startTime),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSignsCard() {
    return _buildSectionCard(
      title: 'Vital Signs & Measurements',
      icon: Icons.monitor_heart,
      color: AppTheme.primaryColor,
      children: [
        // Weight input
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weight (kg)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter weight',
                      suffixText: 'kg',
                      prefixIcon: Icon(Icons.scale),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter weight';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // VAS Pain Score
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Pain Level (VAS Score)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPainColor(_vasScore).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_vasScore/10',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getPainColor(_vasScore),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('No Pain', style: TextStyle(fontSize: 12, color: Colors.green)),
                      Text('Worst Pain', style: TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _vasScore.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    activeColor: _getPainColor(_vasScore),
                    onChanged: (value) {
                      setState(() {
                        _vasScore = value.round();
                      });
                    },
                  ),
                  Text(
                    _getPainDescription(_vasScore),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWoundAssessmentCard() {
    return _buildSectionCard(
      title: 'Wound Assessment',
      icon: Icons.healing,
      color: AppTheme.pinkColor,
      children: [
        Row(
          children: [
            const Text(
              'Update wound information',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Switch(
              value: _hasWoundUpdates,
              onChanged: (value) {
                setState(() {
                  _hasWoundUpdates = value;
                });
              },
              activeColor: AppTheme.pinkColor,
            ),
          ],
        ),
        
        if (_hasWoundUpdates) ...[
          const SizedBox(height: 16),
          
          // Wound location
          DropdownButtonFormField<String>(
            value: _selectedWoundLocation,
            decoration: const InputDecoration(
              labelText: 'Wound Location',
              prefixIcon: Icon(Icons.location_on),
            ),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'Left ankle', child: Text('Left ankle')),
              DropdownMenuItem(value: 'Right ankle', child: Text('Right ankle')),
              DropdownMenuItem(value: 'Left knee', child: Text('Left knee')),
              DropdownMenuItem(value: 'Right knee', child: Text('Right knee')),
              DropdownMenuItem(value: 'Left foot', child: Text('Left foot')),
              DropdownMenuItem(value: 'Right foot', child: Text('Right foot')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedWoundLocation = value!;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Wound measurements
          Column(
            children: [
              // Length and Width in one row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _woundLengthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Length',
                        hintText: 'cm',
                        prefixIcon: Icon(Icons.straighten),
                        suffixText: 'cm',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _woundWidthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Width',
                        hintText: 'cm',
                        prefixIcon: Icon(Icons.straighten),
                        suffixText: 'cm',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Depth in separate row for more space
              TextFormField(
                controller: _woundDepthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Depth',
                  hintText: 'Enter wound depth in centimeters',
                  prefixIcon: Icon(Icons.height),
                  suffixText: 'cm',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Wound stage
          DropdownButtonFormField<WoundStage>(
            value: _selectedWoundStage,
            decoration: const InputDecoration(
              labelText: 'Wound Stage',
              prefixIcon: Icon(Icons.medical_information),
            ),
            isExpanded: true,
            items: WoundStage.values.map((stage) => 
              DropdownMenuItem(
                value: stage,
                child: Text(
                  stage.description,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ).toList(),
            onChanged: (value) {
              setState(() {
                _selectedWoundStage = value!;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Wound description
          TextFormField(
            controller: _woundDescriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Wound Description',
              hintText: 'Describe wound appearance, drainage, healing progress, surrounding tissue condition...',
              prefixIcon: Icon(Icons.description),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotosCard() {
    return _buildSectionCard(
      title: 'Session Photos',
      icon: Icons.camera_alt,
      color: Colors.orange,
      children: [
        if (_sessionPhotos.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_a_photo,
                  size: 48,
                  color: Colors.orange.withOpacity(0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add photos to document treatment progress',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _sessionPhotos.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.cardColor,
                    ),
                    child: const Center(
                      child: Icon(Icons.image, size: 40),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return _buildSectionCard(
      title: 'Session Notes',
      icon: Icons.notes,
      color: AppTheme.secondaryColor,
      children: [
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter treatment notes, observations, patient response, next steps...',
            prefixIcon: Icon(Icons.edit_note),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter session notes';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMotivationFormButton() {
    return _buildSectionCard(
      title: 'Documentation',
      icon: Icons.description_outlined,
      color: AppTheme.infoColor,
      children: [
        const Text(
          'Generate a comprehensive motivation form based on this session data and patient progress.',
          style: TextStyle(color: AppTheme.secondaryColor),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _generateMotivationForm,
            icon: const Icon(Icons.description_outlined),
            label: const Text(
              'Generate Motivation Form',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppTheme.infoColor, width: 2),
              foregroundColor: AppTheme.infoColor,
            ),
          ),
        ),
      ],
    );
  }

  Color _getPainColor(int score) {
    if (score <= 3) return Colors.green;
    if (score <= 6) return Colors.orange;
    return Colors.red;
  }

  String _getPainDescription(int score) {
    if (score == 0) return 'No pain';
    if (score <= 3) return 'Mild pain';
    if (score <= 6) return 'Moderate pain';
    if (score <= 8) return 'Severe pain';
    return 'Worst possible pain';
  }

  void _generateMotivationForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: AppTheme.infoColor),
            SizedBox(width: 12),
            Text('Generate Motivation Form'),
          ],
        ),
        content: Text(
          'Generate a comprehensive motivation form for ${widget.appointment.patientName}?\n\nThe form will include session data, wound assessment, treatment progress, and medical justification for continued care.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showMotivationFormGenerated();
            },
            icon: const Icon(Icons.file_download),
            label: const Text('Generate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.infoColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showMotivationFormGenerated() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Motivation form for ${widget.appointment.patientName} generated successfully!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // In a real app, this would open the generated PDF
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening motivation form...'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _sessionPhotos.add(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding photo: $e'),
          backgroundColor: AppTheme.redColor,
        ),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _sessionPhotos.removeAt(index);
    });
  }

  Future<void> _completeAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create session data
      final session = Session(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: widget.appointment.patientId,
        sessionNumber: 1, // This would be calculated based on patient's session history
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: _vasScore,
        wounds: _hasWoundUpdates ? _buildUpdatedWounds() : [],
        notes: _notesController.text.trim(),
        photos: _sessionPhotos,
        practitionerId: 'current_practitioner_id',
      );

      // Update appointment status
      final completedAppointment = widget.appointment.copyWith(
        status: AppointmentStatus.completed,
        lastUpdated: DateTime.now(),
      );

      // Call the completion callback
      widget.onCompleted(completedAppointment, session);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment completed and patient data updated successfully'),
          backgroundColor: AppTheme.greenColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing appointment: $e'),
          backgroundColor: AppTheme.redColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Wound> _buildUpdatedWounds() {
    if (!_hasWoundUpdates) return [];

    final length = double.tryParse(_woundLengthController.text) ?? 0;
    final width = double.tryParse(_woundWidthController.text) ?? 0;
    final depth = double.tryParse(_woundDepthController.text) ?? 0;

    return [
      Wound(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        location: _selectedWoundLocation,
        type: 'Treatment update',
        length: length,
        width: width,
        depth: depth,
        description: _woundDescriptionController.text.trim(),
        photos: _sessionPhotos,
        assessedAt: DateTime.now(),
        stage: _selectedWoundStage,
      ),
    ];
  }
}
