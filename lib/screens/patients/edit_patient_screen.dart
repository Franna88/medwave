import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../utils/localization.dart';
import '../../utils/id_validation.dart';
import '../../widgets/pmb_chip_selector.dart';

class EditPatientScreen extends StatefulWidget {
  final String patientId;
  
  const EditPatientScreen({super.key, required this.patientId});

  @override
  State<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends State<EditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  Patient? _patient;

  // Basic Patient Details Controllers
  final _surnameController = TextEditingController();
  final _fullNamesController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _patientCellController = TextEditingController();
  final _emailController = TextEditingController();
  
  DateTime? _dateOfBirth;
  String? _maritalStatus;

  // Person Responsible Controllers
  final _responsibleSurnameController = TextEditingController();
  final _responsibleFullNamesController = TextEditingController();
  final _responsibleIdNumberController = TextEditingController();
  final _responsibleCellController = TextEditingController();
  DateTime? _responsibleDateOfBirth;

  // Medical Aid Controllers
  final _medicalAidSchemeController = TextEditingController();
  final _medicalAidNumberController = TextEditingController();
  final _mainMemberNameController = TextEditingController();
  bool _isPrivatePatient = false;

  // Medical History Controllers
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

  // Referring Doctor
  final _referringDoctorController = TextEditingController();
  final _referringDoctorContactController = TextEditingController();
  
  // Enhanced Medical History Details
  final Map<String, String> _detailedMedicalConditions = {};
  
  // PMB Conditions
  List<String> _selectedPMBConditions = [];

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);
    final patient = await patientProvider.getPatient(widget.patientId);
    
    if (patient != null) {
      setState(() {
        _patient = patient;
        
        // Populate form fields
        _surnameController.text = patient.surname;
        _fullNamesController.text = patient.fullNames;
        _idNumberController.text = patient.idNumber;
        _patientCellController.text = patient.patientCell;
        _emailController.text = patient.email;
        _dateOfBirth = patient.dateOfBirth;
        _maritalStatus = patient.maritalStatus;
        
        // Responsible person
        _responsibleSurnameController.text = patient.responsiblePersonSurname ?? '';
        _responsibleFullNamesController.text = patient.responsiblePersonFullNames ?? '';
        _responsibleIdNumberController.text = patient.responsiblePersonIdNumber ?? '';
        _responsibleCellController.text = patient.responsiblePersonCell ?? '';
        _responsibleDateOfBirth = patient.responsiblePersonDateOfBirth;
        
        // Medical Aid
        _isPrivatePatient = patient.medicalAidSchemeName == 'Private';
        if (!_isPrivatePatient) {
          _medicalAidSchemeController.text = patient.medicalAidSchemeName ?? '';
          _medicalAidNumberController.text = patient.medicalAidNumber ?? '';
          _mainMemberNameController.text = patient.mainMemberName ?? '';
        }
        
        // Referring Doctor
        _referringDoctorController.text = patient.referringDoctorName ?? '';
        _referringDoctorContactController.text = patient.referringDoctorCell ?? '';
        
        // Medical History
        _medicalConditions.addAll(patient.medicalConditions);
        _detailedMedicalConditions.addAll(patient.medicalConditionDetails.map((key, value) => MapEntry(key, value ?? '')));
        _currentMedicationsController.text = patient.currentMedications ?? '';
        _allergiesController.text = patient.allergies ?? '';
        _isSmoker = patient.isSmoker ?? false;
        
        // PMB Conditions
        _selectedPMBConditions = patient.pmbConditionIds ?? [];
        
        _isLoading = false;
      });
    } else {
      // Patient not found
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient not found'),
            backgroundColor: Colors.red,
          ),
        );
        context.pop();
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Patient'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Patient'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: _saveChanges,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  title: AppLocalizations.get('patient_details'),
                  children: [
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
                const SizedBox(height: 24),
                
                _buildSection(
                  title: AppLocalizations.get('person_responsible'),
                  children: [
                    TextFormField(
                      controller: _responsibleSurnameController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.get('surname'),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _responsibleFullNamesController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.get('full_names'),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _responsibleIdNumberController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.get('id_number'),
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
                        labelText: AppLocalizations.get('patient_cell'),
                        prefixIcon: const Icon(Icons.phone_android),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                _buildSection(
                  title: AppLocalizations.get('medical_aid_details'),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isPrivatePatient 
                              ? AppTheme.primaryColor 
                              : AppTheme.primaryColor.withOpacity(0.2),
                          width: _isPrivatePatient ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isPrivatePatient,
                            onChanged: (value) {
                              setState(() {
                                _isPrivatePatient = value ?? false;
                                if (_isPrivatePatient) {
                                  _medicalAidSchemeController.clear();
                                  _medicalAidNumberController.clear();
                                  _mainMemberNameController.clear();
                                }
                              });
                            },
                            activeColor: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.get('private_patient'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (!_isPrivatePatient) ...[
                      TextFormField(
                        controller: _medicalAidSchemeController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.get('name_of_scheme'),
                          prefixIcon: const Icon(Icons.medical_services),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _medicalAidNumberController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.get('medical_aid_no'),
                          prefixIcon: const Icon(Icons.credit_card),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _mainMemberNameController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.get('name_of_main_member'),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
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
                const SizedBox(height: 24),
                
                _buildSection(
                  title: AppLocalizations.get('medical_history'),
                  children: [
                    ..._medicalConditions.keys.map((condition) => _buildMedicalConditionTile(condition)),
                    const SizedBox(height: 16),
                    
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
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _currentMedicationsController,
                      decoration: const InputDecoration(
                        labelText: 'Current Medications',
                        prefixIcon: Icon(Icons.medication),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _allergiesController,
                      decoration: const InputDecoration(
                        labelText: 'Allergies',
                        prefixIcon: Icon(Icons.warning),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
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
          if (_medicalConditions[condition] == true) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _detailedMedicalConditions[condition],
              decoration: InputDecoration(
                labelText: 'Condition Details',
                hintText: 'Please provide details about ${AppLocalizations.get(condition).toLowerCase()}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (value) {
                _detailedMedicalConditions[condition] = value;
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date of birth'),
          backgroundColor: Colors.red,
        ),
      );
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
              Text('Updating patient...'),
            ],
          ),
        ),
      );

      // Create medical condition details map
      final medicalConditionDetails = <String, String?>{};
      for (String condition in _medicalConditions.keys) {
        if (_medicalConditions[condition] == true) {
          medicalConditionDetails[condition] = _detailedMedicalConditions[condition];
        }
      }

      // Create updated patient object
      final updatedPatient = _patient!.copyWith(
        surname: _surnameController.text,
        fullNames: _fullNamesController.text,
        idNumber: _idNumberController.text,
        dateOfBirth: _dateOfBirth,
        patientCell: _patientCellController.text,
        email: _emailController.text,
        maritalStatus: _maritalStatus,
        
        // Responsible person
        responsiblePersonSurname: _responsibleSurnameController.text,
        responsiblePersonFullNames: _responsibleFullNamesController.text,
        responsiblePersonIdNumber: _responsibleIdNumberController.text,
        responsiblePersonCell: _responsibleCellController.text,
        responsiblePersonDateOfBirth: _responsibleDateOfBirth,
        
        // Medical Aid
        medicalAidSchemeName: _isPrivatePatient ? 'Private' : _medicalAidSchemeController.text,
        medicalAidNumber: _isPrivatePatient ? 'N/A' : _medicalAidNumberController.text,
        mainMemberName: _isPrivatePatient ? 'N/A' : _mainMemberNameController.text,
        
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
      );

      // Update patient
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      await patientProvider.updatePatient(widget.patientId, updatedPatient);

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

