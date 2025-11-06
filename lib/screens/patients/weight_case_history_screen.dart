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
import '../../utils/validation_utils.dart';

class WeightCaseHistoryScreen extends StatefulWidget {
  final String patientId;

  const WeightCaseHistoryScreen({super.key, required this.patientId});

  @override
  State<WeightCaseHistoryScreen> createState() => _WeightCaseHistoryScreenState();
}

class _WeightCaseHistoryScreenState extends State<WeightCaseHistoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Baseline Measurements Controllers
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _vasScoreController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  
  // Optional measurements
  final _chestController = TextEditingController();
  final _leftArmController = TextEditingController();
  final _rightArmController = TextEditingController();
  final _leftThighController = TextEditingController();
  final _rightThighController = TextEditingController();
  
  // Goals and notes
  final _goalsController = TextEditingController();
  final _notesController = TextEditingController();

  List<String> _baselinePhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  Patient? _patient;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  void _dismissKeyboard() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }

  void _loadPatientData() async {
    final patientProvider = context.read<PatientProvider>();
    final patient = patientProvider.patients.firstWhere(
      (p) => p.id == widget.patientId,
      orElse: () => throw Exception('Patient not found'),
    );
    
    setState(() {
      _patient = patient;
      // Pre-fill target weight if available
      if (patient.baselineTargetWeight != null) {
        _targetWeightController.text = patient.baselineTargetWeight.toString();
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _targetWeightController.dispose();
    _vasScoreController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _chestController.dispose();
    _leftArmController.dispose();
    _rightArmController.dispose();
    _leftThighController.dispose();
    _rightThighController.dispose();
    _goalsController.dispose();
    _notesController.dispose();
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
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _buildModernHeader(),
            _buildProgressIndicator(),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification) {
                    _dismissKeyboard();
                  }
                  return false;
                },
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildBaselineMeasurementsPage(),
                    _buildBodyMeasurementsPage(),
                    _buildGoalsAndPhotosPage(),
                    _buildConfirmationPage(),
                  ],
                ),
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
                      'Weight Management',
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
                'Weight Case History',
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
                'Collecting baseline data for weight management program',
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
              'Record initial weight and set target goals',
              Icons.monitor_weight_outlined,
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Current Weight (kg) *',
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
              controller: _targetWeightController,
              decoration: const InputDecoration(
                labelText: 'Target Weight (kg) *',
                prefixIcon: Icon(Icons.flag_outlined),
                suffixText: 'kg',
                helperText: 'Patient\'s weight goal',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the target weight';
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
                labelText: 'General Pain/Discomfort Level (0-10) *',
                prefixIcon: Icon(Icons.sentiment_satisfied_alt),
                suffixText: '/10',
                helperText: '0 = No discomfort, 10 = Severe discomfort',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the discomfort level';
                }
                final score = int.tryParse(value);
                if (score == null || score < 0 || score > 10) {
                  return 'Please enter a score between 0 and 10';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            _buildInfoCard(
              'Why collect baseline data?',
              'This information establishes your starting point and helps track progress toward your weight management goals over time.',
              Icons.info_outline,
              AppTheme.infoColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyMeasurementsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'Body Measurements',
            'Record circumference measurements for progress tracking',
            Icons.straighten,
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Required Measurements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _waistController,
            decoration: const InputDecoration(
              labelText: 'Waist Circumference *',
              prefixIcon: Icon(Icons.straighten),
              suffixText: 'cm',
              helperText: 'Measure at belly button level',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter waist measurement';
              }
              final measurement = double.tryParse(value);
              if (measurement == null || measurement <= 0) {
                return 'Please enter a valid measurement';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _hipController,
            decoration: const InputDecoration(
              labelText: 'Hip Circumference *',
              prefixIcon: Icon(Icons.straighten),
              suffixText: 'cm',
              helperText: 'Measure at widest point',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter hip measurement';
              }
              final measurement = double.tryParse(value);
              if (measurement == null || measurement <= 0) {
                return 'Please enter a valid measurement';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Optional Measurements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'These measurements are optional but helpful for comprehensive tracking',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _chestController,
            decoration: const InputDecoration(
              labelText: 'Chest Circumference',
              prefixIcon: Icon(Icons.straighten),
              suffixText: 'cm',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _leftArmController,
                  decoration: const InputDecoration(
                    labelText: 'Left Arm',
                    suffixText: 'cm',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _rightArmController,
                  decoration: const InputDecoration(
                    labelText: 'Right Arm',
                    suffixText: 'cm',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _leftThighController,
                  decoration: const InputDecoration(
                    labelText: 'Left Thigh',
                    suffixText: 'cm',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _rightThighController,
                  decoration: const InputDecoration(
                    labelText: 'Right Thigh',
                    suffixText: 'cm',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsAndPhotosPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'Goals & Photos',
            'Set objectives and document baseline progress',
            Icons.camera_alt_outlined,
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _goalsController,
            decoration: const InputDecoration(
              labelText: 'Weight Management Goals',
              prefixIcon: Icon(Icons.flag_outlined),
              alignLabelWithHint: true,
              helperText: 'What does the patient want to achieve?',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Additional Notes',
              prefixIcon: Icon(Icons.notes),
              alignLabelWithHint: true,
              helperText: 'Any other relevant information',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
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
            'Take full-body photos (front, side, back) for visual progress tracking',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 16),
          _buildPhotoSection(_baselinePhotos),
          const SizedBox(height: 24),
          
          _buildInfoCard(
            'Photo Guidelines',
            'For best results: Stand against a plain background, wear fitted clothing, maintain consistent lighting, and take photos from the same angles in future sessions.',
            Icons.lightbulb_outline,
            AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationPage() {
    final currentWeight = double.tryParse(_weightController.text) ?? 0;
    final targetWeight = double.tryParse(_targetWeightController.text) ?? 0;
    final weightDifference = (currentWeight - targetWeight).abs();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'Confirm Baseline Data',
            'Review all collected information before saving',
            Icons.check_circle_outline,
          ),
          const SizedBox(height: 24),
          
          _buildSummaryCard(
            'Weight Information',
            [
              'Current Weight: ${_weightController.text} kg',
              'Target Weight: ${_targetWeightController.text} kg',
              'Difference: ${weightDifference.toStringAsFixed(1)} kg',
              'Discomfort Level: ${_vasScoreController.text}/10',
            ],
            Icons.monitor_weight_outlined,
            AppTheme.infoColor,
          ),
          const SizedBox(height: 16),
          
          _buildSummaryCard(
            'Body Measurements',
            [
              'Waist: ${_waistController.text} cm',
              'Hip: ${_hipController.text} cm',
              if (_chestController.text.isNotEmpty) 'Chest: ${_chestController.text} cm',
              if (_leftArmController.text.isNotEmpty || _rightArmController.text.isNotEmpty)
                'Arms: ${_leftArmController.text.isNotEmpty ? 'L:${_leftArmController.text}' : ''} ${_rightArmController.text.isNotEmpty ? 'R:${_rightArmController.text}' : ''} cm',
              if (_leftThighController.text.isNotEmpty || _rightThighController.text.isNotEmpty)
                'Thighs: ${_leftThighController.text.isNotEmpty ? 'L:${_leftThighController.text}' : ''} ${_rightThighController.text.isNotEmpty ? 'R:${_rightThighController.text}' : ''} cm',
            ],
            Icons.straighten,
            AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          
          _buildSummaryCard(
            'Documentation',
            [
              'Photos: ${_baselinePhotos.length} photos',
              'Goals: ${_goalsController.text.isNotEmpty ? 'Documented' : 'Not set'}',
              'Notes: ${_notesController.text.isNotEmpty ? 'Added' : 'None'}',
            ],
            Icons.description,
            AppTheme.successColor,
          ),
          const SizedBox(height: 24),
          
          _buildInfoCard(
            'What happens next?',
            'This information will be saved as Session #1 and used as baseline data for tracking weight loss progress. Future sessions will compare measurements against these baseline values.',
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

  Widget _buildPhotoSection(List<String> photos) {
    return Column(
      children: [
        if (photos.isNotEmpty)
          SizedBox(
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
                onPressed: () => _pickImage(ImageSource.camera),
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
                onPressed: () => _pickImage(ImageSource.gallery),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _currentPage == 3 ? 4 : 2,
                shadowColor: AppTheme.primaryColor.withOpacity(0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentPage == 3) ...[
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _currentPage == 3 ? 'Complete Baseline' : 'Next',
                    style: TextStyle(
                      fontSize: _currentPage == 3 ? 16 : 14,
                      fontWeight: _currentPage == 3 ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (_currentPage != 3) ...[
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

  void _nextPage() async {
    List<String> missingFields = _getMissingFieldsForCurrentPage();
    
    if (missingFields.isNotEmpty) {
      await ValidationUtils.showValidationDialog(
        context,
        title: 'Section Incomplete',
        missingFields: missingFields,
        additionalMessage: 'Please complete all required fields before proceeding to the next section.',
      );
      return;
    }
    
    if (_validateCurrentPage()) {
      if (_currentPage < 3) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  List<String> _getMissingFieldsForCurrentPage() {
    List<String> missingFields = [];
    
    switch (_currentPage) {
      case 0: // Baseline Measurements
        if (_weightController.text.trim().isEmpty) {
          missingFields.add('Current Weight');
        }
        if (_targetWeightController.text.trim().isEmpty) {
          missingFields.add('Target Weight');
        }
        if (_vasScoreController.text.trim().isEmpty) {
          missingFields.add('Discomfort Level');
        }
        break;
      case 1: // Body Measurements
        if (_waistController.text.trim().isEmpty) {
          missingFields.add('Waist Circumference');
        }
        if (_hipController.text.trim().isEmpty) {
          missingFields.add('Hip Circumference');
        }
        break;
    }
    
    return missingFields;
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _formKey.currentState!.validate();
      case 1:
        return _waistController.text.isNotEmpty && _hipController.text.isNotEmpty;
      case 2:
      case 3:
        return true;
      default:
        return true;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _baselinePhotos.add(image.path);
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

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Creating baseline session...'),
            ],
          ),
        ),
      );

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Upload photos to Firebase Storage
      List<String> uploadedPhotos = [];
      if (_baselinePhotos.isNotEmpty) {
        uploadedPhotos = await SessionService.uploadSessionPhotos(
          widget.patientId, 
          sessionId, 
          _baselinePhotos,
        );
      }
      
      // Build other measurements map
      final Map<String, double> otherMeasurements = {};
      if (_chestController.text.isNotEmpty) {
        otherMeasurements['chest'] = double.parse(_chestController.text);
      }
      if (_leftArmController.text.isNotEmpty) {
        otherMeasurements['leftArm'] = double.parse(_leftArmController.text);
      }
      if (_rightArmController.text.isNotEmpty) {
        otherMeasurements['rightArm'] = double.parse(_rightArmController.text);
      }
      if (_leftThighController.text.isNotEmpty) {
        otherMeasurements['leftThigh'] = double.parse(_leftThighController.text);
      }
      if (_rightThighController.text.isNotEmpty) {
        otherMeasurements['rightThigh'] = double.parse(_rightThighController.text);
      }

      // Create case history session
      final session = Session(
        id: sessionId,
        patientId: widget.patientId,
        sessionNumber: 1,
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: int.parse(_vasScoreController.text),
        wounds: [], // Empty for weight management patients
        notes: 'WEIGHT CASE HISTORY - Baseline data collection\n\n'
               'Target Weight: ${_targetWeightController.text} kg\n'
               'Waist: ${_waistController.text} cm\n'
               'Hip: ${_hipController.text} cm\n'
               '${_goalsController.text.isNotEmpty ? 'Goals: ${_goalsController.text}\n' : ''}'
               '${_notesController.text.isNotEmpty ? 'Notes: ${_notesController.text}\n' : ''}'
               '\nBaseline photos: ${uploadedPhotos.length}',
        photos: uploadedPhotos,
        practitionerId: '',
        waistMeasurement: double.parse(_waistController.text),
        hipMeasurement: double.parse(_hipController.text),
        otherBodyMeasurements: otherMeasurements.isNotEmpty ? otherMeasurements : null,
      );

      await SessionService.createSession(widget.patientId, session);
      
      // Update patient baseline data
      final updatedPatient = _patient!.copyWith(
        baselineWeight: double.parse(_weightController.text),
        baselineTargetWeight: double.parse(_targetWeightController.text),
        baselineVasScore: int.parse(_vasScoreController.text),
        baselinePhotos: uploadedPhotos,
        currentWeight: double.parse(_weightController.text),
        currentVasScore: int.parse(_vasScoreController.text),
        lastUpdated: DateTime.now(),
      );
      
      final patientProvider = context.read<PatientProvider>();
      await patientProvider.updatePatient(widget.patientId, updatedPatient);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weight baseline completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        context.go('/patients/${widget.patientId}');
      }
    } catch (e) {
      print('Error creating weight case history: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating baseline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

