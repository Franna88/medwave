import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/patient.dart';
import '../models/progress_metrics.dart';
import '../services/firebase/patient_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientProvider with ChangeNotifier {
  final List<Patient> _patients = [];
  Patient? _selectedPatient;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<Patient>>? _patientsSubscription;
  int _totalSessionCount = 0;
  
  // Session caching to prevent excessive database queries
  final Map<String, List<Session>> _sessionCache = {};
  final Map<String, DateTime> _sessionCacheTimestamps = {};
  static const Duration _cacheExpiration = Duration(minutes: 5);
  
  // Feature flag for development - allows switching between mock and Firebase
  static const bool _useFirebase = false;

  List<Patient> get patients => List.unmodifiable(_patients);
  Patient? get selectedPatient => _selectedPatient;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalSessionCount => _totalSessionCount;

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

  /// Force reset loading state (useful after navigation)
  void resetLoadingState() {
    _setLoading(false);
    print('🔄 PATIENT PROVIDER: Loading state manually reset');
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
          _loadSessionCount(); // Load session count when patients are updated
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

  /// Load total session count from Firebase
  Future<void> _loadSessionCount() async {
    if (!_useFirebase) {
      // For mock data, count sessions from patients
      _totalSessionCount = _patients.fold<int>(0, (sum, p) => sum + p.sessions.length);
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _totalSessionCount = 0;
        return;
      }

      // Query the main sessions collection for this practitioner
      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('practitionerId', isEqualTo: userId)
          .get();
      
      _totalSessionCount = snapshot.docs.length;
      debugPrint('PatientProvider: Loaded $_totalSessionCount total sessions');
    } catch (e) {
      debugPrint('PatientProvider: Error loading session count: $e');
      _totalSessionCount = 0;
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
      
      // Immediately set loading to false since patient creation is complete
      // The real-time listener will handle UI updates without additional loading state
      _setLoading(false);
      
      return true;
    } catch (e) {
      _setError('Failed to add patient: $e');
      _setLoading(false);
      return false;
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
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update patient: $e');
      _setLoading(false);
      return false;
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
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete patient: $e');
      _setLoading(false);
      return false;
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
      
      // Clear the session cache since we've added a new session
      clearSessionCache(patientId);
      
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

  /// Get patient sessions with caching to prevent excessive database queries
  Future<List<Session>> getPatientSessions(String patientId) async {
    if (!_useFirebase) {
      final patient = _getMockPatient(patientId);
      return patient?.sessions ?? [];
    }

    // Check cache first
    final now = DateTime.now();
    final cacheTimestamp = _sessionCacheTimestamps[patientId];
    
    if (cacheTimestamp != null && 
        now.difference(cacheTimestamp) < _cacheExpiration &&
        _sessionCache.containsKey(patientId)) {
      print('📋 CACHE: Using cached sessions for patient $patientId');
      return _sessionCache[patientId]!;
    }

    try {
      print('📋 CACHE: Fetching fresh sessions for patient $patientId');
      final sessions = await PatientService.getPatientSessions(patientId);
      
      // Update cache
      _sessionCache[patientId] = sessions;
      _sessionCacheTimestamps[patientId] = now;
      
      return sessions;
    } catch (e) {
      _setError('Failed to get patient sessions: $e');
      return [];
    }
  }

  /// Clear session cache for a specific patient (call when sessions are added/updated)
  void clearSessionCache(String patientId) {
    _sessionCache.remove(patientId);
    _sessionCacheTimestamps.remove(patientId);
    print('📋 CACHE: Cleared session cache for patient $patientId');
  }

  /// Clear all session caches
  void clearAllSessionCaches() {
    _sessionCache.clear();
    _sessionCacheTimestamps.clear();
    print('📋 CACHE: Cleared all session caches');
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
    if (sessions.isNotEmpty) {
      final latestVas = sessions.last.vasScore;
      final baselineVas = patient.baselineVasScore;
      if (baselineVas > 0) {
        painReductionPercentage = ((baselineVas - latestVas) / baselineVas) * 100;
      }
    }
    
    // Calculate weight change percentage
    double weightChangePercentage = 0.0;
    if (sessions.isNotEmpty) {
      final latestWeight = sessions.last.weight;
      final baselineWeight = patient.baselineWeight;
      if (baselineWeight > 0) {
        weightChangePercentage = ((latestWeight - baselineWeight) / baselineWeight) * 100;
      }
    }
    
    // Calculate wound healing percentage
    double woundHealingPercentage = 0.0;
    if (sessions.isNotEmpty && patient.baselineWounds.isNotEmpty) {
      final baselineArea = patient.baselineWounds.fold(0.0, (sum, w) => sum + w.area);
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
    final now = DateTime.now();
    
    return [
      Patient(
        id: 'patient_1',
        surname: 'Johnson',
        fullNames: 'Sarah Marie',
        idNumber: '8501234567890',
        dateOfBirth: DateTime(1985, 3, 15),
        patientCell: '+1-555-0101',
        email: 'sarah.johnson@email.com',
        responsiblePersonSurname: 'Johnson',
        responsiblePersonFullNames: 'Michael Johnson',
        responsiblePersonIdNumber: '8201234567890',
        responsiblePersonDateOfBirth: DateTime(1982, 1, 10),
        responsiblePersonCell: '+1-555-0102',
        medicalAidSchemeName: 'Discovery Health',
        medicalAidNumber: 'DH123456',
        mainMemberName: 'Sarah Johnson',
        medicalConditions: {'diabetes': true, 'hypertension': false, 'heart': false},
        medicalConditionDetails: {'diabetes': 'Type 2, well controlled'},
        isSmoker: false,
        baselineWeight: 75.5,
        baselineVasScore: 6,
        baselineWounds: [],
        baselinePhotos: [],
        currentWounds: [],
        practitionerId: 'practitioner_1',
        sessions: [
          Session(
            id: 'session_1',
            patientId: 'patient_1',
            sessionNumber: 1,
            date: now.subtract(const Duration(days: 7)),
            weight: 75.5,
            vasScore: 6,
            wounds: [],
            notes: 'Initial assessment completed',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
          Session(
            id: 'session_2',
            patientId: 'patient_1',
            sessionNumber: 2,
            date: now.subtract(const Duration(days: 3)),
            weight: 75.2,
            vasScore: 4,
            wounds: [],
            notes: 'Good progress, wound healing well',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 14)),
        lastUpdated: now.subtract(const Duration(days: 3)),
      ),
      Patient(
        id: 'patient_2',
        surname: 'Smith',
        fullNames: 'Robert James',
        idNumber: '7812345678901',
        dateOfBirth: DateTime(1978, 8, 22),
        patientCell: '+1-555-0201',
        email: 'robert.smith@email.com',
        responsiblePersonSurname: 'Smith',
        responsiblePersonFullNames: 'Robert James',
        responsiblePersonIdNumber: '7812345678901',
        responsiblePersonDateOfBirth: DateTime(1978, 8, 22),
        responsiblePersonCell: '+1-555-0201',
        medicalAidSchemeName: 'Momentum Health',
        medicalAidNumber: 'MH789012',
        mainMemberName: 'Robert Smith',
        medicalConditions: {'diabetes': false, 'hypertension': true, 'heart': false},
        medicalConditionDetails: {'hypertension': 'Mild, medication controlled'},
        isSmoker: false,
        baselineWeight: 82.3,
        baselineVasScore: 7,
        baselineWounds: [],
        baselinePhotos: [],
        currentWounds: [],
        practitionerId: 'practitioner_1',
        sessions: [
          Session(
            id: 'session_3',
            patientId: 'patient_2',
            sessionNumber: 1,
            date: now.subtract(const Duration(days: 10)),
            weight: 82.3,
            vasScore: 7,
            wounds: [],
            notes: 'Chronic wound assessment',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 21)),
        lastUpdated: now.subtract(const Duration(days: 10)),
      ),
      Patient(
        id: 'patient_3',
        surname: 'Williams',
        fullNames: 'Emily Rose',
        idNumber: '9203456789012',
        dateOfBirth: DateTime(1992, 12, 5),
        patientCell: '+1-555-0301',
        email: 'emily.williams@email.com',
        responsiblePersonSurname: 'Williams',
        responsiblePersonFullNames: 'Emily Rose',
        responsiblePersonIdNumber: '9203456789012',
        responsiblePersonDateOfBirth: DateTime(1992, 12, 5),
        responsiblePersonCell: '+1-555-0301',
        medicalAidSchemeName: 'Bonitas',
        medicalAidNumber: 'BN345678',
        mainMemberName: 'Emily Williams',
        medicalConditions: {'diabetes': false, 'hypertension': false, 'heart': false},
        medicalConditionDetails: {},
        isSmoker: false,
        baselineWeight: 68.7,
        baselineVasScore: 3,
        baselineWounds: [],
        baselinePhotos: [],
        currentWounds: [],
        practitionerId: 'practitioner_1',
        sessions: [
          Session(
            id: 'session_4',
            patientId: 'patient_3',
            sessionNumber: 1,
            date: now.subtract(const Duration(days: 5)),
            weight: 68.7,
            vasScore: 3,
            wounds: [],
            notes: 'Minor wound care',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
          Session(
            id: 'session_5',
            patientId: 'patient_3',
            sessionNumber: 2,
            date: now.subtract(const Duration(days: 2)),
            weight: 68.5,
            vasScore: 2,
            wounds: [],
            notes: 'Excellent healing progress',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
          Session(
            id: 'session_6',
            patientId: 'patient_3',
            sessionNumber: 3,
            date: now.subtract(const Duration(days: 1)),
            weight: 68.4,
            vasScore: 1,
            wounds: [],
            notes: 'Nearly healed, final session',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 12)),
        lastUpdated: now.subtract(const Duration(days: 1)),
      ),
      Patient(
        id: 'patient_4',
        surname: 'Brown',
        fullNames: 'Michael David',
        idNumber: '8567890123456',
        dateOfBirth: DateTime(1985, 6, 18),
        patientCell: '+1-555-0401',
        email: 'michael.brown@email.com',
        responsiblePersonSurname: 'Brown',
        responsiblePersonFullNames: 'Michael David',
        responsiblePersonIdNumber: '8567890123456',
        responsiblePersonDateOfBirth: DateTime(1985, 6, 18),
        responsiblePersonCell: '+1-555-0401',
        medicalAidSchemeName: 'Medihelp',
        medicalAidNumber: 'MH456789',
        mainMemberName: 'Michael Brown',
        medicalConditions: {'diabetes': true, 'hypertension': true, 'heart': false},
        medicalConditionDetails: {
          'diabetes': 'Type 2, insulin dependent',
          'hypertension': 'Moderate, multiple medications'
        },
        isSmoker: true,
        baselineWeight: 95.2,
        baselineVasScore: 8,
        baselineWounds: [],
        baselinePhotos: [],
        currentWounds: [],
        practitionerId: 'practitioner_1',
        sessions: [
          Session(
            id: 'session_7',
            patientId: 'patient_4',
            sessionNumber: 1,
            date: now.subtract(const Duration(days: 14)),
            weight: 95.2,
            vasScore: 8,
            wounds: [],
            notes: 'Complex diabetic wound',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
          Session(
            id: 'session_8',
            patientId: 'patient_4',
            sessionNumber: 2,
            date: now.subtract(const Duration(days: 11)),
            weight: 94.8,
            vasScore: 7,
            wounds: [],
            notes: 'Slow but steady progress',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
          Session(
            id: 'session_9',
            patientId: 'patient_4',
            sessionNumber: 3,
            date: now.subtract(const Duration(days: 8)),
            weight: 94.5,
            vasScore: 6,
            wounds: [],
            notes: 'Continuing treatment protocol',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
          Session(
            id: 'session_10',
            patientId: 'patient_4',
            sessionNumber: 4,
            date: now.subtract(const Duration(days: 4)),
            weight: 94.1,
            vasScore: 5,
            wounds: [],
            notes: 'Improved wound appearance',
            photos: [],
            practitionerId: 'practitioner_1',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 28)),
        lastUpdated: now.subtract(const Duration(days: 4)),
      ),
      Patient(
        id: 'patient_5',
        surname: 'Davis',
        fullNames: 'Jennifer Lynn',
        idNumber: '9012345678901',
        dateOfBirth: DateTime(1990, 4, 12),
        patientCell: '+1-555-0501',
        email: 'jennifer.davis@email.com',
        responsiblePersonSurname: 'Davis',
        responsiblePersonFullNames: 'Jennifer Lynn',
        responsiblePersonIdNumber: '9012345678901',
        responsiblePersonDateOfBirth: DateTime(1990, 4, 12),
        responsiblePersonCell: '+1-555-0501',
        medicalAidSchemeName: 'Fedhealth',
        medicalAidNumber: 'FH567890',
        mainMemberName: 'Jennifer Davis',
        medicalConditions: {'diabetes': false, 'hypertension': false, 'heart': false},
        medicalConditionDetails: {},
        isSmoker: false,
        baselineWeight: 65.0,
        baselineVasScore: 0,
        baselineWounds: [],
        baselinePhotos: [],
        currentWounds: [],
        practitionerId: 'practitioner_1',
        sessions: [],
        createdAt: now.subtract(const Duration(days: 2)),
        lastUpdated: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}