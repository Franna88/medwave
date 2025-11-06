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

class PainSessionLoggingScreen extends StatefulWidget {
  final String patientId;

  const PainSessionLoggingScreen({super.key, required this.patientId});

  @override
  State<PainSessionLoggingScreen> createState() => _PainSessionLoggingScreenState();
}

class _PainSessionLoggingScreenState extends State<PainSessionLoggingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _vasScoreController = TextEditingController();
  final _notesController = TextEditingController();
  final _painDescriptionController = TextEditingController();
  
  // Pain Management specific fields
  List<String> _selectedPainLocations = [];
  int _functionalAssessmentScore = 5;
  
  List<String> _sessionPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  Patient? _patient;
  bool _isLoading = false;

  final List<String> _availablePainLocations = [
    'Head/Neck', 'Shoulders', 'Upper Back', 'Lower Back', 'Chest',
    'Arms', 'Hands', 'Hips', 'Legs', 'Knees', 'Feet', 'Abdomen'
  ];

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
    _painDescriptionController.clear();
    _selectedPainLocations.clear();
    _sessionPhotos.clear();
    _functionalAssessmentScore = 5;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _vasScoreController.dispose();
    _notesController.dispose();
    _painDescriptionController.dispose();
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

      final session = Session(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: widget.patientId,
        sessionNumber: _patient!.sessions.length + 1,
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: int.parse(_vasScoreController.text),
        wounds: [], // Empty for pain management patients
        notes: _notesController.text,
        photos: uploadedPhotoUrls,
        practitionerId: '', // Will be set by service
        // Pain management specific fields
        painLocations: _selectedPainLocations.isNotEmpty ? _selectedPainLocations : null,
        painDescription: _painDescriptionController.text.isNotEmpty 
            ? _painDescriptionController.text 
            : null,
        functionalAssessmentScore: _functionalAssessmentScore,
      );

      await SessionService.createSession(widget.patientId, session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pain session saved successfully')),
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
        title: const Text('Log Pain Session'),
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

                  // Pain Score Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pain Assessment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _vasScoreController,
                            decoration: const InputDecoration(
                              labelText: 'Current Pain Score (0-10) *',
                              prefixIcon: Icon(Icons.sentiment_dissatisfied),
                              helperText: '0 = No pain, 10 = Worst pain',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Pain score is required';
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

                  // Pain Locations Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pain Location(s)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availablePainLocations.map((location) {
                              final isSelected = _selectedPainLocations.contains(location);
                              return FilterChip(
                                label: Text(location),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedPainLocations.add(location);
                                    } else {
                                      _selectedPainLocations.remove(location);
                                    }
                                  });
                                },
                                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                                checkmarkColor: AppTheme.primaryColor,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pain Description Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pain Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _painDescriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Describe the Pain',
                              prefixIcon: Icon(Icons.description),
                              hintText: 'Sharp, dull, burning, throbbing, shooting...',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Functional Assessment Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Functional Assessment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mobility & Activity Level',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('0', style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: Slider(
                                  value: _functionalAssessmentScore.toDouble(),
                                  min: 0,
                                  max: 10,
                                  divisions: 10,
                                  label: _functionalAssessmentScore.toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      _functionalAssessmentScore = value.toInt();
                                    });
                                  },
                                ),
                              ),
                              const Text('10', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          Text(
                            'Current: $_functionalAssessmentScore/10 (0 = Unable to move, 10 = Full mobility)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Weight Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weight',
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

                  // Treatment Notes Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Treatment Notes',
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
                              hintText: 'Treatments applied, medications, progress, concerns...',
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
                                'Session Photos',
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

