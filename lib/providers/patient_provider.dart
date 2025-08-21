import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import '../models/progress_metrics.dart';

class PatientProvider with ChangeNotifier {
  final List<Patient> _patients = [];
  Patient? _selectedPatient;
  bool _isLoading = false;

  List<Patient> get patients => List.unmodifiable(_patients);
  Patient? get selectedPatient => _selectedPatient;
  bool get isLoading => _isLoading;

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

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> loadPatients() async {
    setLoading(true);
    
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Load sample data
    _loadSampleData();
    
    setLoading(false);
  }

  void _loadSampleData() {
    final now = DateTime.now();
    
    // Sample patients with realistic data
    final samplePatients = [
      Patient(
        id: '1',
        surname: 'Johnson',
        fullNames: 'Sarah',
        idNumber: '8501125678901',
        dateOfBirth: DateTime(1985, 1, 12),
        patientCell: '+27 82 123 4567',
        email: 'sarah.johnson@email.com',
        responsiblePersonSurname: 'Johnson',
        responsiblePersonFullNames: 'Sarah',
        responsiblePersonIdNumber: '8501125678901',
        responsiblePersonDateOfBirth: DateTime(1985, 1, 12),
        responsiblePersonCell: '+27 82 123 4567',
        medicalAidSchemeName: 'Discovery Health',
        medicalAidNumber: 'DH123456789',
        mainMemberName: 'Sarah Johnson',
        medicalConditions: {},
        medicalConditionDetails: {},
        isSmoker: false,
        createdAt: now.subtract(const Duration(days: 30)),
        lastUpdated: now.subtract(const Duration(days: 2)),
        baselineWeight: 68.5,
        baselineVasScore: 8,
        baselineWounds: [
          Wound(
            id: 'w1',
            location: 'Left ankle',
            type: 'Diabetic ulcer',
            length: 3.2,
            width: 2.1,
            depth: 0.8,
            description: 'Chronic diabetic ulcer with moderate exudate',
            photos: ['baseline_photo_1.jpg'],
            assessedAt: now.subtract(const Duration(days: 30)),
            stage: WoundStage.stage2,
          ),
        ],
        baselinePhotos: ['patient_1_baseline.jpg'],
        currentWeight: 67.2,
        currentVasScore: 4,
        currentWounds: [
          Wound(
            id: 'w1',
            location: 'Left ankle',
            type: 'Diabetic ulcer',
            length: 2.1,
            width: 1.4,
            depth: 0.3,
            description: 'Significant improvement in wound healing',
            photos: ['current_photo_1.jpg'],
            assessedAt: now.subtract(const Duration(days: 2)),
            stage: WoundStage.stage1,
          ),
        ],
        sessions: [
          Session(
            id: 's1',
            patientId: '1',
            sessionNumber: 1,
            date: now.subtract(const Duration(days: 25)),
            weight: 68.2,
            vasScore: 7,
            wounds: [],
            notes: 'Initial treatment session, patient responding well',
            photos: ['session_1_photo.jpg'],
            practitionerId: 'p1',
          ),
          Session(
            id: 's2',
            patientId: '1',
            sessionNumber: 2,
            date: now.subtract(const Duration(days: 18)),
            weight: 67.8,
            vasScore: 6,
            wounds: [],
            notes: 'Continued improvement in pain levels',
            photos: ['session_2_photo.jpg'],
            practitionerId: 'p1',
          ),
          Session(
            id: 's3',
            patientId: '1',
            sessionNumber: 3,
            date: now.subtract(const Duration(days: 11)),
            weight: 67.5,
            vasScore: 5,
            wounds: [],
            notes: 'Wound showing signs of healing',
            photos: ['session_3_photo.jpg'],
            practitionerId: 'p1',
          ),
          Session(
            id: 's4',
            patientId: '1',
            sessionNumber: 4,
            date: now.subtract(const Duration(days: 4)),
            weight: 67.2,
            vasScore: 4,
            wounds: [],
            notes: 'Excellent progress, patient very satisfied',
            photos: ['session_4_photo.jpg'],
            practitionerId: 'p1',
          ),
        ],
      ),
      Patient(
        id: '2',
        surname: 'Chen',
        fullNames: 'Michael',
        idNumber: '6202156789012',
        dateOfBirth: DateTime(1962, 2, 15),
        patientCell: '+27 83 987 6543',
        email: 'michael.chen@email.com',
        responsiblePersonSurname: 'Chen',
        responsiblePersonFullNames: 'Michael',
        responsiblePersonIdNumber: '6202156789012',
        responsiblePersonDateOfBirth: DateTime(1962, 2, 15),
        responsiblePersonCell: '+27 83 987 6543',
        medicalAidSchemeName: 'Bonitas Medical Fund',
        medicalAidNumber: 'BM987654321',
        mainMemberName: 'Michael Chen',
        medicalConditions: {},
        medicalConditionDetails: {},
        isSmoker: false,
        createdAt: now.subtract(const Duration(days: 45)),
        lastUpdated: now.subtract(const Duration(days: 5)),
        baselineWeight: 82.3,
        baselineVasScore: 9,
        baselineWounds: [
          Wound(
            id: 'w2',
            location: 'Right knee',
            type: 'Post-surgical wound',
            length: 4.5,
            width: 2.8,
            depth: 1.2,
            description: 'Post-surgical wound with delayed healing',
            photos: ['baseline_photo_2.jpg'],
            assessedAt: now.subtract(const Duration(days: 45)),
            stage: WoundStage.stage3,
          ),
        ],
        baselinePhotos: ['patient_2_baseline.jpg'],
        currentWeight: 81.1,
        currentVasScore: 6,
        currentWounds: [
          Wound(
            id: 'w2',
            location: 'Right knee',
            type: 'Post-surgical wound',
            length: 3.2,
            width: 2.0,
            depth: 0.6,
            description: 'Good healing progress, reduced inflammation',
            photos: ['current_photo_2.jpg'],
            assessedAt: now.subtract(const Duration(days: 5)),
            stage: WoundStage.stage2,
          ),
        ],
        sessions: [
          Session(
            id: 's5',
            patientId: '2',
            sessionNumber: 1,
            date: now.subtract(const Duration(days: 40)),
            weight: 82.0,
            vasScore: 8,
            wounds: [],
            notes: 'Starting treatment protocol',
            photos: ['session_5_photo.jpg'],
            practitionerId: 'p1',
          ),
          Session(
            id: 's6',
            patientId: '2',
            sessionNumber: 2,
            date: now.subtract(const Duration(days: 33)),
            weight: 81.7,
            vasScore: 7,
            wounds: [],
            notes: 'Some improvement noted',
            photos: ['session_6_photo.jpg'],
            practitionerId: 'p1',
          ),
        ],
      ),
      Patient(
        id: '3',
        surname: 'Williams',
        fullNames: 'Emma',
        idNumber: '8603258901234',
        dateOfBirth: DateTime(1986, 3, 25),
        patientCell: '+27 84 555 1234',
        email: 'emma.williams@email.com',
        responsiblePersonSurname: 'Williams',
        responsiblePersonFullNames: 'Emma',
        responsiblePersonIdNumber: '8603258901234',
        responsiblePersonDateOfBirth: DateTime(1986, 3, 25),
        responsiblePersonCell: '+27 84 555 1234',
        medicalAidSchemeName: 'Momentum Health',
        medicalAidNumber: 'MH555123456',
        mainMemberName: 'Emma Williams',
        medicalConditions: {},
        medicalConditionDetails: {},
        isSmoker: false,
        createdAt: now.subtract(const Duration(days: 15)),
        lastUpdated: now.subtract(const Duration(days: 1)),
        baselineWeight: 59.8,
        baselineVasScore: 6,
        baselineWounds: [],
        baselinePhotos: ['patient_3_baseline.jpg'],
        currentWeight: 60.2,
        currentVasScore: 3,
        currentWounds: [],
        sessions: [
          Session(
            id: 's7',
            patientId: '3',
            sessionNumber: 1,
            date: now.subtract(const Duration(days: 10)),
            weight: 59.9,
            vasScore: 5,
            wounds: [],
            notes: 'Initial assessment and treatment plan',
            photos: ['session_7_photo.jpg'],
            practitionerId: 'p1',
          ),
        ],
      ),
    ];

    _patients.clear();
    _patients.addAll(samplePatients);
  }

  void selectPatient(String patientId) {
    _selectedPatient = _patients.firstWhere(
      (patient) => patient.id == patientId,
      orElse: () => throw Exception('Patient not found'),
    );
    notifyListeners();
  }

  Future<void> addPatient(Patient patient) async {
    setLoading(true);
    
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 300));
    
    _patients.add(patient);
    notifyListeners();
    setLoading(false);
  }

  Future<void> updatePatient(Patient updatedPatient) async {
    setLoading(true);
    
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 300));
    
    final index = _patients.indexWhere((p) => p.id == updatedPatient.id);
    if (index != -1) {
      _patients[index] = updatedPatient.copyWith(lastUpdated: DateTime.now());
      if (_selectedPatient?.id == updatedPatient.id) {
        _selectedPatient = _patients[index];
      }
      notifyListeners();
    }
    
    setLoading(false);
  }

  Future<void> addSession(String patientId, Session session) async {
    setLoading(true);
    
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 300));
    
    final patientIndex = _patients.indexWhere((p) => p.id == patientId);
    if (patientIndex != -1) {
      final patient = _patients[patientIndex];
      final updatedSessions = List<Session>.from(patient.sessions)..add(session);
      
      _patients[patientIndex] = patient.copyWith(
        sessions: updatedSessions,
        lastUpdated: DateTime.now(),
        currentWeight: session.weight,
        currentVasScore: session.vasScore,
        currentWounds: session.wounds,
      );
      
      if (_selectedPatient?.id == patientId) {
        _selectedPatient = _patients[patientIndex];
      }
      
      notifyListeners();
    }
    
    setLoading(false);
  }

  ProgressMetrics calculateProgress(String patientId) {
    final patient = _patients.firstWhere((p) => p.id == patientId);
    
    final painHistory = patient.sessions.map((session) => 
      ProgressDataPoint(
        date: session.date,
        value: session.vasScore.toDouble(),
        sessionNumber: session.sessionNumber,
        notes: session.notes,
      )
    ).toList();

    final weightHistory = patient.sessions.map((session) => 
      ProgressDataPoint(
        date: session.date,
        value: session.weight,
        sessionNumber: session.sessionNumber,
      )
    ).toList();

    // Calculate wound size history
    final woundSizeHistory = patient.sessions.where((session) => session.wounds.isNotEmpty)
      .map((session) => 
        ProgressDataPoint(
          date: session.date,
          value: session.wounds.first.area,
          sessionNumber: session.sessionNumber,
        )
      ).toList();

    final painReduction = patient.painReductionPercentage;
    final weightChange = patient.weightChangePercentage;
    final woundHealing = patient.currentWounds.isNotEmpty && patient.baselineWounds.isNotEmpty
        ? ((patient.baselineWounds.first.area - patient.currentWounds.first.area) / 
           patient.baselineWounds.first.area) * 100
        : 0.0;

    final hasImprovement = painReduction > 20 || woundHealing > 30;
    
    String improvementSummary = '';
    if (painReduction > 0) {
      improvementSummary += 'Pain reduced by ${painReduction.toStringAsFixed(1)}%. ';
    }
    if (woundHealing > 0) {
      improvementSummary += 'Wound healing progress: ${woundHealing.toStringAsFixed(1)}%. ';
    }
    if (weightChange.abs() > 5) {
      improvementSummary += 'Weight ${weightChange > 0 ? 'gained' : 'lost'}: ${weightChange.abs().toStringAsFixed(1)}%.';
    }

    return ProgressMetrics(
      patientId: patientId,
      calculatedAt: DateTime.now(),
      painReductionPercentage: painReduction,
      weightChangePercentage: weightChange,
      woundHealingPercentage: woundHealing,
      totalSessions: patient.sessions.length,
      painHistory: painHistory,
      weightHistory: weightHistory,
      woundSizeHistory: woundSizeHistory,
      hasSignificantImprovement: hasImprovement,
      improvementSummary: improvementSummary.trim(),
    );
  }
}
