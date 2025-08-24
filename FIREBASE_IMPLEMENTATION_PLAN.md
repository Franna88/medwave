# MedWave Firebase Implementation Plan

## Overview

This document outlines the complete implementation plan for integrating Firebase into the MedWave wound care management system. The plan includes detailed Firebase data structure design, per-screen implementation steps, and migration strategy from the current mock data system.

## Firebase Project Setup

### Required Firebase Services
1. **Firebase Authentication** - User management
2. **Cloud Firestore** - Real-time database
3. **Firebase Storage** - Image and file storage
4. **Cloud Functions** - Server-side logic
5. **Firebase Cloud Messaging (FCM)** - Push notifications
6. **Firebase Analytics** - Usage tracking
7. **Firebase Performance Monitoring** - App performance

### Dependencies to Add

```yaml
# pubspec.yaml additions
dependencies:
  # Firebase Core
  firebase_core: ^2.24.2
  
  # Authentication
  firebase_auth: ^4.15.3
  
  # Database
  cloud_firestore: ^4.13.6
  
  # Storage
  firebase_storage: ^11.5.6
  
  # Messaging
  firebase_messaging: ^14.7.10
  
  # Analytics
  firebase_analytics: ^10.7.4
  
  # Performance
  firebase_performance: ^0.9.3+8
  
  # Functions (if needed)
  cloud_functions: ^4.6.8
```

## Firestore Database Structure

### Collections & Document Structure

```javascript
// Users Collection
users/{userId} {
  // Profile Information
  firstName: string,
  lastName: string,
  email: string,
  phoneNumber: string,
  licenseNumber: string,
  specialization: string,
  yearsOfExperience: number,
  practiceLocation: string,
  
  // Location & Country Information (for super admin analytics)
  country: string, // ISO country code (ZA, US, UK, etc.)
  countryName: string, // Full country name
  province: string, // State/Province
  city: string,
  address: string,
  postalCode: string,
  
  // Practitioner Approval Workflow
  accountStatus: string, // 'pending' | 'approved' | 'rejected' | 'suspended'
  applicationDate: timestamp,
  approvalDate: timestamp,
  approvedBy: string, // Reference to super admin user ID
  rejectionReason: string, // If rejected
  
  // Professional Verification
  licenseVerified: boolean,
  licenseVerificationDate: timestamp,
  professionalReferences: array<{
    name: string,
    organization: string,
    email: string,
    phone: string,
    relationship: string
  }>,
  
  // App Settings
  settings: {
    notificationsEnabled: boolean,
    darkModeEnabled: boolean,
    biometricEnabled: boolean,
    language: string, // 'en' | 'af'
    timezone: string
  },
  
  // Metadata
  createdAt: timestamp,
  lastUpdated: timestamp,
  lastLogin: timestamp,
  role: string, // 'practitioner' | 'super_admin' | 'country_admin'
  
  // Super Admin Analytics Support
  totalPatients: number, // Calculated field updated via Cloud Functions
  totalSessions: number, // Calculated field
  lastActivityDate: timestamp
}

// Practitioner Applications Collection (for approval workflow)
practitionerApplications/{applicationId} {
  // Applicant Information
  userId: string, // Reference to users collection
  email: string, // Denormalized for admin view
  firstName: string,
  lastName: string,
  
  // Professional Information
  licenseNumber: string,
  specialization: string,
  yearsOfExperience: number,
  practiceLocation: string,
  
  // Location Information
  country: string,
  countryName: string,
  province: string,
  city: string,
  
  // Application Status
  status: string, // 'pending' | 'under_review' | 'approved' | 'rejected'
  submittedAt: timestamp,
  reviewedAt: timestamp,
  reviewedBy: string, // Super admin user ID
  reviewNotes: string,
  rejectionReason: string,
  
  // Supporting Documents (Firebase Storage references)
  documents: {
    licenseDocument: string, // Storage path
    idDocument: string,
    qualificationCertificate: string,
    professionalReference: string
  },
  
  // Verification Status
  documentsVerified: boolean,
  licenseVerified: boolean,
  referencesVerified: boolean
}

// Country Analytics Collection (aggregated data for super admin)
countryAnalytics/{countryCode} {
  countryName: string,
  
  // Practitioner Statistics
  totalPractitioners: number,
  activePractitioners: number, // Last 30 days
  pendingApplications: number,
  approvedThisMonth: number,
  rejectedThisMonth: number,
  
  // Patient Statistics
  totalPatients: number,
  newPatientsThisMonth: number,
  totalSessions: number,
  sessionsThisMonth: number,
  
  // Performance Metrics
  averageSessionsPerPractitioner: number,
  averagePatientsPerPractitioner: number,
  averageWoundHealingRate: number,
  
  // Geographic Distribution
  provinces: map<string, {
    totalPractitioners: number,
    totalPatients: number,
    totalSessions: number
  }>,
  
  // Last Updated
  lastCalculated: timestamp,
  calculatedBy: string // Cloud Function identifier
}

// Patients Collection
patients/{patientId} {
  // Basic Information
  surname: string,
  fullNames: string,
  idNumber: string,
  dateOfBirth: timestamp,
  patientCell: string,
  email: string,
  maritalStatus: string,
  occupation: string,
  
  // Location Information (inherited from practitioner for analytics)
  country: string, // ISO country code from practitioner
  countryName: string, // Full country name from practitioner
  province: string, // Province from practitioner
  city: string, // Patient's city (can be different from practitioner)
  
  // Work Information (optional)
  workNameAndAddress: string,
  workPostalAddress: string,
  workTelNo: string,
  homeTelNo: string,
  
  // Responsible Person Information
  responsiblePerson: {
    surname: string,
    fullNames: string,
    idNumber: string,
    dateOfBirth: timestamp,
    workNameAndAddress: string,
    workPostalAddress: string,
    workTelNo: string,
    cell: string,
    homeTelNo: string,
    email: string,
    maritalStatus: string,
    occupation: string,
    relationToPatient: string
  },
  
  // Medical Aid Information
  medicalAid: {
    schemeName: string,
    number: string,
    planAndDepNumber: string,
    mainMemberName: string
  },
  
  // Referring Doctor Information
  referringDoctor: {
    name: string,
    cell: string,
    additionalReferrerName: string,
    additionalReferrerCell: string
  },
  
  // Medical History
  medicalHistory: {
    conditions: map, // condition -> boolean
    conditionDetails: map, // condition -> details
    currentMedications: string,
    allergies: string,
    isSmoker: boolean,
    naturalTreatments: string
  },
  
  // Consent and Signatures
  consent: {
    accountResponsibilitySignature: string, // Storage URL
    accountResponsibilitySignatureDate: timestamp,
    woundPhotographyConsentSignature: string, // Storage URL
    witnessSignature: string, // Storage URL
    woundPhotographyConsentDate: timestamp,
    trainingPhotosConsent: boolean,
    trainingPhotosConsentDate: timestamp
  },
  
  // Baseline Measurements
  baseline: {
    weight: number,
    vasScore: number,
    wounds: [woundObject], // Array of wound objects
    photos: [string] // Array of Storage URLs
  },
  
  // Current Status
  current: {
    weight: number,
    vasScore: number,
    wounds: [woundObject]
  },
  
  // Metadata
  practitionerId: string, // Reference to users collection
  createdAt: timestamp,
  lastUpdated: timestamp,
  
  // Calculated fields (updated via Cloud Functions)
  calculations: {
    weightChange: number,
    painReduction: number,
    woundHealingProgress: number,
    hasImprovement: boolean,
    totalSessions: number,
    nextAppointment: timestamp
  }
}

// Sessions Subcollection
patients/{patientId}/sessions/{sessionId} {
  sessionNumber: number,
  date: timestamp,
  weight: number,
  vasScore: number,
  wounds: [woundObject],
  notes: string,
  photos: [string], // Storage URLs
  practitionerId: string,
  
  // Metadata
  createdAt: timestamp,
  lastUpdated: timestamp
}

// Appointments Collection
appointments/{appointmentId} {
  patientId: string, // Reference
  patientName: string, // Denormalized for quick access
  title: string,
  description: string,
  startTime: timestamp,
  endTime: timestamp,
  type: string, // 'consultation' | 'followUp' | 'treatment' | 'assessment' | 'emergency'
  status: string, // 'scheduled' | 'confirmed' | 'inProgress' | 'completed' | 'cancelled' | 'noShow' | 'rescheduled'
  practitionerId: string,
  practitionerName: string, // Denormalized
  location: string,
  notes: [string],
  reminderSent: string,
  metadata: map,
  
  // Metadata
  createdAt: timestamp,
  lastUpdated: timestamp
}

// Notifications Collection
notifications/{notificationId} {
  title: string,
  message: string,
  type: string, // 'appointment' | 'improvement' | 'reminder' | 'alert'
  priority: string, // 'low' | 'medium' | 'high' | 'urgent'
  isRead: boolean,
  
  // Target Information
  practitionerId: string,
  patientId: string, // Optional
  patientName: string, // Optional, denormalized
  
  // Additional Data
  data: map, // Additional notification-specific data
  
  // Metadata
  createdAt: timestamp,
  
  // Auto-delete after 30 days (Firestore TTL)
  expiresAt: timestamp
}

// Progress Reports Collection (Generated)
reports/{reportId} {
  patientId: string,
  patientName: string, // Denormalized
  practitionerId: string,
  reportType: string, // 'progress' | 'summary' | 'discharge'
  generatedAt: timestamp,
  treatmentStartDate: timestamp,
  treatmentEndDate: timestamp,
  
  metrics: {
    painReductionPercentage: number,
    weightChangePercentage: number,
    woundHealingPercentage: number,
    totalSessions: number,
    hasSignificantImprovement: boolean,
    improvementSummary: string
  },
  
  keyFindings: [string],
  recommendations: [string],
  
  // Storage URL for generated PDF
  pdfUrl: string,
  
  // Metadata
  createdAt: timestamp
}
```

### Wound Object Structure
```javascript
{
  id: string,
  location: string,
  type: string,
  length: number, // cm
  width: number, // cm
  depth: number, // cm
  description: string,
  photos: [string], // Storage URLs
  assessedAt: timestamp,
  stage: string // 'stage1' | 'stage2' | 'stage3' | 'stage4' | 'unstageable' | 'deepTissueInjury'
}
```

## Firebase Storage Structure

```
/users/{userId}/
  /profile/
    avatar.jpg
    
/patients/{patientId}/
  /baseline/
    baseline_photo_1.jpg
    baseline_photo_2.jpg
  /wounds/
    {woundId}/
      wound_photo_1.jpg
      wound_photo_2.jpg
  /sessions/
    {sessionId}/
      session_photo_1.jpg
      session_photo_2.jpg
  /signatures/
    account_responsibility.png
    wound_consent.png
    witness.png
    
/reports/{reportId}/
  report.pdf
  
/temp/{userId}/
  temp_upload_123.jpg
```

## Security Rules

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isSuperAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'super_admin';
    }
    
    function isApprovedPractitioner() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.accountStatus == 'approved';
    }
    
    // Users collection - enhanced for practitioner approval
    match /users/{userId} {
      // Users can read/write their own data
      allow read, write: if isOwner(userId);
      
      // Super admins can read all user data for approval/management
      allow read: if isSuperAdmin();
      
      // Super admins can update account status and approval fields
      allow update: if isSuperAdmin() && 
        onlyUpdatingFields(['accountStatus', 'approvalDate', 'approvedBy', 'rejectionReason', 
                           'licenseVerified', 'licenseVerificationDate']);
    }
    
    // Practitioner Applications - for approval workflow
    match /practitionerApplications/{applicationId} {
      // Applicants can create and read their own applications
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      
      // Super admins can read and update all applications
      allow read, update: if isSuperAdmin();
    }
    
    // Country Analytics - Super admin read only
    match /countryAnalytics/{countryCode} {
      allow read: if isSuperAdmin();
      // Updates handled by Cloud Functions only
    }
    
    // Helper function for field updates
    function onlyUpdatingFields(allowedFields) {
      return request.resource.data.keys().hasAll(resource.data.keys()) &&
             request.resource.data.keys().hasOnly(resource.data.keys().concat(allowedFields));
    }
    
    // Patients - only accessible by approved practitioners
    match /patients/{patientId} {
      allow read, write: if isApprovedPractitioner() && 
        resource.data.practitionerId == request.auth.uid;
      allow create: if isApprovedPractitioner() && 
        request.resource.data.practitionerId == request.auth.uid;
      
      // Super admins can read all patient data for analytics
      allow read: if isSuperAdmin();
        
      // Sessions subcollection
      match /sessions/{sessionId} {
        allow read, write: if isApprovedPractitioner() && 
          get(/databases/$(database)/documents/patients/$(patientId)).data.practitionerId == request.auth.uid;
        
        // Super admins can read sessions for analytics
        allow read: if isSuperAdmin();
      }
    }
    
    // Appointments - only accessible by approved practitioners
    match /appointments/{appointmentId} {
      allow read, write: if isApprovedPractitioner() && 
        resource.data.practitionerId == request.auth.uid;
      allow create: if isApprovedPractitioner() && 
        request.resource.data.practitionerId == request.auth.uid;
      
      // Super admins can read appointments for analytics
      allow read: if isSuperAdmin();
    }
    
    // Notifications - only accessible by the target practitioner
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        resource.data.practitionerId == request.auth.uid;
    }
    
    // Reports - only accessible by the practitioner
    match /reports/{reportId} {
      allow read: if request.auth != null && 
        resource.data.practitionerId == request.auth.uid;
      allow write: if false; // Only created by Cloud Functions
    }
  }
}
```

### Storage Security Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can only access their own files
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Patient files - only accessible by the practitioner
    match /patients/{patientId}/{allPaths=**} {
      allow read, write: if request.auth != null && 
        firestore.get(/databases/(default)/documents/patients/$(patientId)).data.practitionerId == request.auth.uid;
    }
    
    // Report files - read only for practitioner
    match /reports/{reportId}/{allPaths=**} {
      allow read: if request.auth != null && 
        firestore.get(/databases/(default)/documents/reports/$(reportId)).data.practitionerId == request.auth.uid;
    }
    
    // Temp files - only accessible by the uploader
    match /temp/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Cloud Functions

### Required Cloud Functions for Practitioner Management & Analytics

#### 1. Practitioner Application Processing
```javascript
// Function: processPractitionerApplication
// Trigger: Firestore onCreate practitionerApplications/{applicationId}
exports.processPractitionerApplication = functions.firestore
  .document('practitionerApplications/{applicationId}')
  .onCreate(async (snap, context) => {
    const application = snap.data();
    
    // Send notification to super admins
    await sendNotificationToSuperAdmins({
      title: 'New Practitioner Application',
      message: `${application.firstName} ${application.lastName} from ${application.countryName} has applied`,
      data: { applicationId: context.params.applicationId }
    });
    
    // Update country analytics
    await updateCountryAnalytics(application.country, 'pendingApplications', 1);
  });
```

#### 2. Practitioner Approval Workflow
```javascript
// Function: approvePractitioner
// Trigger: HTTP function called by super admin
exports.approvePractitioner = functions.https.onCall(async (data, context) => {
  // Verify super admin permissions
  if (!context.auth || !await isSuperAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Only super admins can approve practitioners');
  }
  
  const { applicationId, approved, rejectionReason } = data;
  
  const batch = admin.firestore().batch();
  
  // Update application status
  const appRef = admin.firestore().collection('practitionerApplications').doc(applicationId);
  const app = await appRef.get();
  const appData = app.data();
  
  batch.update(appRef, {
    status: approved ? 'approved' : 'rejected',
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewedBy: context.auth.uid,
    rejectionReason: approved ? null : rejectionReason
  });
  
  // Update user account status
  const userRef = admin.firestore().collection('users').doc(appData.userId);
  batch.update(userRef, {
    accountStatus: approved ? 'approved' : 'rejected',
    approvalDate: approved ? admin.firestore.FieldValue.serverTimestamp() : null,
    approvedBy: approved ? context.auth.uid : null,
    rejectionReason: approved ? null : rejectionReason
  });
  
  await batch.commit();
  
  // Update country analytics
  const field = approved ? 'approvedThisMonth' : 'rejectedThisMonth';
  await updateCountryAnalytics(appData.country, field, 1);
  await updateCountryAnalytics(appData.country, 'pendingApplications', -1);
  
  // Send notification to practitioner
  await sendNotificationToPractitioner(appData.userId, {
    title: approved ? 'Application Approved!' : 'Application Update',
    message: approved ? 'Your application has been approved. Welcome to MedWave!' : `Your application was not approved: ${rejectionReason}`
  });
});
```

#### 3. Country Analytics Calculator
```javascript
// Function: calculateCountryAnalytics
// Trigger: Scheduled function (runs daily)
exports.calculateCountryAnalytics = functions.pubsub.schedule('0 2 * * *').onRun(async () => {
  const countries = await getActiveCountries();
  
  for (const countryCode of countries) {
    await calculateAndUpdateCountryStats(countryCode);
  }
});

async function calculateAndUpdateCountryStats(countryCode) {
  const batch = admin.firestore().batch();
  
  // Get practitioners in country
  const practitioners = await admin.firestore()
    .collection('users')
    .where('country', '==', countryCode)
    .where('role', '==', 'practitioner')
    .where('accountStatus', '==', 'approved')
    .get();
  
  // Calculate aggregated statistics
  const stats = {
    totalPractitioners: practitioners.size,
    activePractitioners: 0,
    totalPatients: 0,
    totalSessions: 0,
    provinces: {}
  };
  
  for (const practitioner of practitioners.docs) {
    const practitionerData = practitioner.data();
    
    // Count active practitioners (last 30 days)
    if (practitionerData.lastActivityDate && 
        isWithinLast30Days(practitionerData.lastActivityDate)) {
      stats.activePractitioners++;
    }
    
    // Aggregate patient and session counts
    stats.totalPatients += practitionerData.totalPatients || 0;
    stats.totalSessions += practitionerData.totalSessions || 0;
    
    // Aggregate by province
    const province = practitionerData.province;
    if (!stats.provinces[province]) {
      stats.provinces[province] = {
        totalPractitioners: 0,
        totalPatients: 0,
        totalSessions: 0
      };
    }
    stats.provinces[province].totalPractitioners++;
    stats.provinces[province].totalPatients += practitionerData.totalPatients || 0;
    stats.provinces[province].totalSessions += practitionerData.totalSessions || 0;
  }
  
  // Calculate performance metrics
  stats.averagePatientsPerPractitioner = stats.totalPractitioners > 0 ? 
    stats.totalPatients / stats.totalPractitioners : 0;
  stats.averageSessionsPerPractitioner = stats.totalPractitioners > 0 ? 
    stats.totalSessions / stats.totalPractitioners : 0;
  
  // Update country analytics
  const analyticsRef = admin.firestore().collection('countryAnalytics').doc(countryCode);
  batch.set(analyticsRef, {
    ...stats,
    lastCalculated: admin.firestore.FieldValue.serverTimestamp(),
    calculatedBy: 'calculateCountryAnalytics'
  }, { merge: true });
  
  await batch.commit();
}
```

#### 4. Practitioner Statistics Updater
```javascript
// Function: updatePractitionerStats
// Trigger: Firestore changes on patients and sessions
exports.updatePractitionerStatsOnPatient = functions.firestore
  .document('patients/{patientId}')
  .onCreate(async (snap, context) => {
    const patient = snap.data();
    await incrementPractitionerStat(patient.practitionerId, 'totalPatients', 1);
    await updatePractitionerActivity(patient.practitionerId);
  });

exports.updatePractitionerStatsOnSession = functions.firestore
  .document('patients/{patientId}/sessions/{sessionId}')
  .onCreate(async (snap, context) => {
    const session = snap.data();
    await incrementPractitionerStat(session.practitionerId, 'totalSessions', 1);
    await updatePractitionerActivity(session.practitionerId);
  });
```

## Implementation Plan by Screen

### Phase 1: Firebase Setup & Authentication

#### 1.1 Project Setup
- [ ] Create Firebase project
- [ ] Add Android/iOS/Web configurations
- [ ] Install Firebase CLI
- [ ] Initialize Firebase SDK in Flutter app
- [ ] Configure security rules

#### 1.2 Authentication Implementation

**Files to modify:**
- `lib/providers/auth_provider.dart`
- `lib/screens/auth/login_screen.dart`
- `lib/screens/auth/signup_screen.dart`
- `lib/screens/auth/welcome_screen.dart`

**Implementation Steps:**

1. **Update AuthProvider**
```dart
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;
  
  User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  
  // Listen to auth state changes
  void initializeAuthStateListener() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await _loadUserProfile();
      } else {
        _userProfile = null;
      }
      notifyListeners();
    });
  }
  
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      setLoading(true);
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last login
      await _firestore.collection('users').doc(credential.user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      
      return true;
    } on FirebaseAuthException catch (e) {
      // Handle specific error codes
      throw _handleAuthException(e);
    } finally {
      setLoading(false);
    }
  }
  
  Future<bool> createUserWithEmailAndPassword(
    String email, 
    String password, 
    Map<String, dynamic> userData
  ) async {
    try {
      setLoading(true);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user profile document
      await _firestore.collection('users').doc(credential.user!.uid).set({
        ...userData,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'role': 'practitioner',
      });
      
      return true;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } finally {
      setLoading(false);
    }
  }
  
  Future<void> signOut() async {
    await _auth.signOut();
    _userProfile = null;
    notifyListeners();
  }
  
  Future<void> _loadUserProfile() async {
    if (_user == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userProfile = UserProfile.fromFirestore(doc);
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }
}
```

2. **Update Login Screen**
- Replace mock authentication with Firebase auth
- Add proper error handling for auth exceptions
- Add loading states
- Implement "Remember Me" functionality

3. **Update Signup Screen**
- Integrate with Firebase user creation
- Store additional user data in Firestore
- Add email verification flow
- Implement terms acceptance

### Phase 1.5: Practitioner Approval System

#### 1.5.1 Practitioner Application Workflow

**New Collections to Implement:**
- `practitionerApplications` collection
- `countryAnalytics` collection

**Files to create:**
- `lib/models/practitioner_application.dart`
- `lib/services/practitioner_service.dart`
- `lib/providers/admin_provider.dart`
- `lib/screens/admin/pending_applications_screen.dart`
- `lib/screens/admin/country_analytics_screen.dart`

**Implementation Steps:**

1. **Create PractitionerApplication Model**
```dart
class PractitionerApplication {
  final String id;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String licenseNumber;
  final String specialization;
  final int yearsOfExperience;
  final String practiceLocation;
  final String country;
  final String countryName;
  final String province;
  final String city;
  final ApplicationStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNotes;
  final String? rejectionReason;
  final Map<String, String> documents;
  final bool documentsVerified;
  final bool licenseVerified;
  final bool referencesVerified;
  
  // Constructors, fromFirestore, toFirestore methods
}

enum ApplicationStatus {
  pending, underReview, approved, rejected
}
```

2. **Update AuthProvider for Approval Status**
```dart
// Add to existing AuthProvider
Future<bool> checkApprovalStatus() async {
  if (_user == null) return false;
  
  final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
  if (!userDoc.exists) return false;
  
  final userData = userDoc.data()!;
  return userData['accountStatus'] == 'approved';
}

// Add approval status checking to navigation
bool get canAccessApp => _userProfile?.accountStatus == 'approved' || 
                         _userProfile?.role == 'super_admin';
```

3. **Create Admin Provider**
```dart
class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  List<PractitionerApplication> _pendingApplications = [];
  Map<String, CountryAnalytics> _countryAnalytics = {};
  bool _isLoading = false;
  
  List<PractitionerApplication> get pendingApplications => _pendingApplications;
  Map<String, CountryAnalytics> get countryAnalytics => _countryAnalytics;
  bool get isLoading => _isLoading;
  
  // Load pending applications
  Future<void> loadPendingApplications() async {
    setLoading(true);
    try {
      final snapshot = await _firestore
        .collection('practitionerApplications')
        .where('status', 'in', ['pending', 'under_review'])
        .orderBy('submittedAt', descending: true)
        .get();
      
      _pendingApplications = snapshot.docs
        .map((doc) => PractitionerApplication.fromFirestore(doc))
        .toList();
    } catch (e) {
      print('Error loading pending applications: $e');
    } finally {
      setLoading(false);
    }
  }
  
  // Approve/Reject practitioner
  Future<bool> reviewApplication(String applicationId, bool approved, {String? rejectionReason}) async {
    try {
      final callable = _functions.httpsCallable('approvePractitioner');
      await callable.call({
        'applicationId': applicationId,
        'approved': approved,
        'rejectionReason': rejectionReason,
      });
      
      // Refresh applications list
      await loadPendingApplications();
      return true;
    } catch (e) {
      print('Error reviewing application: $e');
      return false;
    }
  }
}
```

4. **Update Signup Screen for Detailed Application**
```dart
// Enhance signup to collect practitioner details
class SignupScreen extends StatefulWidget {
  // Add additional form fields for:
  // - License number
  // - Specialization
  // - Years of experience
  // - Practice location
  // - Country/Province/City
  // - Document uploads (license, ID, qualifications)
  
  Future<void> _submitApplication() async {
    // Create user account with status 'pending'
    // Upload supporting documents
    // Create practitioner application
    // Show pending approval message
  }
}
```

5. **Create Super Admin Dashboard Components**
- Pending applications list with review capabilities
- Country analytics dashboard
- Practitioner management tools

#### 1.5.2 Country Analytics Implementation

**Files to create:**
- `lib/models/country_analytics.dart`
- `lib/widgets/country_stats_card.dart`
- `lib/widgets/analytics_charts.dart`

**Cloud Functions to Deploy:**
- `processPractitionerApplication`
- `approvePractitioner`
- `calculateCountryAnalytics`
- `updatePractitionerStats`

### Phase 2: Patient Management

#### 2.1 Patient Data Implementation

**Files to modify:**
- `lib/providers/patient_provider.dart`
- `lib/screens/patients/add_patient_screen.dart`
- `lib/screens/patients/patient_list_screen.dart`
- `lib/screens/patients/patient_profile_screen.dart`

**Implementation Steps:**

1. **Update PatientProvider**
```dart
class PatientProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Patient> _patients = [];
  StreamSubscription<QuerySnapshot>? _patientsSubscription;
  bool _isLoading = false;
  
  List<Patient> get patients => List.unmodifiable(_patients);
  bool get isLoading => _isLoading;
  
  // Real-time patient data streaming
  void startPatientsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    _patientsSubscription = _firestore
        .collection('patients')
        .where('practitionerId', isEqualTo: userId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen((snapshot) {
      _patients = snapshot.docs
          .map((doc) => Patient.fromFirestore(doc))
          .toList();
      notifyListeners();
    });
  }
  
  void stopPatientsStream() {
    _patientsSubscription?.cancel();
    _patientsSubscription = null;
  }
  
  Future<void> addPatient(Patient patient) async {
    try {
      setLoading(true);
      
      // Upload baseline photos first
      final baselinePhotoUrls = await _uploadPhotos(
        patient.baselinePhotos, 
        'patients/${patient.id}/baseline'
      );
      
      // Upload wound photos
      final updatedWounds = await _uploadWoundPhotos(
        patient.baselineWounds, 
        'patients/${patient.id}/wounds'
      );
      
      // Upload signature images
      final consentUrls = await _uploadSignatures(patient, patient.id);
      
      // Create patient document
      final patientData = patient.copyWith(
        baselinePhotos: baselinePhotoUrls,
        baselineWounds: updatedWounds,
        accountResponsibilitySignature: consentUrls['account'],
        woundPhotographyConsentSignature: consentUrls['wound'],
        witnessSignature: consentUrls['witness'],
        practitionerId: _auth.currentUser!.uid,
      );
      
      await _firestore
          .collection('patients')
          .doc(patient.id)
          .set(patientData.toFirestore());
          
      // Trigger progress calculation via Cloud Function
      await _triggerProgressCalculation(patient.id);
      
    } catch (e) {
      throw Exception('Failed to add patient: $e');
    } finally {
      setLoading(false);
    }
  }
  
  Future<List<String>> _uploadPhotos(List<String> localPaths, String storagePath) async {
    final uploadTasks = localPaths.map((path) async {
      final file = File(path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${basename(path)}';
      final ref = _storage.ref().child('$storagePath/$fileName');
      
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    });
    
    return await Future.wait(uploadTasks);
  }
}
```

2. **Update Add Patient Screen**
- Implement image upload to Firebase Storage
- Add progress indicators for uploads
- Handle offline scenarios
- Implement signature upload

3. **Update Patient List Screen**
- Implement real-time data streaming
- Add offline support with cached data
- Implement search with Firestore queries
- Add pull-to-refresh functionality

#### 2.2 Session Management

**Files to modify:**
- `lib/screens/sessions/session_logging_screen.dart`
- `lib/screens/patients/session_detail_screen.dart`

**Implementation Steps:**

1. **Session Creation**
```dart
Future<void> addSession(String patientId, Session session) async {
  final batch = _firestore.batch();
  
  // Upload session photos
  final photoUrls = await _uploadPhotos(
    session.photos, 
    'patients/$patientId/sessions/${session.id}'
  );
  
  // Upload wound photos
  final updatedWounds = await _uploadWoundPhotos(
    session.wounds, 
    'patients/$patientId/wounds'
  );
  
  final sessionData = session.copyWith(
    photos: photoUrls,
    wounds: updatedWounds,
  );
  
  // Add session to subcollection
  batch.set(
    _firestore
        .collection('patients')
        .doc(patientId)
        .collection('sessions')
        .doc(session.id),
    sessionData.toFirestore()
  );
  
  // Update patient current status
  batch.update(
    _firestore.collection('patients').doc(patientId),
    {
      'current.weight': session.weight,
      'current.vasScore': session.vasScore,
      'current.wounds': updatedWounds.map((w) => w.toFirestore()).toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }
  );
  
  await batch.commit();
  
  // Trigger progress recalculation
  await _triggerProgressCalculation(patientId);
}
```

### Phase 3: Appointments & Calendar

#### 3.1 Appointment Management

**Files to modify:**
- `lib/providers/appointment_provider.dart`
- `lib/screens/calendar/calendar_screen.dart`
- `lib/screens/calendar/widgets/add_appointment_dialog.dart`

**Implementation Steps:**

1. **Real-time Appointment Streaming**
```dart
class AppointmentProvider extends ChangeNotifier {
  void startAppointmentsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    _appointmentsSubscription = _firestore
        .collection('appointments')
        .where('practitionerId', isEqualTo: userId)
        .orderBy('startTime')
        .snapshots()
        .listen((snapshot) {
      _appointments = snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .toList();
      notifyListeners();
    });
  }
  
  Future<void> addAppointment(Appointment appointment) async {
    // Check for conflicts
    final conflicts = await _checkForConflicts(
      appointment.startTime, 
      appointment.endTime
    );
    
    if (conflicts.isNotEmpty) {
      throw AppointmentConflictException(conflicts);
    }
    
    await _firestore
        .collection('appointments')
        .doc(appointment.id)
        .set(appointment.toFirestore());
        
    // Schedule notification reminder
    await _scheduleAppointmentReminder(appointment);
  }
}
```

### Phase 4: Notifications & Reports

#### 4.1 Notification System

**Files to modify:**
- `lib/providers/notification_provider.dart`
- `lib/screens/notifications/notifications_screen.dart`
- `lib/services/notification_service.dart`

**Implementation Steps:**

1. **FCM Integration**
```dart
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  static Future<void> initialize() async {
    // Request permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Get FCM token
    final token = await _messaging.getToken();
    
    // Save token to user profile
    if (token != null) {
      await _saveTokenToDatabase(token);
    }
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }
}
```

2. **Notification Generation**
- Implement Cloud Functions for automatic notifications
- Add real-time notification streaming
- Implement notification categories and priorities

#### 4.2 Reports & Analytics

**Files to modify:**
- `lib/screens/reports/reports_screen.dart`
- `lib/models/progress_metrics.dart`

**Implementation Steps:**

1. **Progress Calculation Cloud Function**
```javascript
// Cloud Function for progress calculation
exports.calculatePatientProgress = functions.firestore
  .document('patients/{patientId}/sessions/{sessionId}')
  .onWrite(async (change, context) => {
    const patientId = context.params.patientId;
    
    // Fetch patient data and all sessions
    const patient = await getPatientData(patientId);
    const sessions = await getPatientSessions(patientId);
    
    // Calculate progress metrics
    const metrics = calculateProgressMetrics(patient, sessions);
    
    // Update patient document with calculated fields
    await updatePatientCalculations(patientId, metrics);
    
    // Generate notifications if significant progress
    if (metrics.hasSignificantImprovement) {
      await generateProgressNotification(patientId, metrics);
    }
  });
```

### Phase 5: Offline Support & Synchronization

#### 5.1 Offline Data Management

**Implementation Steps:**

1. **Enable Firestore Offline Persistence**
```dart
await FirebaseFirestore.instance.enablePersistence();
```

2. **Implement Offline-First Approach**
- Cache critical data locally
- Queue operations for when online
- Implement conflict resolution
- Add offline indicators in UI

3. **Image Caching Strategy**
- Implement progressive image loading
- Cache essential images locally
- Background sync for non-critical images

### Phase 6: Performance Optimization

#### 6.1 Database Optimization

**Implementation Steps:**

1. **Firestore Indexes**
```javascript
// Required composite indexes
patients: [practitionerId, lastUpdated]
appointments: [practitionerId, startTime]
notifications: [practitionerId, createdAt]
sessions: [patientId, date]
```

2. **Data Pagination**
- Implement cursor-based pagination
- Lazy loading for large datasets
- Virtual scrolling for patient lists

3. **Storage Optimization**
- Image compression before upload
- Progressive image formats
- CDN integration for global access

## Migration Strategy

### Phase 1: Parallel Implementation
1. Keep existing mock data system running
2. Implement Firebase services alongside
3. Add feature flags to switch between systems
4. Test Firebase implementation thoroughly

### Phase 2: Gradual Migration
1. Migrate authentication first
2. Migrate patient data (with user consent)
3. Migrate appointments and sessions
4. Migrate notifications and reports

### Phase 3: Full Transition
1. Switch all users to Firebase
2. Remove mock data system
3. Optimize based on usage patterns
4. Implement advanced features

## Testing Strategy

### Unit Tests
- Firebase service wrappers
- Data model serialization
- Business logic functions
- Offline scenario handling

### Integration Tests
- Authentication flows
- Data CRUD operations
- Real-time synchronization
- File upload/download

### End-to-End Tests
- Complete user workflows
- Cross-platform compatibility
- Performance under load
- Offline/online transitions

## Security Audit Checklist

- [ ] Authentication implementation review
- [ ] Security rules testing
- [ ] Data encryption verification
- [ ] Access control validation
- [ ] Audit logging implementation
- [ ] HIPAA compliance verification
- [ ] Penetration testing
- [ ] Code security review

## Performance Monitoring

### Key Metrics to Track
- App startup time
- Data loading performance
- Image upload/download speed
- Offline/online transition time
- Memory usage patterns
- Battery consumption
- Network usage optimization

### Monitoring Tools
- Firebase Performance Monitoring
- Firebase Crashlytics
- Custom analytics events
- User experience metrics

## Rollout Plan

### Phase 1: Internal Testing (2 weeks)
- Development team testing
- Feature completeness verification
- Performance optimization
- Bug fixes and improvements

### Phase 2: Beta Testing (2 weeks)
- Select practitioner testing
- Real-world usage scenarios
- Feedback collection and implementation
- Security and compliance verification

### Phase 3: Gradual Rollout (2 weeks)
- 25% user rollout
- Monitor performance and issues
- 50% user rollout
- Full rollout after validation

### Phase 4: Post-Rollout (Ongoing)
- Performance monitoring
- User feedback implementation
- Feature enhancements
- Ongoing maintenance and updates

## Developer Implementation Notes

### Technical Implementation Guidelines

#### Code Organization Strategy
1. **Create Firebase Service Layer First**
   - Create `lib/services/firebase/` directory
   - Implement separate service classes for each data type
   - Use dependency injection pattern for testing

2. **Provider Modification Pattern**
   - Keep original provider interface intact
   - Add `isFirebaseEnabled` flag for testing
   - Implement both mock and Firebase data sources
   - Switch between them using environment variables

3. **Error Handling Strategy**
   ```dart
   // Standard error handling pattern for all Firebase operations
   try {
     final result = await firebaseOperation();
     return Right(result);
   } on FirebaseAuthException catch (e) {
     return Left(AuthError(e.message ?? 'Authentication failed'));
   } on FirebaseException catch (e) {
     return Left(DataError(e.message ?? 'Database operation failed'));
   } catch (e) {
     return Left(UnknownError('Unexpected error: $e'));
   }
   ```

#### Critical Implementation Details

**Authentication Implementation Order:**
1. Firebase project setup and configuration
2. AuthProvider modification with Firebase Auth
3. Login/Signup screen integration
4. User profile creation in Firestore
5. Navigation guard implementation

**Data Migration Strategy:**
1. Implement Firestore collections with proper indexing
2. Create data transformation utilities
3. Implement batch operations for bulk data
4. Add real-time listeners with proper cleanup
5. Test with Firebase Emulator extensively

**Image Storage Implementation:**
1. Setup Firebase Storage with proper security rules
2. Implement image compression before upload
3. Create thumbnail generation Cloud Function
4. Add progress indicators for uploads
5. Implement offline image caching

#### Development Environment Setup
```bash
# Firebase CLI setup
npm install -g firebase-tools
firebase login
firebase use --add # Select your project

# Start emulators for local development
firebase emulators:start --only auth,firestore,storage,functions
```

#### Testing Strategy During Development
1. **Unit Tests**: Test each service method independently
2. **Mock Data Toggle**: Keep ability to switch back to mock data
3. **Firebase Emulator**: Use for all development testing
4. **Error Scenarios**: Test network failures, permission errors
5. **Performance**: Monitor query performance and optimize

#### Common Pitfalls to Avoid
1. **Security Rules**: Always implement before production
2. **Infinite Listeners**: Properly dispose of Firestore listeners
3. **Overfetching**: Use proper pagination and filtering
4. **Image Size**: Always compress images before upload
5. **Offline Handling**: Consider offline scenarios for all operations

#### Debugging Tools
- Firebase Console for data inspection
- Flutter Inspector for widget debugging
- Firebase Emulator UI for local testing
- Chrome DevTools for web platform debugging

#### Performance Optimization Notes
- Use `StreamBuilder` for real-time data
- Implement proper pagination with `limit()` and `startAfter()`
- Cache frequently accessed data locally
- Use `keepSynced(true)` for critical offline data
- Optimize security rules for better performance

This implementation plan provides a comprehensive roadmap for migrating MedWave from mock data to a fully functional Firebase backend while maintaining data integrity, security, and user experience.
