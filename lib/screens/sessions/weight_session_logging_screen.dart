import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../services/firebase/session_service.dart';
import '../../services/firebase/patient_service.dart';

class WeightSessionLoggingScreen extends StatefulWidget {
  final String patientId;

  const WeightSessionLoggingScreen({super.key, required this.patientId});

  @override
  State<WeightSessionLoggingScreen> createState() => _WeightSessionLoggingScreenState();
}

class _WeightSessionLoggingScreenState extends State<WeightSessionLoggingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _vasScoreController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Weight Management specific measurements
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  final Map<String, TextEditingController> _otherMeasurementControllers = {};
  
  List<String> _sessionPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  Patient? _patient;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  void _loadPatientData() {
    final patientProvider = context.read<PatientProvider>();
    _patient = patientProvider.patients.firstWhere(
      (p) => p.id == widget.patientId,
      orElse: () => throw Exception('Patient not found'),
    );

    // Clear all form fields for fresh data entry
    _weightController.clear();
    _vasScoreController.clear();
    _notesController.clear();
    _waistController.clear();
    _hipController.clear();
    _sessionPhotos.clear();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _vasScoreController.dispose();
    _notesController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    for (var controller in _otherMeasurementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _sessionPhotos.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _sessionPhotos.removeAt(index);
    });
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient data not loaded')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload photos
      List<String> uploadedPhotoUrls = [];
      if (_sessionPhotos.isNotEmpty) {
        uploadedPhotoUrls = await PatientService.uploadPatientPhotos(
          widget.patientId,
          _sessionPhotos,
          'session',
        );
      }

      // Build other measurements map
      final Map<String, double> otherMeasurements = {};
      for (var entry in _otherMeasurementControllers.entries) {
        final value = double.tryParse(entry.value.text);
        if (value != null) {
          otherMeasurements[entry.key] = value;
        }
      }

      final session = Session(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: widget.patientId,
        sessionNumber: _patient!.sessions.length + 1,
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: int.parse(_vasScoreController.text),
        wounds: [], // Empty for weight management patients
        notes: _notesController.text,
        photos: uploadedPhotoUrls,
        practitionerId: '', // Will be set by service
        // Weight management specific fields
        waistMeasurement: _waistController.text.isNotEmpty 
            ? double.tryParse(_waistController.text) 
            : null,
        hipMeasurement: _hipController.text.isNotEmpty 
            ? double.tryParse(_hipController.text) 
            : null,
        otherBodyMeasurements: otherMeasurements.isNotEmpty ? otherMeasurements : null,
      );

      await SessionService.createSession(widget.patientId, session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight session saved successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving session: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Weight Session'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _patient == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Patient: ${_patient!.fullNames} ${_patient!.surname}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Weight Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weight Measurement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: 'Current Weight (kg) *',
                              prefixIcon: Icon(Icons.monitor_weight),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Weight is required';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Invalid weight';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Body Measurements Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Body Measurements',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _waistController,
                            decoration: const InputDecoration(
                              labelText: 'Waist (cm)',
                              prefixIcon: Icon(Icons.straighten),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _hipController,
                            decoration: const InputDecoration(
                              labelText: 'Hips (cm)',
                              prefixIcon: Icon(Icons.straighten),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wellbeing Score Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'General Wellbeing',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _vasScoreController,
                            decoration: const InputDecoration(
                              labelText: 'Wellbeing Score (0-10) *',
                              prefixIcon: Icon(Icons.sentiment_satisfied),
                              helperText: '0 = Poor, 10 = Excellent',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Score is required';
                              }
                              final score = int.tryParse(value);
                              if (score == null || score < 0 || score > 10) {
                                return 'Score must be between 0-10';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Progress Notes Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Progress Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Session Notes',
                              prefixIcon: Icon(Icons.note),
                              hintText: 'Dietary changes, exercise, challenges, achievements...',
                            ),
                            maxLines: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Photo Capture Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Progress Photos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Take Photo'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_sessionPhotos.isEmpty)
                            const Text(
                              'No photos added yet',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _sessionPhotos.asMap().entries.map((entry) {
                                return Stack(
                                  children: [
                                    Image.file(
                                      File(entry.value),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () => _removePhoto(entry.key),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSession,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Session',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

