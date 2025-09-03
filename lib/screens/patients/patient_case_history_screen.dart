import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../services/firebase/session_service.dart';

class PatientCaseHistoryScreen extends StatefulWidget {
  final String patientId;

  const PatientCaseHistoryScreen({super.key, required this.patientId});

  @override
  State<PatientCaseHistoryScreen> createState() => _PatientCaseHistoryScreenState();
}

class _PatientCaseHistoryScreenState extends State<PatientCaseHistoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Baseline Measurements Controllers
  final _weightController = TextEditingController();
  final _vasScoreController = TextEditingController();
  
  // Wound Assessment Controllers
  final _woundLocationController = TextEditingController();
  final _woundLengthController = TextEditingController();
  final _woundWidthController = TextEditingController();
  final _woundDepthController = TextEditingController();
  final _woundDescriptionController = TextEditingController();
  WoundStage _selectedWoundStage = WoundStage.stage1;
  String _selectedWoundType = 'Pressure Ulcer';
  
  // Wound History Controllers
  final _woundHistoryController = TextEditingController();
  final _woundOccurrenceController = TextEditingController();
  final _previousTreatmentsController = TextEditingController();
  DateTime? _woundStartDate;
  String _selectedWoundOccurrence = 'Chronic condition (diabetes, vascular disease)';

  List<String> _baselinePhotos = [];
  List<String> _woundPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  Patient? _patient;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  void _loadPatientData() async {
    final patientProvider = context.read<PatientProvider>();
    final patient = patientProvider.patients.firstWhere(
      (p) => p.id == widget.patientId,
      orElse: () => throw Exception('Patient not found'),
    );
    
    setState(() {
      _patient = patient;
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _vasScoreController.dispose();
    _woundLocationController.dispose();
    _woundLengthController.dispose();
    _woundWidthController.dispose();
    _woundDepthController.dispose();
    _woundDescriptionController.dispose();
    _woundHistoryController.dispose();
    _woundOccurrenceController.dispose();
    _previousTreatmentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_patient == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildModernHeader(),
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildBaselineMeasurementsPage(),
                _buildWoundAssessmentPage(),
                _buildWoundHistoryPage(),
                _buildConfirmationPage(),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Case History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Patient Case History',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_patient!.fullNames} ${_patient!.surname}',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Collecting baseline data and wound assessment for first session',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentPage;
          final isCompleted = index < _currentPage;
          
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              decoration: BoxDecoration(
                color: isCompleted 
                    ? AppTheme.successColor
                    : isActive 
                        ? AppTheme.primaryColor 
                        : AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBaselineMeasurementsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(
              'Baseline Measurements',
              'Record initial measurements for tracking progress',
              Icons.monitor_weight_outlined,
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Weight (kg) *',
                prefixIcon: Icon(Icons.monitor_weight),
                suffixText: 'kg',
                helperText: 'Patient\'s current weight',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the patient\'s weight';
                }
                final weight = double.tryParse(value);
                if (weight == null || weight <= 0 || weight > 300) {
                  return 'Please enter a valid weight (1-300 kg)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _vasScoreController,
              decoration: const InputDecoration(
                labelText: 'VAS Pain Score (0-10) *',
                prefixIcon: Icon(Icons.healing),
                suffixText: '/10',
                helperText: '0 = No pain, 10 = Worst pain imaginable',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the VAS pain score';
                }
                final score = int.tryParse(value);
                if (score == null || score < 0 || score > 10) {
                  return 'Please enter a score between 0 and 10';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Baseline Photos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take photos for baseline comparison and progress tracking',
              style: TextStyle(color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 16),
            _buildPhotoSection(_baselinePhotos, 'baseline'),
            
            const SizedBox(height: 24),
            _buildInfoCard(
              'Why collect baseline data?',
              'This information establishes the starting point for treatment and allows us to track healing progress over time. The AI will use this data to generate accurate reports and treatment recommendations.',
              Icons.info_outline,
              AppTheme.infoColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWoundAssessmentPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'Wound Assessment',
            'Document wound characteristics and current state',
            Icons.medical_information_outlined,
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _woundLocationController,
            decoration: const InputDecoration(
              labelText: 'Wound Location *',
              prefixIcon: Icon(Icons.location_on),
              helperText: 'Anatomical location of the wound',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the wound location';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedWoundType,
            decoration: const InputDecoration(
              labelText: 'Wound Type *',
              prefixIcon: Icon(Icons.medical_information),
              helperText: 'Classification of wound type',
            ),
            isExpanded: true,
            items: [
              'Pressure Ulcer',
              'Diabetic Foot Ulcer',
              'Venous Leg Ulcer',
              'Arterial Ulcer',
              'Surgical Wound',
              'Traumatic Wound',
              'Burns',
              'Other',
            ].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedWoundType = value!;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a wound type';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          const Text(
            'Wound Measurements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _woundLengthController,
                  decoration: const InputDecoration(
                    labelText: 'Length *',
                    suffixText: 'cm',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final length = double.tryParse(value);
                    if (length == null || length <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _woundWidthController,
                  decoration: const InputDecoration(
                    labelText: 'Width *',
                    suffixText: 'cm',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final width = double.tryParse(value);
                    if (width == null || width <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _woundDepthController,
                  decoration: const InputDecoration(
                    labelText: 'Depth *',
                    suffixText: 'cm',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final depth = double.tryParse(value);
                    if (depth == null || depth <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<WoundStage>(
            value: _selectedWoundStage,
            decoration: const InputDecoration(
              labelText: 'Wound Stage *',
              prefixIcon: Icon(Icons.layers),
              helperText: 'Clinical staging of wound severity',
            ),
            isExpanded: true,
            items: WoundStage.values.map((stage) {
              return DropdownMenuItem(
                value: stage,
                child: Text(stage.description),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedWoundStage = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _woundDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Wound Description *',
              prefixIcon: Icon(Icons.description),
              alignLabelWithHint: true,
              helperText: 'Detailed description of wound appearance',
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a wound description';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Wound Photos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Document the current wound state for progress tracking',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 16),
          _buildPhotoSection(_woundPhotos, 'wound'),
        ],
      ),
    );
  }

  Widget _buildWoundHistoryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'Wound History',
            'Understand the wound\'s origin and progression',
            Icons.history,
          ),
          const SizedBox(height: 24),
          
          const Text(
            'When did the wound first appear?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _woundStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _woundStartDate = date;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Wound Start Date *',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              child: Text(
                _woundStartDate != null
                    ? DateFormat('MMMM dd, yyyy').format(_woundStartDate!)
                    : 'Select date when wound first appeared',
                style: TextStyle(
                  color: _woundStartDate != null ? AppTheme.textColor : AppTheme.secondaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          const Text(
            'How did the wound occur?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedWoundOccurrence,
            decoration: const InputDecoration(
              labelText: 'Wound Cause/Occurrence *',
              prefixIcon: Icon(Icons.help_outline),
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            items: [
              'Chronic condition (diabetes, vascular disease)',
              'Fall (down stairs, from height)',
              'Motor vehicle accident',
              'Sports injury',
              'Work-related accident',
              'Post-surgical complication',
              'Pressure from prolonged bed rest',
              'Other trauma/injury',
              'Unknown/unclear cause',
            ].map((cause) {
              return DropdownMenuItem(
                value: cause,
                child: Text(
                  cause,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedWoundOccurrence = value!;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select how the wound occurred';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _woundOccurrenceController,
            decoration: const InputDecoration(
              labelText: 'Additional details about wound occurrence',
              hintText: 'Provide specific details (e.g., fell down 5 stairs, left ankle twisted)',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            validator: (value) {
              if (_selectedWoundOccurrence.contains('Other') && 
                  (value == null || value.trim().isEmpty)) {
                return 'Please provide details when "Other" is selected';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Wound Progression & Treatment History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _woundHistoryController,
            decoration: const InputDecoration(
              labelText: 'Wound progression and history *',
              hintText: 'How has the wound changed over time? Any improvements or worsening?',
              prefixIcon: Icon(Icons.timeline),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please describe the wound history and progression';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _previousTreatmentsController,
            decoration: const InputDecoration(
              labelText: 'Previous treatments attempted',
              hintText: 'List any previous treatments, dressings, medications, or therapies tried',
              prefixIcon: Icon(Icons.medical_services),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          
          _buildInfoCard(
            'Why is wound history important?',
            'This information helps the AI generate accurate ICD-10 codes for insurance claims and provides context for treatment recommendations. It also reduces repetitive questions in future sessions.',
            Icons.lightbulb_outline,
            AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'Confirm Case History',
            'Review all collected information before saving',
            Icons.check_circle_outline,
          ),
          const SizedBox(height: 24),
          
          _buildSummaryCard(
            'Baseline Measurements',
            [
              'Weight: ${_weightController.text} kg',
              'VAS Pain Score: ${_vasScoreController.text}/10',
              'Baseline Photos: ${_baselinePhotos.length} photos',
            ],
            Icons.monitor_weight_outlined,
            AppTheme.infoColor,
          ),
          const SizedBox(height: 16),
          
          _buildSummaryCard(
            'Wound Assessment',
            [
              'Location: ${_woundLocationController.text}',
              'Type: $_selectedWoundType',
              'Dimensions: ${_woundLengthController.text} × ${_woundWidthController.text} × ${_woundDepthController.text} cm',
              'Stage: ${_selectedWoundStage.description}',
              'Wound Photos: ${_woundPhotos.length} photos',
            ],
            Icons.medical_information_outlined,
            AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          
          _buildSummaryCard(
            'Wound History',
            [
              'Start Date: ${_woundStartDate != null ? DateFormat('MMM dd, yyyy').format(_woundStartDate!) : 'Not set'}',
              'Occurrence: $_selectedWoundOccurrence',
              'History Documented: ${_woundHistoryController.text.isNotEmpty ? 'Yes' : 'No'}',
              'Previous Treatments: ${_previousTreatmentsController.text.isNotEmpty ? 'Yes' : 'No'}',
            ],
            Icons.history,
            AppTheme.successColor,
          ),
          const SizedBox(height: 24),
          
          _buildInfoCard(
            'What happens next?',
            'This information will be saved as Session #1 and used as baseline data for all future treatment sessions. The AI will reference this data for generating reports and tracking progress.',
            Icons.info_outline,
            AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, List<String> items, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(List<String> photos, String type) {
    return Column(
      children: [
        if (photos.isNotEmpty)
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(photos[index]),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: AppTheme.errorColor,
                                size: 40,
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              photos.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.errorColor,
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
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(type, ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(type, ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Previous'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentPage == 3 ? _submitCaseHistory : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(_currentPage == 3 ? 'Complete Case History' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPage < 3) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0: // Baseline Measurements
        if (!_formKey.currentState!.validate()) return false;
        return _weightController.text.isNotEmpty && _vasScoreController.text.isNotEmpty;
      case 1: // Wound Assessment
        return _woundLocationController.text.isNotEmpty &&
               _woundLengthController.text.isNotEmpty &&
               _woundWidthController.text.isNotEmpty &&
               _woundDepthController.text.isNotEmpty &&
               _woundDescriptionController.text.isNotEmpty;
      case 2: // Wound History
        return _woundStartDate != null && _woundHistoryController.text.isNotEmpty;
      case 3: // Confirmation
        return true;
      default:
        return true;
    }
  }

  Future<void> _pickImage(String type, ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          if (type == 'baseline') {
            _baselinePhotos.add(image.path);
          } else {
            _woundPhotos.add(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _submitCaseHistory() async {
    if (!_validateCurrentPage()) {
      return;
    }

    // Show loading dialog immediately

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Creating case history session...'),
            ],
          ),
        ),
      );

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Upload photos to Firebase Storage
      List<String> uploadedBaselinePhotos = [];
      List<String> uploadedWoundPhotos = [];
      
      if (_baselinePhotos.isNotEmpty) {
        uploadedBaselinePhotos = await SessionService.uploadSessionPhotos(
          widget.patientId, 
          sessionId, 
          _baselinePhotos,
        );
      }
      
      if (_woundPhotos.isNotEmpty) {
        uploadedWoundPhotos = await SessionService.uploadSessionPhotos(
          widget.patientId, 
          sessionId, 
          _woundPhotos,
        );
      }
      
      // Create wound object
      final wound = Wound(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        location: _woundLocationController.text,
        type: _selectedWoundType,
        length: double.parse(_woundLengthController.text),
        width: double.parse(_woundWidthController.text),
        depth: double.parse(_woundDepthController.text),
        description: _woundDescriptionController.text,
        photos: uploadedWoundPhotos,
        assessedAt: DateTime.now(),
        stage: _selectedWoundStage,
      );

      // Create case history session with special notes
      final session = Session(
        id: sessionId,
        patientId: widget.patientId,
        sessionNumber: 1, // This is the first session
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: int.parse(_vasScoreController.text),
        wounds: [wound],
        notes: 'PATIENT CASE HISTORY - Baseline data collection\n\n'
               'Wound Start Date: ${_woundStartDate != null ? DateFormat('MMM dd, yyyy').format(_woundStartDate!) : 'Not specified'}\n'
               'Wound Occurrence: $_selectedWoundOccurrence\n'
               '${_woundOccurrenceController.text.isNotEmpty ? 'Details: ${_woundOccurrenceController.text}\n' : ''}'
               'Wound History: ${_woundHistoryController.text}\n'
               '${_previousTreatmentsController.text.isNotEmpty ? 'Previous Treatments: ${_previousTreatmentsController.text}\n' : ''}'
               '\nBaseline photos: ${uploadedBaselinePhotos.length}',
        photos: [...uploadedBaselinePhotos, ...uploadedWoundPhotos],
        practitionerId: '', // Will be set by Firebase service
      );

      // Save the session using SessionService.createSession
      await SessionService.createSession(widget.patientId, session);
      
      // Update patient baseline data
      final updatedPatient = _patient!.copyWith(
        baselineWeight: double.parse(_weightController.text),
        baselineVasScore: int.parse(_vasScoreController.text),
        baselineWounds: [wound],
        baselinePhotos: uploadedBaselinePhotos,
        currentWeight: double.parse(_weightController.text),
        currentVasScore: int.parse(_vasScoreController.text),
        currentWounds: [wound],
        woundStartDate: _woundStartDate,
        woundOccurrence: _selectedWoundOccurrence,
        woundOccurrenceDetails: _woundOccurrenceController.text.isEmpty ? null : _woundOccurrenceController.text,
        woundHistory: _woundHistoryController.text.isEmpty ? null : _woundHistoryController.text,
        previousTreatments: _previousTreatmentsController.text.isEmpty ? null : _previousTreatmentsController.text,
        lastUpdated: DateTime.now(),
      );
      
      // Update patient in provider
      final patientProvider = context.read<PatientProvider>();
      await patientProvider.updatePatient(widget.patientId, updatedPatient);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient Case History completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to patient profile
        context.pop();
      }
    } catch (e) {
      print('Error creating case history: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating case history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
