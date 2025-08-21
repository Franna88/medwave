import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/patient.dart';
import '../../../providers/patient_provider.dart';
import '../../../theme/app_theme.dart';

class PatientSelector extends StatefulWidget {
  final Patient? selectedPatient;
  final Function(Patient?) onPatientSelected;
  final Function(String) onManualPatientAdded;

  const PatientSelector({
    super.key,
    this.selectedPatient,
    required this.onPatientSelected,
    required this.onManualPatientAdded,
  });

  @override
  State<PatientSelector> createState() => _PatientSelectorState();
}

class _PatientSelectorState extends State<PatientSelector> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualNameController = TextEditingController();
  List<Patient> _filteredPatients = [];
  bool _showManualEntry = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatientsIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualNameController.dispose();
    super.dispose();
  }

  void _loadPatientsIfNeeded() {
    final patientProvider = context.read<PatientProvider>();
    if (patientProvider.patients.isEmpty) {
      patientProvider.loadPatients();
    }
    _updateFilteredPatients();
  }

  void _updateFilteredPatients() {
    final patientProvider = context.read<PatientProvider>();
    final allPatients = patientProvider.patients;
    
    if (_searchQuery.isEmpty) {
      _filteredPatients = allPatients;
    } else {
      _filteredPatients = allPatients.where((patient) {
        return patient.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               patient.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               patient.phone.contains(_searchQuery);
      }).toList();
    }
    
    setState(() {});
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _updateFilteredPatients();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, child) {
        if (patientProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient *',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            
            // Search field
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients by name, email, or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
            
            const SizedBox(height: 12),
            
            // Patient selection area
            if (_showManualEntry) ...[
              // Manual patient entry
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_add, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Add New Patient',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showManualEntry = false;
                              _manualNameController.clear();
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _manualNameController,
                      decoration: const InputDecoration(
                        labelText: 'Patient Name',
                        hintText: 'Enter patient full name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter patient name';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (value.trim().isNotEmpty) {
                          widget.onManualPatientAdded(value.trim());
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Note: This will create a temporary patient entry for this appointment only.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Patient list or empty state
              if (_filteredPatients.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 48,
                        color: AppTheme.secondaryColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty 
                            ? 'No patients found' 
                            : 'No patients match your search',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Add a new patient or load existing patients'
                            : 'Try a different search term or add a new patient',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryColor.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showManualEntry = true;
                          });
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add New Patient'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Patient selection list
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Add new patient option at the top
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showManualEntry = true;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_add,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Add New Patient',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppTheme.primaryColor,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Divider
                      const Divider(height: 1),
                      
                      // Patient list
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _filteredPatients.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final patient = _filteredPatients[index];
                            final isSelected = widget.selectedPatient?.id == patient.id;
                            
                            return InkWell(
                              onTap: () {
                                widget.onPatientSelected(patient);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                color: isSelected 
                                    ? AppTheme.primaryColor.withOpacity(0.1) 
                                    : null,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isSelected 
                                          ? AppTheme.primaryColor 
                                          : AppTheme.secondaryColor.withOpacity(0.3),
                                      child: Text(
                                        patient.name.isNotEmpty 
                                            ? patient.name[0].toUpperCase() 
                                            : '?',
                                        style: TextStyle(
                                          color: isSelected 
                                              ? Colors.white 
                                              : AppTheme.secondaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            patient.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isSelected 
                                                  ? AppTheme.primaryColor 
                                                  : AppTheme.textColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${patient.age} years • ${patient.medicalAid}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.secondaryColor.withOpacity(0.8),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (patient.phone.isNotEmpty)
                                            Text(
                                              patient.phone,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.secondaryColor.withOpacity(0.6),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}
