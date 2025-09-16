import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../services/firebase/session_service.dart';
import '../../widgets/wound_assessment_widget.dart';

class MultiWoundCaseHistoryScreen extends StatefulWidget {
  final String patientId;

  const MultiWoundCaseHistoryScreen({super.key, required this.patientId});

  @override
  State<MultiWoundCaseHistoryScreen> createState() => _MultiWoundCaseHistoryScreenState();
}

class _MultiWoundCaseHistoryScreenState extends State<MultiWoundCaseHistoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Baseline Measurements Controllers
  final _weightController = TextEditingController();
  final _vasScoreController = TextEditingController();
  
  // Wound History Controllers
  final _woundHistoryController = TextEditingController();
  final _woundOccurrenceController = TextEditingController();
  final _previousTreatmentsController = TextEditingController();
  DateTime? _woundStartDate;
  String _selectedWoundOccurrence = 'Chronic condition (diabetes, vascular disease)';

  // Multi-wound specific
  int _woundCount = 2;
  List<WoundAssessmentData> _woundsData = [];
  int _expandedWoundIndex = 0;
  List<String> _baselinePhotos = [];
  
  final ImagePicker _imagePicker = ImagePicker();
  Patient? _patient;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _initializeWounds();
  }

  // Enhanced keyboard dismissal for iOS compatibility
  void _dismissKeyboard() {
    // Method 1: Unfocus current focus
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.focusedChild!.unfocus();
    }
    
    // Method 2: Unfocus the entire scope
    FocusScope.of(context).unfocus();
    
    // Method 3: iOS-specific keyboard dismissal
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    
    // Method 4: Force keyboard dismissal with delay for iOS
    Future.delayed(const Duration(milliseconds: 100), () {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    });
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

  void _initializeWounds() {
    _woundsData = List.generate(_woundCount, (index) {
      return WoundAssessmentData(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_$index',
        location: '',
        type: 'Pressure Ulcer',
        length: 0.0,
        width: 0.0,
        depth: 0.0,
        description: '',
        stage: WoundStage.stage1,
        photos: [],
      );
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _vasScoreController.dispose();
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

    return GestureDetector(
      onTap: _dismissKeyboard,
      onPanDown: (_) => _dismissKeyboard(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        resizeToAvoidBottomInset: true,
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
                _buildWoundCountPage(),
                _buildWoundAssessmentsPage(),
                _buildWoundHistoryPage(),
                _buildConfirmationPage(),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
        ),
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
                      'Multi-Wound Case History',
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
              const Text(
                'Multiple Wound Assessment',
                style: TextStyle(
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
                'Comprehensive assessment for multiple wounds',
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
        children: List.generate(5, (index) {
          final isActive = index <= _currentPage;
          final isCompleted = index < _currentPage;
          
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
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
          ],
        ),
      ),
    );
  }

  Widget _buildWoundCountPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'Wound Count',
            'Specify the number of wounds to assess',
            Icons.format_list_numbered,
          ),
          const SizedBox(height: 24),
          
          const Text(
            'How many wounds does this patient have?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.infoColor),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select the total number of wounds',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.infoColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Each wound will be assessed individually with its own measurements, photos, and tracking. You can assess between 2-8 wounds.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.infoColor.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Wound count selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _woundCount > 2 ? () {
                  setState(() {
                    _woundCount--;
                    _initializeWounds();
                  });
                } : null,
                icon: const Icon(Icons.remove_circle),
                iconSize: 40,
                color: _woundCount > 2 ? AppTheme.primaryColor : AppTheme.borderColor,
              ),
              const SizedBox(width: 24),
              Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_woundCount',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      _woundCount == 1 ? 'Wound' : 'Wounds',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: _woundCount < 8 ? () {
                  setState(() {
                    _woundCount++;
                    _initializeWounds();
                  });
                } : null,
                icon: const Icon(Icons.add_circle),
                iconSize: 40,
                color: _woundCount < 8 ? AppTheme.primaryColor : AppTheme.borderColor,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Wound count options
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(7, (index) {
              final count = index + 2; // Start from 2
              final isSelected = count == _woundCount;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _woundCount = count;
                    _initializeWounds();
                  });
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.3)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWoundAssessmentsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'Wound Assessments',
            'Document each wound individually',
            Icons.medical_information_outlined,
          ),
          const SizedBox(height: 24),
          
          Text(
            'Assess $_woundCount Wounds',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Expand each wound card to complete the assessment. All wounds must be assessed to continue.',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 24),
          
          // Wound assessment widgets
          ...List.generate(_woundCount, (index) {
            return WoundAssessmentWidget(
              key: ValueKey(_woundsData[index].id),
              woundIndex: index,
              woundId: _woundsData[index].id,
              initialData: _woundsData[index],
              isExpanded: _expandedWoundIndex == index,
              onToggleExpanded: () {
                setState(() {
                  _expandedWoundIndex = _expandedWoundIndex == index ? -1 : index;
                });
              },
              onWoundDataChanged: (data) {
                setState(() {
                  _woundsData[index] = data;
                });
              },
            );
          }),
          
          const SizedBox(height: 24),
          _buildWoundAssessmentSummary(),
        ],
      ),
    );
  }

  Widget _buildWoundAssessmentSummary() {
    final completedWounds = _woundsData.where((w) => w.isValid).length;
    final allComplete = completedWounds == _woundCount;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: allComplete 
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allComplete 
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.warningColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            allComplete ? Icons.check_circle : Icons.info_outline,
            color: allComplete ? AppTheme.successColor : AppTheme.warningColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allComplete 
                      ? 'All Wounds Assessed'
                      : 'Assessment Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: allComplete ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allComplete
                      ? 'All $_woundCount wounds have been successfully assessed'
                      : '$completedWounds of $_woundCount wounds completed',
                  style: TextStyle(
                    fontSize: 14,
                    color: (allComplete ? AppTheme.successColor : AppTheme.warningColor)
                        .withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
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
            'Shared history for all wounds',
            Icons.history,
          ),
          const SizedBox(height: 24),
          
          const Text(
            'When did these wounds first appear?',
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
                    : 'Select date when wounds first appeared',
                style: TextStyle(
                  color: _woundStartDate != null ? AppTheme.textColor : AppTheme.secondaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          const Text(
            'How did these wounds occur?',
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
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _woundOccurrenceController,
            decoration: const InputDecoration(
              labelText: 'Additional details about wound occurrence',
              hintText: 'Provide specific details about how the wounds occurred',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
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
              hintText: 'How have the wounds changed over time? Any improvements or worsening?',
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
            'Confirm Multi-Wound Case History',
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
            'Wound Assessments',
            [
              'Total Wounds: $_woundCount',
              'Completed Assessments: ${_woundsData.where((w) => w.isValid).length}',
              'Total Wound Photos: ${_woundsData.fold<int>(0, (sum, w) => sum + w.photos.length)}',
              'Assessment Status: ${_woundsData.every((w) => w.isValid) ? 'Complete' : 'Incomplete'}',
            ],
            Icons.medical_information_outlined,
            AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          
          // Individual wound summaries
          ...List.generate(_woundCount, (index) {
            final wound = _woundsData[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: _buildSummaryCard(
                'Wound ${index + 1}: ${wound.location.isEmpty ? 'Not specified' : wound.location}',
                [
                  'Type: ${wound.type}',
                  'Dimensions: ${wound.length} × ${wound.width} × ${wound.depth} cm',
                  'Stage: ${wound.stage.description}',
                  'Photos: ${wound.photos.length} photos',
                  'Status: ${wound.isValid ? 'Complete' : 'Incomplete'}',
                ],
                Icons.healing,
                wound.isValid ? AppTheme.successColor : AppTheme.warningColor,
              ),
            );
          }),
          
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
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
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
              onPressed: _currentPage == 4 ? _submitMultiWoundCaseHistory : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentPage == 4 ? AppTheme.primaryColor : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _currentPage == 4 ? 4 : 2,
                shadowColor: AppTheme.primaryColor.withOpacity(0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentPage == 4) ...[
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _currentPage == 4 ? 'Complete Case History' : 'Next',
                    style: TextStyle(
                      fontSize: _currentPage == 4 ? 16 : 14,
                      fontWeight: _currentPage == 4 ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (_currentPage != 4) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPage < 4) {
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
      case 1: // Wound Count
        return _woundCount >= 2 && _woundCount <= 8;
      case 2: // Wound Assessments
        return _woundsData.every((wound) => wound.isValid);
      case 3: // Wound History
        return _woundStartDate != null && _woundHistoryController.text.isNotEmpty;
      case 4: // Confirmation
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
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _submitMultiWoundCaseHistory() async {
    if (!_validateCurrentPage()) {
      return;
    }

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
              Text('Creating multi-wound case history...'),
            ],
          ),
        ),
      );

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Upload baseline photos
      List<String> uploadedBaselinePhotos = [];
      if (_baselinePhotos.isNotEmpty) {
        uploadedBaselinePhotos = await SessionService.uploadSessionPhotos(
          widget.patientId, 
          sessionId, 
          _baselinePhotos,
        );
      }
      
      // Create wound objects and upload their photos
      List<Wound> wounds = [];
      List<String> allWoundPhotos = [];
      
      for (int i = 0; i < _woundsData.length; i++) {
        final woundData = _woundsData[i];
        
        // Upload wound photos
        List<String> uploadedWoundPhotos = [];
        if (woundData.photos.isNotEmpty) {
          uploadedWoundPhotos = await SessionService.uploadSessionPhotos(
            widget.patientId, 
            sessionId, 
            woundData.photos,
          );
        }
        
        // Create wound object
        final wound = Wound(
          id: woundData.id,
          location: woundData.location,
          type: woundData.type,
          length: woundData.length,
          width: woundData.width,
          depth: woundData.depth,
          description: woundData.description,
          photos: uploadedWoundPhotos,
          assessedAt: DateTime.now(),
          stage: woundData.stage,
        );
        
        wounds.add(wound);
        allWoundPhotos.addAll(uploadedWoundPhotos);
      }

      // Create case history session with special notes for multi-wound
      final session = Session(
        id: sessionId,
        patientId: widget.patientId,
        sessionNumber: 1, // This is the first session
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: int.parse(_vasScoreController.text),
        wounds: wounds,
        notes: 'MULTI-WOUND CASE HISTORY - Baseline data collection\n\n'
               'Total Wounds: $_woundCount\n'
               'Wound Start Date: ${_woundStartDate != null ? DateFormat('MMM dd, yyyy').format(_woundStartDate!) : 'Not specified'}\n'
               'Wound Occurrence: $_selectedWoundOccurrence\n'
               '${_woundOccurrenceController.text.isNotEmpty ? 'Details: ${_woundOccurrenceController.text}\n' : ''}'
               'Wound History: ${_woundHistoryController.text}\n'
               '${_previousTreatmentsController.text.isNotEmpty ? 'Previous Treatments: ${_previousTreatmentsController.text}\n' : ''}'
               '\nBaseline photos: ${uploadedBaselinePhotos.length}\n'
               'Total wound photos: ${allWoundPhotos.length}',
        photos: [...uploadedBaselinePhotos, ...allWoundPhotos],
        practitionerId: '', // Will be set by Firebase service
      );

      // Save the session using SessionService.createSession
      await SessionService.createSession(widget.patientId, session);
      
      // Update patient baseline data
      final updatedPatient = _patient!.copyWith(
        baselineWeight: double.parse(_weightController.text),
        baselineVasScore: int.parse(_vasScoreController.text),
        baselineWounds: wounds,
        baselinePhotos: uploadedBaselinePhotos,
        currentWeight: double.parse(_weightController.text),
        currentVasScore: int.parse(_vasScoreController.text),
        currentWounds: wounds,
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
          SnackBar(
            content: Text('Multi-wound case history completed! $_woundCount wounds assessed successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to patient profile (go back 2 levels: case-history -> wound-selection -> patient-profile)
        context.go('/patients/${widget.patientId}');
      }
    } catch (e) {
      print('Error creating multi-wound case history: $e');
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
