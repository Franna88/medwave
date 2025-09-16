import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../utils/localization.dart';
import '../../utils/id_validation.dart';
import '../../widgets/signature_pad.dart';
import '../../widgets/pmb_chip_selector.dart';
import '../../services/firebase/patient_service.dart';
import '../../services/storage_test_service.dart';

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

  // Referring Doctor (moved from wound section)
  final _referringDoctorController = TextEditingController();
  final _referringDoctorContactController = TextEditingController();
  
  // Enhanced Medical History Details (for AI report generation)
  final Map<String, String> _detailedMedicalConditions = {};
  
  // PMB Conditions
  List<String> _selectedPMBConditions = [];

  // Signature pads
  final GlobalKey _accountSignatureKey = GlobalKey();
  final GlobalKey _woundConsentSignatureKey = GlobalKey();
  final GlobalKey _witnessSignatureKey = GlobalKey();
  
  // Store captured signature bytes
  Uint8List? _accountSignatureBytes;
  Uint8List? _woundConsentSignatureBytes;
  Uint8List? _witnessSignatureBytes;
  
  bool? _trainingPhotosConsent;

  @override
  void initState() {
    super.initState();
    AppLocalizations.setLanguage(_currentLanguage);
  }
  

  /// Test photo URL accessibility
  Future<void> _testPhotoUrls() async {
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final patients = patientProvider.patients;
      
      for (final patient in patients.take(2)) { // Test first 2 patients
        print('🔍 Testing photos for patient: ${patient.surname}');
        final sessions = await patientProvider.getPatientSessions(patient.id);
        
        for (final session in sessions) {
          print('📋 Session ${session.sessionNumber} has ${session.photos.length} photos');
          for (int i = 0; i < session.photos.length; i++) {
            final photoUrl = session.photos[i];
            print('🔗 Testing URL: $photoUrl');
            
            // Try to make a simple HTTP request to test accessibility
            try {
              final response = await http.head(Uri.parse(photoUrl));
              print('✅ URL accessible: ${response.statusCode}');
            } catch (e) {
              print('❌ URL failed: $e');
            }
          }
        }
      }
    } catch (e) {
      print('❌ Photo URL test failed: $e');
    }
  }

  /// Run storage connectivity test for debugging
  Future<void> _runStorageTest() async {
    print('🚀 Starting Firebase Storage connectivity test...');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Testing Storage...'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Running diagnostics...'),
          ],
        ),
      ),
    );

    try {
      final results = await StorageTestService.runStorageConnectivityTest();
      StorageTestService.printTestResults(results);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show results dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Storage Test Results'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Authentication: ${results['authentication']?['status'] ?? 'UNKNOWN'}'),
                  Text('Bucket Config: ${results['bucket_config']?['status'] ?? 'UNKNOWN'}'),
                  Text('Read Permission: ${results['read_permission']?['status'] ?? 'UNKNOWN'}'),
                  Text('Write Permission: ${results['write_permission']?['status'] ?? 'UNKNOWN'}'),
                  const SizedBox(height: 8),
                  const Text('Check console for detailed results.', 
                            style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Storage test failed: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          // Photo URL test button (for debugging)
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _testPhotoUrls,
            tooltip: 'Test Photo URLs',
          ),
          // Storage test button (for debugging)
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _runStorageTest,
            tooltip: 'Test Storage Connectivity',
          ),
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
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside of text fields
          FocusScope.of(context).unfocus();
        },
        child: Column(
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
                  _buildConsentPage(),
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

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(6, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 5 ? 8 : 0),
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '${AppLocalizations.get('marital_status')} ${AppLocalizations.get('required')}';
                }
                return null;
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
          
          const SizedBox(height: 32),
          
          // PMB Conditions Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: PMBChipSelector(
              selectedConditionIds: _selectedPMBConditions,
              onSelectionChanged: (selectedIds) {
                setState(() {
                  _selectedPMBConditions = selectedIds;
                });
              },
            ),
          ),
          
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
                  onSignatureChanged: (bytes) {
                    setState(() {
                      _accountSignatureBytes = bytes;
                    });
                  },
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
                        onSignatureChanged: (bytes) {
                          setState(() {
                            _woundConsentSignatureBytes = bytes;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SignaturePad(
                        key: _witnessSignatureKey,
                        label: 'Witness ${AppLocalizations.get('signature')}',
                        height: 100,
                        onSignatureChanged: (bytes) {
                          setState(() {
                            _witnessSignatureBytes = bytes;
                          });
                        },
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
            'Registration Summary',
            [
              'Registration completed successfully',
              'Patient Case History will be collected at first visit',
              'All consent forms signed',
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
              onPressed: _currentPage == 5 ? _submitForm : _nextPage,
              child: Text(_currentPage == 5 ? AppLocalizations.get('submit') : AppLocalizations.get('next')),
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPage < 5) {
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
      case 3: // Medical History
        return true; // No specific validation for medical history
      case 4: // Consent
        final hasAccountSig = _accountSignatureBytes != null;
        final hasWoundSig = _woundConsentSignatureBytes != null;
        final hasTrainingConsent = _trainingPhotosConsent != null;
        
        print('🔍 VALIDATION DEBUG: Account signature: $hasAccountSig (${_accountSignatureBytes?.length ?? 0} bytes)');
        print('🔍 VALIDATION DEBUG: Wound consent signature: $hasWoundSig (${_woundConsentSignatureBytes?.length ?? 0} bytes)');
        print('🔍 VALIDATION DEBUG: Training consent selected: $hasTrainingConsent ($_trainingPhotosConsent)');
        
        final isValid = hasAccountSig && hasWoundSig && hasTrainingConsent;
        print('🔍 VALIDATION DEBUG: Page 4 (Consent) valid: $isValid');
        
        return isValid;
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



  Future<void> _submitForm() async {
    print('🚀 SUBMIT DEBUG: _submitForm() started');
    
    if (!_validateCurrentPage()) {
      print('❌ SUBMIT DEBUG: Validation failed, exiting');
      return;
    }

    print('✅ SUBMIT DEBUG: Validation passed, proceeding');
    final patientProvider = context.read<PatientProvider>();
    final now = DateTime.now();

    try {
      print('🎬 SUBMIT DEBUG: Showing loading dialog...');
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
              Text('Creating patient profile...'),
            ],
          ),
        ),
      );
      print('✅ SUBMIT DEBUG: Loading dialog shown successfully');

      // Note: Wound data will be collected during Patient Case History (first session)

      // Use stored signature bytes
      print('🖋️ FORM DEBUG: Using stored signatures...');
      final accountSignatureBytes = _accountSignatureBytes;
      final woundConsentSignatureBytes = _woundConsentSignatureBytes;
      final witnessSignatureBytes = _witnessSignatureBytes;

      print('🖋️ FORM DEBUG: Account signature: ${accountSignatureBytes?.length ?? 0} bytes');
      print('🖋️ FORM DEBUG: Wound consent signature: ${woundConsentSignatureBytes?.length ?? 0} bytes');
      print('🖋️ FORM DEBUG: Witness signature: ${witnessSignatureBytes?.length ?? 0} bytes');

      // Create temporary patient ID for signature upload
      final tempPatientId = DateTime.now().millisecondsSinceEpoch.toString();

      // Prepare signature bytes for upload
      final signatureBytes = <String, Uint8List>{};
      if (accountSignatureBytes != null) {
        signatureBytes['account'] = accountSignatureBytes;
      }
      if (woundConsentSignatureBytes != null) {
        signatureBytes['wound_consent'] = woundConsentSignatureBytes;
      }
      if (witnessSignatureBytes != null) {
        signatureBytes['witness'] = witnessSignatureBytes;
      }

      // Upload signatures to Firebase Storage
      String? accountSignatureUrl;
      String? woundConsentSignatureUrl;
      String? witnessSignatureUrl;

      print('📝 SUBMIT DEBUG: Preparing signature upload for patient ID: $tempPatientId');
      print('📊 SUBMIT DEBUG: Signature count to upload: ${signatureBytes.length}');
      
      if (signatureBytes.isNotEmpty) {
        print('🖋️ FORM DEBUG: Uploading signatures...');
        final uploadResults = await PatientService.uploadSignatureBytes(tempPatientId, signatureBytes);
        
        accountSignatureUrl = uploadResults['account'];
        woundConsentSignatureUrl = uploadResults['wound_consent'];
        witnessSignatureUrl = uploadResults['witness'];
        
        print('✅ FORM DEBUG: Signatures uploaded successfully');
        print('📋 SUBMIT DEBUG: Signature URLs received: ${uploadResults.keys.toList()}');
      } else {
        print('⚠️ FORM DEBUG: No signatures to upload');
      }

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
      
      // PMB Conditions
      pmbConditionIds: _selectedPMBConditions,
      
      // Enhanced Wound History (will be collected in Patient Case History)
      woundStartDate: null,
      woundOccurrence: null,
      woundOccurrenceDetails: null,
      woundHistory: null,
      previousTreatments: null,
      
      // Signatures and consent
      accountResponsibilitySignature: accountSignatureUrl,
      accountResponsibilitySignatureDate: now,
      woundPhotographyConsentSignature: woundConsentSignatureUrl,
      witnessSignature: witnessSignatureUrl,
      woundPhotographyConsentDate: now,
      trainingPhotosConsent: _trainingPhotosConsent,
      trainingPhotosConsentDate: _trainingPhotosConsent != null ? now : null,
      
      createdAt: now,
      practitionerId: '', // Will be set by the Firebase service
      baselineWeight: 0.0, // Will be set during Patient Case History
      baselineVasScore: 0, // Will be set during Patient Case History
      baselineWounds: [], // Will be populated during Patient Case History
      baselinePhotos: [], // Will be populated during Patient Case History
      currentWeight: null, // Will be set during Patient Case History
      currentVasScore: null, // Will be set during Patient Case History
      currentWounds: [], // Will be populated during Patient Case History
      sessions: [],
    );

      print('🏥 FORM DEBUG: Creating patient record...');
      print('🔄 SUBMIT DEBUG: Calling patientProvider.addPatient()...');
      
      await patientProvider.addPatient(patient);
      
      print('✅ FORM DEBUG: Patient created successfully');
      print('✅ SUBMIT DEBUG: patientProvider.addPatient() completed');
      
      if (mounted) {
        print('📱 FORM DEBUG: Dismissing loading dialog and navigating...');
        print('🎭 SUBMIT DEBUG: Component is still mounted, proceeding with dialog dismissal');
        
        // Ensure we close the loading dialog first
        print('🔚 SUBMIT DEBUG: About to call Navigator.pop() to close loading dialog');
        
        // Try to close the loading dialog using rootNavigator to ensure it's dismissed
        try {
          Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog using root navigator
          print('✅ FORM DEBUG: Loading dialog dismissed using rootNavigator');
        } catch (e) {
          print('⚠️ SUBMIT DEBUG: Root navigator pop failed, trying regular navigator');
          Navigator.of(context).pop(); // Fallback to regular navigator
          print('✅ FORM DEBUG: Loading dialog dismissed using regular navigator');
        }
        
        print('✅ SUBMIT DEBUG: Navigator.pop() completed');
        
        // Add a small delay to ensure dialog is fully dismissed
        print('⏰ SUBMIT DEBUG: Waiting 200ms for dialog dismissal...');
        await Future.delayed(const Duration(milliseconds: 200));
        print('✅ SUBMIT DEBUG: Delay completed');
        
        if (mounted) {
          print('🎭 SUBMIT DEBUG: Component still mounted after delay, continuing');
          
          // Reset loading state immediately
          print('🔄 SUBMIT DEBUG: Resetting patient provider loading state...');
          patientProvider.resetLoadingState();
          print('✅ SUBMIT DEBUG: Loading state reset completed');
          
        print('🎪 SUBMIT DEBUG: About to navigate with success message...');
        
        // Force close any remaining dialogs before navigation
        print('🔚 SUBMIT DEBUG: Force dismissing any remaining dialogs before navigation...');
        while (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        
        // Small delay to ensure all dialogs are fully closed
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Navigate immediately with a success parameter that the patients screen can detect
        print('🧭 SUBMIT DEBUG: About to navigate to /patients immediately');
        context.go('/patients?success=patient_created');
        print('✅ SUBMIT DEBUG: Navigation completed successfully');
        } else {
          print('❌ SUBMIT DEBUG: Component not mounted after delay, skipping further steps');
        }
      } else {
        print('❌ SUBMIT DEBUG: Component not mounted after patient creation, skipping dialog dismissal');
      }
    } catch (e) {
      print('❌ FORM DEBUG: Error creating patient: $e');
      print('💥 SUBMIT DEBUG: Exception caught: ${e.toString()}');
      print('📍 SUBMIT DEBUG: Stack trace: ${StackTrace.current}');
      
      if (mounted) {
        print('🎭 SUBMIT DEBUG: Component mounted during error handling');
        // Ensure loading dialog is closed
        print('🔚 SUBMIT DEBUG: About to close loading dialog in error handler');
        Navigator.of(context).pop(); // Close loading dialog
        print('✅ SUBMIT DEBUG: Loading dialog closed in error handler');
        
        // Reset loading state
        print('🔄 SUBMIT DEBUG: Resetting loading state in error handler');
        patientProvider.resetLoadingState();
        print('✅ SUBMIT DEBUG: Loading state reset in error handler');
        
        print('📢 SUBMIT DEBUG: Showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
        print('✅ SUBMIT DEBUG: Error snackbar shown');
      } else {
        print('❌ SUBMIT DEBUG: Component not mounted during error handling');
      }
    }
    print('🏁 SUBMIT DEBUG: _submitForm() completed');
  }
}
