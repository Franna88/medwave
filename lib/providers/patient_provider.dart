import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/patient.dart';
import '../models/progress_metrics.dart';
import '../services/firebase/patient_service.dart';

class PatientProvider with ChangeNotifier {
  final List<Patient> _patients = [];
  Patient? _selectedPatient;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<Patient>>? _patientsSubscription;
  
  // Feature flag for development - allows switching between mock and Firebase
  static const bool _useFirebase = true;

  List<Patient> get patients => List.unmodifiable(_patients);
  Patient? get selectedPatient => _selectedPatient;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get patients with recent updates (last 7 days)
  List<Patient> get recentlyUpdatedPatients {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    return _patients.where((patient) {
      return patient.lastUpdated != null && 
             patient.lastUpdated!.isAfter(sevenDaysAgo);
    }).toList()..sort((a, b) => b.lastUpdated!.compareTo(a.lastUpdated!));
  }

  // Get patients with upcoming appointments
  List<Patient> get patientsWithUpcomingAppointments {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    
    return _patients.where((patient) {
      final nextAppointment = patient.nextAppointment;
      return nextAppointment != null && 
             nextAppointment.isAfter(now) && 
             nextAppointment.isBefore(nextWeek);
    }).toList()..sort((a, b) => a.nextAppointment!.compareTo(b.nextAppointment!));
  }

  // Get patients with significant improvement
  List<Patient> get patientsWithImprovement {
    return _patients.where((patient) => patient.hasImprovement).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Initialize patient data stream
  Future<void> loadPatients() async {
    if (!_useFirebase) {
      return _loadMockPatients();
    }

    try {
      _setLoading(true);
      _setError(null);
      
      // Subscribe to real-time patient updates
      _patientsSubscription?.cancel();
      _patientsSubscription = PatientService.getPatientsStream().listen(
        (patients) {
          _patients.clear();
          _patients.addAll(patients);
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load patients: $error');
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError('Failed to initialize patient stream: $e');
      _setLoading(false);
    }
  }

  /// Add a new patient
  Future<bool> addPatient(Patient patient) async {
    if (!_useFirebase) {
      return _addMockPatient(patient);
    }

    try {
      _setLoading(true);
      _setError(null);
      
      final patientId = await PatientService.createPatient(patient);
      
      // The real-time listener will automatically update the UI
      debugPrint('Patient created with ID: $patientId');
      return true;
    } catch (e) {
      _setError('Failed to add patient: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing patient
  Future<bool> updatePatient(String patientId, Patient patient) async {
    if (!_useFirebase) {
      return _updateMockPatient(patientId, patient);
    }

    try {
      _setLoading(true);
      _setError(null);
      
      await PatientService.updatePatient(patientId, patient);
      
      // The real-time listener will automatically update the UI
      return true;
    } catch (e) {
      _setError('Failed to update patient: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a patient
  Future<bool> deletePatient(String patientId) async {
    if (!_useFirebase) {
      return _deleteMockPatient(patientId);
    }

    try {
      _setLoading(true);
      _setError(null);
      
      await PatientService.deletePatient(patientId);
      
      // The real-time listener will automatically update the UI
      return true;
    } catch (e) {
      _setError('Failed to delete patient: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get a specific patient
  Future<Patient?> getPatient(String patientId) async {
    if (!_useFirebase) {
      return _getMockPatient(patientId);
    }

    try {
      return await PatientService.getPatient(patientId);
    } catch (e) {
      _setError('Failed to get patient: $e');
      return null;
    }
  }

  /// Search patients
  Future<List<Patient>> searchPatients(String query) async {
    if (!_useFirebase) {
      return _searchMockPatients(query);
    }

    try {
      return await PatientService.searchPatients(query);
    } catch (e) {
      _setError('Failed to search patients: $e');
      return [];
    }
  }

  /// Select a patient for detailed view
  void selectPatient(Patient patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  /// Clear selected patient
  void clearSelectedPatient() {
    _selectedPatient = null;
    notifyListeners();
  }

  /// Add a session to a patient
  Future<bool> addPatientSession(String patientId, Session session) async {
    print('🏥 PATIENT PROVIDER DEBUG: addPatientSession called');
    print('🏥 PATIENT PROVIDER DEBUG: Patient ID: $patientId');
    print('🏥 PATIENT PROVIDER DEBUG: Session ID: ${session.id}');
    print('🏥 PATIENT PROVIDER DEBUG: UseFirebase flag: $_useFirebase');
    
    if (!_useFirebase) {
      print('🏥 PATIENT PROVIDER DEBUG: Using mock data - calling _addMockSession');
      return _addMockSession(patientId, session);
    }

    try {
      print('🏥 PATIENT PROVIDER DEBUG: Setting loading state to true');
      _setLoading(true);
      _setError(null);
      
      print('🏥 PATIENT PROVIDER DEBUG: Calling PatientService.addPatientSession');
      await PatientService.addPatientSession(patientId, session);
      print('✅ PATIENT PROVIDER DEBUG: PatientService.addPatientSession completed successfully');
      
      // The real-time listener will automatically update the UI
      print('🏥 PATIENT PROVIDER DEBUG: Returning true (success)');
      return true;
    } catch (e) {
      print('❌ PATIENT PROVIDER DEBUG: Error in addPatientSession: $e');
      _setError('Failed to add session: $e');
      return false;
    } finally {
      print('🏥 PATIENT PROVIDER DEBUG: Setting loading state to false');
      _setLoading(false);
    }
  }

  /// Get patient sessions
  Future<List<Session>> getPatientSessions(String patientId) async {
    if (!_useFirebase) {
      final patient = _getMockPatient(patientId);
      return patient?.sessions ?? [];
    }

    try {
      return await PatientService.getPatientSessions(patientId);
    } catch (e) {
      _setError('Failed to get patient sessions: $e');
      return [];
    }
  }

  /// Upload patient photos
  Future<List<String>> uploadPatientPhotos(
    String patientId, 
    List<String> imagePaths, 
    String photoType,
  ) async {
    if (!_useFirebase) {
      // Return mock URLs for development
      return imagePaths.map((path) => 'mock_url_$path').toList();
    }

    try {
      return await PatientService.uploadPatientPhotos(patientId, imagePaths, photoType);
    } catch (e) {
      _setError('Failed to upload photos: $e');
      return [];
    }
  }

  /// Upload signature images
  Future<Map<String, String>> uploadSignatures(
    String patientId,
    Map<String, String> signaturePaths,
  ) async {
    if (!_useFirebase) {
      // Return mock URLs for development
      return signaturePaths.map((key, path) => MapEntry(key, 'mock_signature_url_$path'));
    }

    try {
      return await PatientService.uploadSignatures(patientId, signaturePaths);
    } catch (e) {
      _setError('Failed to upload signatures: $e');
      return {};
    }
  }

  /// Calculate progress metrics for a patient using real session data from main collection
  Future<ProgressMetrics> calculateProgress(String patientId) async {
    final patient = _patients.firstWhere(
      (p) => p.id == patientId,
      orElse: () => throw Exception('Patient not found'),
    );

    // Fetch real sessions from main collection
    final sessions = await getPatientSessions(patientId);
    
    // Calculate pain reduction percentage
    double painReductionPercentage = 0.0;
    if (sessions.isNotEmpty && patient.baselineVasScore != null) {
      final latestVas = sessions.last.vasScore;
      final baselineVas = patient.baselineVasScore!;
      if (baselineVas > 0) {
        painReductionPercentage = ((baselineVas - latestVas) / baselineVas) * 100;
      }
    }
    
    // Calculate weight change percentage
    double weightChangePercentage = 0.0;
    if (sessions.isNotEmpty && patient.baselineWeight != null) {
      final latestWeight = sessions.last.weight;
      final baselineWeight = patient.baselineWeight!;
      if (baselineWeight > 0) {
        weightChangePercentage = ((latestWeight - baselineWeight) / baselineWeight) * 100;
      }
    }
    
    // Calculate wound healing percentage
    double woundHealingPercentage = 0.0;
    if (sessions.isNotEmpty && patient.baselineWounds != null && patient.baselineWounds!.isNotEmpty) {
      final baselineArea = patient.baselineWounds!.fold(0.0, (sum, w) => sum + w.area);
      final latestArea = sessions.last.wounds.fold(0.0, (sum, w) => sum + w.area);
      if (baselineArea > 0) {
        woundHealingPercentage = ((baselineArea - latestArea) / baselineArea) * 100;
      }
    }
    
    // Create progress data points from real sessions
    final painHistory = sessions.map((session) => ProgressDataPoint(
      date: session.date,
      value: session.vasScore.toDouble(),
      sessionNumber: session.sessionNumber,
    )).toList();
    
    final weightHistory = sessions.map((session) => ProgressDataPoint(
      date: session.date,
      value: session.weight,
      sessionNumber: session.sessionNumber,
    )).toList();
    
    final woundSizeHistory = sessions.map((session) => ProgressDataPoint(
      date: session.date,
      value: session.wounds.fold(0.0, (sum, w) => sum + w.area),
      sessionNumber: session.sessionNumber,
    )).toList();

    return ProgressMetrics(
      patientId: patientId,
      calculatedAt: DateTime.now(),
      painReductionPercentage: painReductionPercentage,
      weightChangePercentage: weightChangePercentage,
      woundHealingPercentage: woundHealingPercentage,
      totalSessions: sessions.length,
      hasSignificantImprovement: painReductionPercentage > 20 || woundHealingPercentage > 30,
      painHistory: painHistory,
      weightHistory: weightHistory,
      woundSizeHistory: woundSizeHistory,
      improvementSummary: _generateImprovementSummaryFromSessions(patient, sessions, painReductionPercentage, weightChangePercentage, woundHealingPercentage),
    );
  }

  /// Generate improvement summary text from real session data
  String _generateImprovementSummaryFromSessions(Patient patient, List<Session> sessions, double painReduction, double weightChange, double woundHealing) {
    final List<String> improvements = [];
    
    if (painReduction > 20) {
      improvements.add('${painReduction.toStringAsFixed(1)}% pain reduction');
    }
    
    if (weightChange.abs() > 5) {
      if (weightChange > 0) {
        improvements.add('${weightChange.toStringAsFixed(1)}% weight gain');
      } else {
        improvements.add('${weightChange.abs().toStringAsFixed(1)}% weight loss');
      }
    }
    
    if (woundHealing > 30) {
      improvements.add('${woundHealing.toStringAsFixed(1)}% wound healing');
    }
    
    if (improvements.isEmpty) {
      if (sessions.isEmpty) {
        return 'Begin treatment to track progress';
      }
      return 'Continue monitoring progress';
    }
    
    return 'Showing improvement: ${improvements.join(', ')}';
  }



  /// Add a session (legacy method name for backward compatibility)
  Future<bool> addSession(String patientId, Session session) async {
    return await addPatientSession(patientId, session);
  }

  /// Get patient statistics
  Future<Map<String, int>> getPatientStats() async {
    if (!_useFirebase) {
      return _getMockPatientStats();
    }

    try {
      return await PatientService.getPatientStats();
    } catch (e) {
      _setError('Failed to get patient statistics: $e');
      return {
        'total': 0,
        'withImprovement': 0,
        'recentlyUpdated': 0,
      };
    }
  }

  /// Dispose of resources
  @override
  void dispose() {
    _patientsSubscription?.cancel();
    super.dispose();
  }

  // Mock data methods for development
  Future<void> _loadMockPatients() async {
    _setLoading(true);
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    _patients.clear();
    _patients.addAll(_generateMockPatients());
    
    _setLoading(false);
  }

  Future<bool> _addMockPatient(Patient patient) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _patients.add(patient);
    notifyListeners();
    return true;
  }

  Future<bool> _updateMockPatient(String patientId, Patient patient) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _patients.indexWhere((p) => p.id == patientId);
    if (index != -1) {
      _patients[index] = patient;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> _deleteMockPatient(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final initialLength = _patients.length;
    _patients.removeWhere((p) => p.id == patientId);
    final removed = initialLength - _patients.length;
    if (removed > 0) {
      notifyListeners();
      return true;
    }
    return false;
  }

  Patient? _getMockPatient(String patientId) {
    return _patients.firstWhere(
      (p) => p.id == patientId,
      orElse: () => _patients.first, // Fallback for mock data
    );
  }

  List<Patient> _searchMockPatients(String query) {
    if (query.isEmpty) return _patients;
    
    final lowercaseQuery = query.toLowerCase();
    return _patients.where((patient) {
      return patient.name.toLowerCase().contains(lowercaseQuery) ||
             patient.idNumber.toLowerCase().contains(lowercaseQuery) ||
             patient.email.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  Future<bool> _addMockSession(String patientId, Session session) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _patients.indexWhere((p) => p.id == patientId);
    if (index != -1) {
      final updatedSessions = List<Session>.from(_patients[index].sessions)..add(session);
      _patients[index] = _patients[index].copyWith(sessions: updatedSessions);
      notifyListeners();
      return true;
    }
    return false;
  }

  Map<String, int> _getMockPatientStats() {
    return {
      'total': _patients.length,
      'withImprovement': patientsWithImprovement.length,
      'recentlyUpdated': recentlyUpdatedPatients.length,
    };
  }

  List<Patient> _generateMockPatients() {
    // This would contain your existing mock patient generation logic
    // For now, return an empty list since Firebase is the primary path
    return [];
  }
}