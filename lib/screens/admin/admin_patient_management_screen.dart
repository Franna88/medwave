import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/admin_provider.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import 'admin_patient_detail_screen.dart';

// Define PatientStatus enum since it's not in the model
enum PatientStatus { active, recovered, inactive }

class AdminPatientManagementScreen extends StatefulWidget {
  const AdminPatientManagementScreen({super.key});

  @override
  State<AdminPatientManagementScreen> createState() => _AdminPatientManagementScreenState();
}

class _AdminPatientManagementScreenState extends State<AdminPatientManagementScreen> {
  String _searchQuery = '';
  String _countryFilter = 'All';
  String _statusFilter = 'All';
  
  // Map to store last session date for each patient
  final Map<String, DateTime> _patientLastSessions = {};

  @override
  void initState() {
    super.initState();
    // Initialize patient data when the screen loads (admin mode - load ALL patients)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().loadPatients(isAdmin: true);
      _loadPatientSessions();
    });
  }
  
  /// Load last session dates for all patients from the main sessions collection
  Future<void> _loadPatientSessions() async {
    try {
      // Query the main sessions collection
      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .orderBy('date', descending: true)
          .get();
      
      // Build a map of patientId to last session date
      final Map<String, DateTime> lastSessions = {};
      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final patientId = data['patientId'] as String?;
        final date = (data['date'] as Timestamp?)?.toDate();
        
        if (patientId != null && date != null) {
          // Only keep the most recent session for each patient (since ordered by date desc)
          if (!lastSessions.containsKey(patientId)) {
            lastSessions[patientId] = date;
          }
        }
      }
      
      setState(() {
        _patientLastSessions.clear();
        _patientLastSessions.addAll(lastSessions);
      });
      
      debugPrint('✅ Loaded session data for ${lastSessions.length} patients');
    } catch (e) {
      debugPrint('❌ Error loading patient sessions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer2<AdminProvider, PatientProvider>(
        builder: (context, adminProvider, patientProvider, child) {
          if (adminProvider.isLoading || patientProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Use real patient data from PatientProvider
          final patients = patientProvider.patients;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildPatientStatistics(patients, adminProvider),
                const SizedBox(height: 24),
                _buildFiltersSection(),
                const SizedBox(height: 24),
                _buildPatientsTable(patients),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patient Management',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Monitor and manage patient data across all healthcare providers',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPatientStatistics(List<Patient> patients, AdminProvider adminProvider) {
    final totalPatients = patients.length;
    final activePatients = patients.where((p) => _getPatientStatus(p) == PatientStatus.active).length;
    final completedTreatments = patients.where((p) => _getPatientStatus(p) == PatientStatus.recovered).length;
    final averageAge = patients.isEmpty ? 0.0 : patients.fold(0, (sum, p) => sum + _getPatientAge(p)) / patients.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Patients',
            totalPatients.toString(),
            Icons.people,
            AppTheme.primaryColor,
            'Across all providers',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Treatments',
            activePatients.toString(),
            Icons.medical_services,
            Colors.green,
            'Currently receiving care',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Completed',
            completedTreatments.toString(),
            Icons.check_circle,
            Colors.blue,
            'Successfully treated',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Average Age',
            averageAge.toStringAsFixed(1),
            Icons.calendar_today,
            Colors.orange,
            'Years old',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
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
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search patients by name, ID, or condition...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: ['All', 'Active', 'Recovered', 'Inactive'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) => setState(() => _statusFilter = value!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _countryFilter,
              decoration: InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: ['All', 'USA', 'RSA'].map((country) {
                return DropdownMenuItem(value: country, child: Text(country));
              }).toList(),
              onChanged: (value) => setState(() => _countryFilter = value!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsTable(List<Patient> patients) {
    final filteredPatients = _getFilteredPatients(patients);

    return Container(
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Patient Records (${filteredPatients.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 600,
            child: DataTable2(
              columnSpacing: 12,
              horizontalMargin: 20,
              minWidth: 1200,
              columns: const [
                DataColumn2(
                  label: Text('Patient'),
                  size: ColumnSize.L,
                ),
                DataColumn2(
                  label: Text('Age/Gender'),
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Condition'),
                  size: ColumnSize.L,
                ),
                DataColumn2(
                  label: Text('Provider'),
                  size: ColumnSize.M,
                ),
                DataColumn2(
                  label: Text('Status'),
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Last Session'),
                  size: ColumnSize.M,
                ),
                DataColumn2(
                  label: Text('Progress'),
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Actions'),
                  size: ColumnSize.M,
                ),
              ],
              rows: filteredPatients.map((patient) {
                return DataRow2(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Text(
                          _getPatientFullName(patient),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'ID: ${patient.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text('${_getPatientAge(patient)}y, ${_getPatientGender(patient)}'),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getPatientPrimaryCondition(patient),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (_getPatientWoundType(patient) != null)
                            Text(
                              _getPatientWoundType(patient)!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(patient.practitionerId),
                    ),
                    DataCell(_buildStatusChip(patient)),
                    DataCell(
                      Text(
                        _getPatientLastSessionDate(patient) != null
                            ? '${DateTime.now().difference(_getPatientLastSessionDate(patient)!).inDays} days ago'
                            : 'No sessions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    DataCell(
                      LinearProgressIndicator(
                        value: _calculateProgress(patient),
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(_calculateProgress(patient)),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () => _viewPatientDetails(patient),
                            tooltip: 'View Details',
                          ),
                          IconButton(
                            icon: const Icon(Icons.history),
                            onPressed: () => _viewPatientHistory(patient),
                            tooltip: 'View History',
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) => _handlePatientAction(value, patient),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'export',
                                child: Text('Export Data'),
                              ),
                              const PopupMenuItem(
                                value: 'reassign',
                                child: Text('Reassign Provider'),
                              ),
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text('Archive Patient'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Patient patient) {
    final status = _getPatientStatus(patient);
    Color color;
    String text;
    
    switch (status) {
      case PatientStatus.active:
        color = Colors.green;
        text = 'Active';
        break;
      case PatientStatus.recovered:
        color = Colors.blue;
        text = 'Recovered';
        break;
      case PatientStatus.inactive:
        color = Colors.orange;
        text = 'Inactive';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<Patient> _getFilteredPatients(List<Patient> patients) {
    var filtered = patients;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((patient) {
        return _getPatientFullName(patient).toLowerCase().contains(_searchQuery.toLowerCase()) ||
               patient.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               _getPatientPrimaryCondition(patient).toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by status
    if (_statusFilter != 'All') {
      PatientStatus? status;
      switch (_statusFilter) {
        case 'Active':
          status = PatientStatus.active;
          break;
        case 'Recovered':
          status = PatientStatus.recovered;
          break;
        case 'Inactive':
          status = PatientStatus.inactive;
          break;
      }
      if (status != null) {
        filtered = filtered.where((patient) => _getPatientStatus(patient) == status).toList();
      }
    }

    return filtered;
  }

  double _calculateProgress(Patient patient) {
    // Mock progress calculation based on session count and recovery status
    final status = _getPatientStatus(patient);
    if (status == PatientStatus.recovered) return 1.0;
    if (status == PatientStatus.inactive) return 0.0;
    
    // Calculate based on sessions (mock logic)
    final sessionCount = patient.sessions.length;
    return (sessionCount / 10).clamp(0.0, 0.9); // Max 90% for active patients
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return Colors.green;
    if (progress >= 0.5) return Colors.orange;
    return Colors.red;
  }

  void _viewPatientDetails(Patient patient) {
    // Navigate to detailed patient screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminPatientDetailScreen(patient: patient),
      ),
    );
  }

  void _viewPatientHistory(Patient patient) {
    // Navigate to patient history or show history dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing history for ${_getPatientFullName(patient)}')),
    );
  }

  void _handlePatientAction(String action, Patient patient) {
    switch (action) {
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exporting data for ${_getPatientFullName(patient)}')),
        );
        break;
      case 'reassign':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reassigning provider for ${_getPatientFullName(patient)}')),
        );
        break;
      case 'archive':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archiving ${_getPatientFullName(patient)}')),
        );
        break;
    }
  }

  // Helper methods to work with Patient model
  String _getPatientFullName(Patient patient) {
    return '${patient.fullNames} ${patient.surname}';
  }

  int _getPatientAge(Patient patient) {
    final now = DateTime.now();
    final age = now.year - patient.dateOfBirth.year;
    if (now.month < patient.dateOfBirth.month || 
        (now.month == patient.dateOfBirth.month && now.day < patient.dateOfBirth.day)) {
      return age - 1;
    }
    return age;
  }

  String _getPatientGender(Patient patient) {
    // Since gender is not in the Patient model, we'll derive it from ID number
    // In South African ID numbers, the 7th digit indicates gender
    if (patient.idNumber.length >= 7) {
      final genderDigit = int.tryParse(patient.idNumber.substring(6, 7)) ?? 0;
      return genderDigit < 5 ? 'Female' : 'Male';
    }
    return 'Unknown';
  }

  PatientStatus _getPatientStatus(Patient patient) {
    // Determine status based on last session date
    final lastSession = _patientLastSessions[patient.id];
    if (lastSession == null) return PatientStatus.inactive;
    
    final daysSinceLastSession = DateTime.now().difference(lastSession).inDays;
    if (daysSinceLastSession > 60) return PatientStatus.inactive;
    if (daysSinceLastSession > 30) return PatientStatus.recovered;
    return PatientStatus.active;
  }

  String _getPatientPrimaryCondition(Patient patient) {
    // Get the first medical condition that is true
    final conditions = patient.medicalConditions.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
    return conditions.isNotEmpty ? conditions.first : 'No specific condition';
  }

  String? _getPatientWoundType(Patient patient) {
    // Check if patient has any current wounds
    if (patient.currentWounds.isNotEmpty) {
      return patient.currentWounds.first.type;
    }
    // Fall back to baseline wounds
    if (patient.baselineWounds.isNotEmpty) {
      return patient.baselineWounds.first.type;
    }
    return null;
  }

  DateTime? _getPatientLastSessionDate(Patient patient) {
    // Check if we have session data loaded from Firebase
    return _patientLastSessions[patient.id];
  }

}
