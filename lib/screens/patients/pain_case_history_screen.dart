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

class PainCaseHistoryScreen extends StatefulWidget {
  final String patientId;

  const PainCaseHistoryScreen({super.key, required this.patientId});

  @override
  State<PainCaseHistoryScreen> createState() => _PainCaseHistoryScreenState();
}

class _PainCaseHistoryScreenState extends State<PainCaseHistoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Baseline Measurements Controllers
  final _weightController = TextEditingController();
  final _vasScoreController = TextEditingController();
  final _functionalScoreController = TextEditingController();
  final _painDescriptionController = TextEditingController();
  final _goalsController = TextEditingController();
  final _notesController = TextEditingController();

  // Pain locations
  final List<String> _availablePainLocations = [
    'Head/Neck',
    'Upper Back',
    'Lower Back',
    'Left Shoulder',
    'Right Shoulder',
    'Left Elbow',
    'Right Elbow',
    'Left Wrist/Hand',
    'Right Wrist/Hand',
    'Chest',
    'Abdomen',
    'Left Hip',
    'Right Hip',
    'Left Knee',
    'Right Knee',
    'Left Ankle/Foot',
    'Right Ankle/Foot',
    'Other',
  ];
  
  final List<String> _selectedPainLocations = [];

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
      // Pre-fill pain locations if available
      if (patient.painLocations != null && patient.painLocations!.isNotEmpty) {
        _selectedPainLocations.addAll(patient.painLocations!);
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _vasScoreController.dispose();
    _functionalScoreController.dispose();
    _painDescriptionController.dispose();
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
                    _buildPainAssessmentPage(),
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
                      'Pain Management',
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
                'Pain Case History',
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
                'Collecting baseline data for pain management program',
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
              'Record initial weight and pain levels',
              Icons.monitor_heart_outlined,
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
                prefixIcon: Icon(Icons.sentiment_dissatisfied),
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
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _functionalScoreController,
              decoration: const InputDecoration(
                labelText: 'Functional Assessment (0-10) *',
                prefixIcon: Icon(Icons.accessibility_new),
                suffixText: '/10',
                helperText: '0 = Completely limited, 10 = Fully functional',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the functional assessment score';
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
              'About Functional Assessment',
              'This score measures how pain affects daily activities like walking, working, sleeping, and self-care. A lower score indicates significant functional limitations.',
              Icons.info_outline,
              AppTheme.infoColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPainAssessmentPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'Pain Assessment',
            'Identify pain locations and characteristics',
            Icons.person_pin_circle_outlined,
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Pain Locations *',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select all areas where the patient experiences pain',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          
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
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _painDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Pain Description *',
              prefixIcon: Icon(Icons.description),
              alignLabelWithHint: true,
              helperText: 'Describe the pain: sharp, dull, burning, aching, tingling, etc.',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please describe the pain';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          _buildInfoCard(
            'Pain Characteristics',
            'Include details about when pain occurs (morning, evening, after activity), what makes it better or worse, and any patterns you\'ve noticed.',
            Icons.lightbulb_outline,
            AppTheme.warningColor,
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
            'Set treatment objectives and document affected areas',
            Icons.camera_alt_outlined,
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _goalsController,
            decoration: const InputDecoration(
              labelText: 'Treatment Goals',
              prefixIcon: Icon(Icons.flag_outlined),
              alignLabelWithHint: true,
              helperText: 'What outcomes does the patient want to achieve?',
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
            'Baseline Photos (Optional)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take photos of affected areas or posture if relevant',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 16),
          _buildPhotoSection(_baselinePhotos),
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
            'Confirm Baseline Data',
            'Review all collected information before saving',
            Icons.check_circle_outline,
          ),
          const SizedBox(height: 24),
          
          _buildSummaryCard(
            'Baseline Measurements',
            [
              'Weight: ${_weightController.text} kg',
              'VAS Pain Score: ${_vasScoreController.text}/10',
              'Functional Score: ${_functionalScoreController.text}/10',
            ],
            Icons.monitor_heart_outlined,
            AppTheme.infoColor,
          ),
          const SizedBox(height: 16),
          
          _buildSummaryCard(
            'Pain Assessment',
            [
              'Pain Locations: ${_selectedPainLocations.join(', ')}',
              'Description: ${_painDescriptionController.text.length > 50 ? '${_painDescriptionController.text.substring(0, 50)}...' : _painDescriptionController.text}',
            ],
            Icons.person_pin_circle_outlined,
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
            'This information will be saved as Session #1 and used as baseline data for tracking pain management progress. Future sessions will assess changes in pain levels and functionality.',
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
          missingFields.add('Weight');
        }
        if (_vasScoreController.text.trim().isEmpty) {
          missingFields.add('VAS Pain Score');
        }
        if (_functionalScoreController.text.trim().isEmpty) {
          missingFields.add('Functional Assessment Score');
        }
        break;
      case 1: // Pain Assessment
        if (_selectedPainLocations.isEmpty) {
          missingFields.add('Pain Locations (select at least one)');
        }
        if (_painDescriptionController.text.trim().isEmpty) {
          missingFields.add('Pain Description');
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
        return _selectedPainLocations.isNotEmpty && _painDescriptionController.text.isNotEmpty;
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

      // Create case history session
      final session = Session(
        id: sessionId,
        patientId: widget.patientId,
        sessionNumber: 1,
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: int.parse(_vasScoreController.text),
        wounds: [], // Empty for pain management patients
        notes: 'PAIN CASE HISTORY - Baseline data collection\n\n'
               'Functional Assessment Score: ${_functionalScoreController.text}/10\n'
               'Pain Locations: ${_selectedPainLocations.join(', ')}\n'
               'Pain Description: ${_painDescriptionController.text}\n'
               '${_goalsController.text.isNotEmpty ? 'Goals: ${_goalsController.text}\n' : ''}'
               '${_notesController.text.isNotEmpty ? 'Notes: ${_notesController.text}\n' : ''}'
               '\nBaseline photos: ${uploadedPhotos.length}',
        photos: uploadedPhotos,
        practitionerId: '',
        painLocations: _selectedPainLocations,
        painDescription: _painDescriptionController.text,
        functionalAssessmentScore: int.parse(_functionalScoreController.text),
      );

      await SessionService.createSession(widget.patientId, session);
      
      // Update patient baseline data
      final updatedPatient = _patient!.copyWith(
        baselineWeight: double.parse(_weightController.text),
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
            content: Text('Pain baseline completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        context.go('/patients/${widget.patientId}');
      }
    } catch (e) {
      print('Error creating pain case history: $e');
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

