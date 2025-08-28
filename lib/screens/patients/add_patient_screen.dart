import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../utils/localization.dart';
import '../../utils/id_validation.dart';
import '../../widgets/signature_pad.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  Language _currentLanguage = Language.english;

  // Basic Patient Details Controllers
  final _surnameController = TextEditingController();
  final _fullNamesController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _patientCellController = TextEditingController();
  final _emailController = TextEditingController();
  
  DateTime? _dateOfBirth;
  String? _maritalStatus;

  // Person Responsible Controllers (simplified - using patient details if same person)
  final _responsibleSurnameController = TextEditingController();
  final _responsibleFullNamesController = TextEditingController();
  final _responsibleIdNumberController = TextEditingController();
  final _responsibleCellController = TextEditingController();
  DateTime? _responsibleDateOfBirth;

  // Medical Aid Controllers
  final _medicalAidSchemeController = TextEditingController();
  final _medicalAidNumberController = TextEditingController();
  final _mainMemberNameController = TextEditingController();

  // Medical History Controllers (simplified)
  final Map<String, bool> _medicalConditions = {
    'heart': false,
    'lungs': false,
    'diabetes': false,
    'cancer': false,
    'hiv': false,
  };
  final _currentMedicationsController = TextEditingController();
  final _allergiesController = TextEditingController();
  bool _isSmoker = false;

  // Baseline Measurements
  final _weightController = TextEditingController();
  final _vasScoreController = TextEditingController();
  
  // Wound Information
  final _woundLocationController = TextEditingController();
  final _woundLengthController = TextEditingController();
  final _woundWidthController = TextEditingController();
  final _woundDepthController = TextEditingController();
  final _woundDescriptionController = TextEditingController();
  WoundStage _selectedWoundStage = WoundStage.stage1;
  String _selectedWoundType = 'Pressure Ulcer';
  
  // Enhanced Wound History (NEW - for AI report generation)
  final _woundHistoryController = TextEditingController();
  final _woundOccurrenceController = TextEditingController();
  final _previousTreatmentsController = TextEditingController();
  final _referringDoctorController = TextEditingController();
  final _referringDoctorContactController = TextEditingController();
  DateTime? _woundStartDate;
  String _selectedWoundOccurrence = 'Chronic condition';
  final Map<String, String> _detailedMedicalConditions = {};

  List<String> _baselinePhotos = [];
  List<String> _woundPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  // Signature pads
  final GlobalKey _accountSignatureKey = GlobalKey();
  final GlobalKey _woundConsentSignatureKey = GlobalKey();
  final GlobalKey _witnessSignatureKey = GlobalKey();
  
  bool? _trainingPhotosConsent;

  @override
  void initState() {
    super.initState();
    AppLocalizations.setLanguage(_currentLanguage);
  }

  @override
  void dispose() {
    _surnameController.dispose();
    _fullNamesController.dispose();
    _idNumberController.dispose();
    _patientCellController.dispose();
    _emailController.dispose();
    _responsibleSurnameController.dispose();
    _responsibleFullNamesController.dispose();
    _responsibleIdNumberController.dispose();
    _responsibleCellController.dispose();
    _medicalAidSchemeController.dispose();
    _medicalAidNumberController.dispose();
    _mainMemberNameController.dispose();
    _currentMedicationsController.dispose();
    _allergiesController.dispose();
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
    _referringDoctorController.dispose();
    _referringDoctorContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.get('patient_intake_form')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Language toggle
          PopupMenuButton<Language>(
            icon: const Icon(Icons.language),
            onSelected: (Language language) {
              setState(() {
                _currentLanguage = language;
                AppLocalizations.setLanguage(language);
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: Language.english,
                child: Text('English'),
              ),
              const PopupMenuItem(
                value: Language.afrikaans,
                child: Text('Afrikaans'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
                _buildPatientDetailsPage(),
                _buildResponsiblePersonPage(),
                _buildMedicalAidPage(),
                _buildMedicalHistoryPage(),
                _buildBaselineMeasurementsPage(),
                _buildWoundDetailsPage(),
                _buildWoundHistoryPage(),
                _buildConsentPage(),
                _buildConfirmationPage(),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(9, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 7 ? 8 : 0),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPatientDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.get('patient_details'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _surnameController,
              decoration: InputDecoration(
                labelText: '${AppLocalizations.get('surname')} *',
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '${AppLocalizations.get('surname')} ${AppLocalizations.get('required')}';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _fullNamesController,
              decoration: InputDecoration(
                labelText: '${AppLocalizations.get('full_names')} *',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '${AppLocalizations.get('full_names')} ${AppLocalizations.get('required')}';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _idNumberController,
              decoration: InputDecoration(
                labelText: '${AppLocalizations.get('id_number')} *',
                prefixIcon: const Icon(Icons.badge),
                helperText: '13 digits',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              onChanged: (value) {
                if (value.length == 13) {
                  final dob = SouthAfricanIdValidator.getDateOfBirth(value);
                  if (dob != null) {
                    setState(() {
                      _dateOfBirth = dob;
                    });
                  }
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '${AppLocalizations.get('id_number')} ${AppLocalizations.get('required')}';
                }
                if (!SouthAfricanIdValidator.isValidSAId(value)) {
                  return 'Invalid South African ID number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Date of Birth (auto-populated from ID)
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _dateOfBirth = date;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppTheme.secondaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dateOfBirth != null
                            ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!)
                            : '${AppLocalizations.get('date_of_birth')} *',
                        style: TextStyle(
                          color: _dateOfBirth != null ? AppTheme.textColor : AppTheme.secondaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _patientCellController,
              decoration: InputDecoration(
                labelText: '${AppLocalizations.get('patient_cell')} *',
                prefixIcon: const Icon(Icons.phone_android),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '${AppLocalizations.get('patient_cell')} ${AppLocalizations.get('required')}';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: '${AppLocalizations.get('email')} *',
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '${AppLocalizations.get('email')} ${AppLocalizations.get('required')}';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Invalid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _maritalStatus,
              decoration: InputDecoration(
                labelText: AppLocalizations.get('marital_status'),
                prefixIcon: const Icon(Icons.favorite),
              ),
              items: [
                'single',
                'married',
                'divorced',
                'widowed',
                'other',
              ].map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(AppLocalizations.get(status)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _maritalStatus = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiblePersonPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.get('person_responsible'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // Copy from patient details button
          ElevatedButton.icon(
            onPressed: _copyPatientDetailsToResponsible,
            icon: const Icon(Icons.copy),
            label: const Text('Copy Patient Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _responsibleSurnameController,
            decoration: InputDecoration(
              labelText: '${AppLocalizations.get('surname')} *',
              prefixIcon: const Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _responsibleFullNamesController,
            decoration: InputDecoration(
              labelText: '${AppLocalizations.get('full_names')} *',
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _responsibleIdNumberController,
            decoration: InputDecoration(
              labelText: '${AppLocalizations.get('id_number')} *',
              prefixIcon: const Icon(Icons.badge),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
            ],
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _responsibleCellController,
            decoration: InputDecoration(
              labelText: '${AppLocalizations.get('patient_cell')} *',
              prefixIcon: const Icon(Icons.phone_android),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalAidPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.get('medical_aid_details'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _medicalAidSchemeController,
            decoration: InputDecoration(
              labelText: '${AppLocalizations.get('name_of_scheme')} *',
              prefixIcon: const Icon(Icons.medical_services),
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _medicalAidNumberController,
            decoration: InputDecoration(
              labelText: '${AppLocalizations.get('medical_aid_no')} *',
              prefixIcon: const Icon(Icons.credit_card),
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _mainMemberNameController,
            decoration: InputDecoration(
              labelText: '${AppLocalizations.get('name_of_main_member')} *',
              prefixIcon: const Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 32),
          
          // Referring Doctor Section
          const Text(
            'Referring Doctor/Specialist',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _referringDoctorController,
            decoration: const InputDecoration(
              labelText: 'Referring Doctor Name',
              prefixIcon: Icon(Icons.local_hospital),
              hintText: 'Dr. Smith',
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _referringDoctorContactController,
            decoration: const InputDecoration(
              labelText: 'Doctor Contact Number',
              prefixIcon: Icon(Icons.phone),
              hintText: '011 123 4567',
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalHistoryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.get('medical_history'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            AppLocalizations.get('treated_for_illness'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          // Medical conditions checkboxes
          ..._medicalConditions.keys.map((condition) => _buildMedicalConditionTile(condition)),
          
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _currentMedicationsController,
            decoration: InputDecoration(
              labelText: AppLocalizations.get('current_medications'),
              prefixIcon: const Icon(Icons.medication),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _allergiesController,
            decoration: InputDecoration(
              labelText: AppLocalizations.get('allergies'),
              prefixIcon: const Icon(Icons.warning),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          
          // Smoker question
          Row(
            children: [
              const Icon(Icons.smoking_rooms, color: AppTheme.secondaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.get('smoker'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: Text(AppLocalizations.get('yes')),
                  value: true,
                  groupValue: _isSmoker,
                  onChanged: (value) {
                    setState(() {
                      _isSmoker = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: Text(AppLocalizations.get('no')),
                  value: false,
                  groupValue: _isSmoker,
                  onChanged: (value) {
                    setState(() {
                      _isSmoker = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalConditionTile(String condition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.get(condition),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(AppLocalizations.get('yes')),
                  Radio<bool>(
                    value: true,
                    groupValue: _medicalConditions[condition],
                    onChanged: (value) {
                      setState(() {
                        _medicalConditions[condition] = value!;
                      });
                    },
                  ),
                  Text(AppLocalizations.get('no')),
                  Radio<bool>(
                    value: false,
                    groupValue: _medicalConditions[condition],
                    onChanged: (value) {
                      setState(() {
                        _medicalConditions[condition] = value!;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          // Enhanced: Add detailed description field for ICD-10 coding
          if (_medicalConditions[condition] == true) ...[
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Please provide details about ${AppLocalizations.get(condition).toLowerCase()}',
                hintText: 'e.g., Type 1/2 diabetes, specific cardiac condition, etc.',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (value) {
                _detailedMedicalConditions[condition] = value;
              },
              validator: _medicalConditions[condition] == true
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide details for ICD-10 coding';
                      }
                      return null;
                    }
                  : null,
            ),
          ],
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
          const Text(
            'Wound History & Occurrence',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This information is crucial for accurate ICD-10 coding and insurance claims',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 24),
          
          // When did the wound start?
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
                    ? '${_woundStartDate!.day}/${_woundStartDate!.month}/${_woundStartDate!.year}'
                    : 'Select date when wound first appeared',
                style: TextStyle(
                  color: _woundStartDate != null ? AppTheme.textColor : AppTheme.secondaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // How did the wound occur?
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
          
          // Wound history and progression
          const Text(
            'Wound History & Previous Treatments',
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
              labelText: 'Wound progression and history',
              hintText: 'How has the wound changed over time? Any improvements or worsening?',
              prefixIcon: Icon(Icons.history),
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
          
          // Information note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This information will be used to generate accurate ICD-10 codes and reduce repetitive questions during AI report generation.',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.get('consent_signatures'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // Account Responsibility Disclaimer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Responsibility Disclaimer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.get('account_responsibility_disclaimer'),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SignaturePad(
                  key: _accountSignatureKey,
                  label: AppLocalizations.get('signature'),
                  width: double.infinity,
                  height: 120,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Wound Photography Consent
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wound Photography Consent',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.get('wound_photography_consent'),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SignaturePad(
                        key: _woundConsentSignatureKey,
                        label: 'Patient ${AppLocalizations.get('signature')}',
                        height: 100,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SignaturePad(
                        key: _witnessSignatureKey,
                        label: 'Witness ${AppLocalizations.get('signature')}',
                        height: 100,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Training Photos Consent
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Training Photos Consent',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.get('training_photos_consent'),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    RadioListTile<bool>(
                      title: Text(AppLocalizations.get('give_permission')),
                      value: true,
                      groupValue: _trainingPhotosConsent,
                      onChanged: (value) {
                        setState(() {
                          _trainingPhotosConsent = value;
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      title: Text(AppLocalizations.get('do_not_give_permission')),
                      value: false,
                      groupValue: _trainingPhotosConsent,
                      onChanged: (value) {
                        setState(() {
                          _trainingPhotosConsent = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaselineMeasurementsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Baseline Measurements',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Record initial measurements for tracking progress',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              prefixIcon: Icon(Icons.monitor_weight),
              suffixText: 'kg',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the patient\'s weight';
              }
              final weight = double.tryParse(value);
              if (weight == null || weight <= 0 || weight > 300) {
                return 'Please enter a valid weight';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vasScoreController,
            decoration: const InputDecoration(
              labelText: 'VAS Pain Score (0-10)',
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
            'Take photos for baseline comparison',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 16),
          _buildPhotoSection(_baselinePhotos, 'baseline'),
        ],
      ),
    );
  }

  Widget _buildWoundDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wound Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Document wound characteristics and photos',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _woundLocationController,
            decoration: const InputDecoration(
              labelText: 'Wound Location',
              prefixIcon: Icon(Icons.location_on),
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
              labelText: 'Wound Type',
              prefixIcon: Icon(Icons.medical_information),
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
                child: Text(
                  type,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _woundLengthController,
                  decoration: const InputDecoration(
                    labelText: 'Length (cm)',
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
                    labelText: 'Width (cm)',
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
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _woundDepthController,
            decoration: const InputDecoration(
              labelText: 'Depth (cm)',
              suffixText: 'cm',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the wound depth';
              }
              final depth = double.tryParse(value);
              if (depth == null || depth <= 0) {
                return 'Please enter a valid depth';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<WoundStage>(
            value: _selectedWoundStage,
            decoration: const InputDecoration(
              labelText: 'Wound Stage',
              prefixIcon: Icon(Icons.layers),
            ),
            isExpanded: true,
            items: WoundStage.values.map((stage) {
              return DropdownMenuItem(
                value: stage,
                child: Text(
                  stage.description,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
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
              labelText: 'Description',
              prefixIcon: Icon(Icons.description),
              alignLabelWithHint: true,
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
            'Document the wound for progress tracking',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 16),
          _buildPhotoSection(_woundPhotos, 'wound'),
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
          const Text(
            'Confirm Patient Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review all information before adding the patient',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(
            AppLocalizations.get('patient_details'),
            [
              '${AppLocalizations.get('full_names')}: ${_fullNamesController.text} ${_surnameController.text}',
              '${AppLocalizations.get('id_number')}: ${_idNumberController.text}',
              '${AppLocalizations.get('email')}: ${_emailController.text}',
              '${AppLocalizations.get('patient_cell')}: ${_patientCellController.text}',
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            AppLocalizations.get('medical_aid_details'),
            [
              '${AppLocalizations.get('name_of_scheme')}: ${_medicalAidSchemeController.text}',
              '${AppLocalizations.get('medical_aid_no')}: ${_medicalAidNumberController.text}',
              '${AppLocalizations.get('name_of_main_member')}: ${_mainMemberNameController.text}',
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            'Baseline Measurements',
            [
              'Weight: ${_weightController.text} kg',
              'VAS Pain Score: ${_vasScoreController.text}/10',
              'Baseline Photos: ${_baselinePhotos.length}',
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            'Wound Details',
            [
              'Location: ${_woundLocationController.text}',
              'Type: $_selectedWoundType',
              'Dimensions: ${_woundLengthController.text} × ${_woundWidthController.text} × ${_woundDepthController.text} cm',
              'Stage: ${_selectedWoundStage.description}',
              'Wound Photos: ${_woundPhotos.length}',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, List<String> items) {
    IconData getIconForTitle(String title) {
      switch (title) {
        case 'Basic Information':
          return Icons.person_outline;
        case 'Baseline Measurements':
          return Icons.monitor_weight_outlined;
        case 'Wound Details':
          return Icons.medical_information_outlined;
        default:
          return Icons.info_outline;
      }
    }
    
    Color getColorForTitle(String title) {
      switch (title) {
        case 'Basic Information':
          return AppTheme.infoColor;
        case 'Baseline Measurements':
          return AppTheme.warningColor;
        case 'Wound Details':
          return AppTheme.primaryColor;
        default:
          return AppTheme.secondaryColor;
      }
    }

    final cardColor = getColorForTitle(title);
    final cardIcon = getIconForTitle(title);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.1),
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
                    color: cardColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    cardIcon,
                    color: cardColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cardColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final parts = item.split(': ');
                final label = parts.isNotEmpty ? parts[0] : '';
                final value = parts.length > 1 ? parts.sublist(1).join(': ') : item;
                
                return Container(
                  margin: EdgeInsets.only(bottom: index < items.length - 1 ? 16 : 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cardColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (parts.length > 1) ...[
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                value,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.secondaryColor.withOpacity(0.8),
                                ),
                              ),
                            ] else ...[
                              Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.image,
                          color: AppTheme.secondaryColor.withOpacity(0.5),
                          size: 40,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              photos.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(type, ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(type, ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
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
                child: const Text('Previous'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentPage == 8 ? _submitForm : _nextPage,
              child: Text(_currentPage == 8 ? AppLocalizations.get('submit') : AppLocalizations.get('next')),
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPage < 8) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0: // Patient Details
        return _formKey.currentState!.validate() && _dateOfBirth != null;
      case 1: // Responsible Person
        return _responsibleSurnameController.text.isNotEmpty &&
               _responsibleFullNamesController.text.isNotEmpty &&
               _responsibleIdNumberController.text.isNotEmpty &&
               _responsibleCellController.text.isNotEmpty;
      case 2: // Medical Aid
        return _medicalAidSchemeController.text.isNotEmpty &&
               _medicalAidNumberController.text.isNotEmpty &&
               _mainMemberNameController.text.isNotEmpty;
      case 6: // Consent
        return (_accountSignatureKey.currentWidget as SignaturePad?) != null &&
               (_woundConsentSignatureKey.currentWidget as SignaturePad?) != null &&
               _trainingPhotosConsent != null;
      default:
        return true;
    }
  }

  void _copyPatientDetailsToResponsible() {
    setState(() {
      _responsibleSurnameController.text = _surnameController.text;
      _responsibleFullNamesController.text = _fullNamesController.text;
      _responsibleIdNumberController.text = _idNumberController.text;
      _responsibleDateOfBirth = _dateOfBirth;
      _responsibleCellController.text = _patientCellController.text;
    });
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

  Future<void> _submitForm() async {
    if (!_validateCurrentPage()) {
      return;
    }

    final patientProvider = context.read<PatientProvider>();
    final now = DateTime.now();

    // Create wound
    final wound = Wound(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: _woundLocationController.text,
      type: _selectedWoundType,
      length: double.parse(_woundLengthController.text),
      width: double.parse(_woundWidthController.text),
      depth: double.parse(_woundDepthController.text),
      description: _woundDescriptionController.text,
      photos: _woundPhotos,
      assessedAt: now,
      stage: _selectedWoundStage,
    );

    // Get signature bytes (simplified - storing as placeholder strings)
    final accountSignature = 'signature_account_${DateTime.now().millisecondsSinceEpoch}';
    final woundConsentSignature = 'signature_wound_${DateTime.now().millisecondsSinceEpoch}';
    final witnessSignature = 'signature_witness_${DateTime.now().millisecondsSinceEpoch}';

    // Create medical condition details map
    final medicalConditionDetails = <String, String?>{};
    for (String condition in _medicalConditions.keys) {
      if (_medicalConditions[condition] == true) {
        medicalConditionDetails[condition] = _detailedMedicalConditions[condition]; // Use detailed descriptions
      }
    }

    // Create patient
    final patient = Patient(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      surname: _surnameController.text,
      fullNames: _fullNamesController.text,
      idNumber: _idNumberController.text,
      dateOfBirth: _dateOfBirth!,
      patientCell: _patientCellController.text,
      email: _emailController.text,
      maritalStatus: _maritalStatus,
      
      // Responsible person
      responsiblePersonSurname: _responsibleSurnameController.text,
      responsiblePersonFullNames: _responsibleFullNamesController.text,
      responsiblePersonIdNumber: _responsibleIdNumberController.text,
      responsiblePersonDateOfBirth: _responsibleDateOfBirth ?? _dateOfBirth!,
      responsiblePersonCell: _responsibleCellController.text,
      
      // Medical Aid
      medicalAidSchemeName: _medicalAidSchemeController.text,
      medicalAidNumber: _medicalAidNumberController.text,
      mainMemberName: _mainMemberNameController.text,
      
      // Referring Doctor
      referringDoctorName: _referringDoctorController.text.isEmpty ? null : _referringDoctorController.text,
      referringDoctorCell: _referringDoctorContactController.text.isEmpty ? null : _referringDoctorContactController.text,
      
      // Medical History
      medicalConditions: _medicalConditions,
      medicalConditionDetails: medicalConditionDetails,
      currentMedications: _currentMedicationsController.text.isEmpty ? null : _currentMedicationsController.text,
      allergies: _allergiesController.text.isEmpty ? null : _allergiesController.text,
      isSmoker: _isSmoker,
      
      // Enhanced Wound History
      woundStartDate: _woundStartDate,
      woundOccurrence: _selectedWoundOccurrence,
      woundOccurrenceDetails: _woundOccurrenceController.text.isEmpty ? null : _woundOccurrenceController.text,
      woundHistory: _woundHistoryController.text.isEmpty ? null : _woundHistoryController.text,
      previousTreatments: _previousTreatmentsController.text.isEmpty ? null : _previousTreatmentsController.text,
      
      // Signatures and consent
      accountResponsibilitySignature: accountSignature,
      accountResponsibilitySignatureDate: now,
      woundPhotographyConsentSignature: woundConsentSignature,
      witnessSignature: witnessSignature,
      woundPhotographyConsentDate: now,
      trainingPhotosConsent: _trainingPhotosConsent,
      trainingPhotosConsentDate: _trainingPhotosConsent != null ? now : null,
      
      createdAt: now,
      practitionerId: '', // Will be set by the Firebase service
      baselineWeight: double.parse(_weightController.text),
      baselineVasScore: int.parse(_vasScoreController.text),
      baselineWounds: [wound],
      baselinePhotos: _baselinePhotos,
      currentWeight: double.parse(_weightController.text),
      currentVasScore: int.parse(_vasScoreController.text),
      currentWounds: [wound],
      sessions: [],
    );

    try {
      await patientProvider.addPatient(patient);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient added successfully!')),
        );
        context.go('/patients');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding patient: $e')),
        );
      }
    }
  }
}
