# Practitioner Registration & Patient Onboarding - Web Desktop Version

## Overview

This document provides comprehensive technical documentation for the Practitioner Registration and Patient Onboarding systems in the MedWave wound care management application. The web desktop version is built using Flutter Web and integrates with Firebase for authentication, data storage, and real-time synchronization.

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Practitioner Registration](#practitioner-registration)
3. [Patient Onboarding](#patient-onboarding)
4. [Firebase Collections & Data Structure](#firebase-collections--data-structure)
5. [Current Firebase Queries](#current-firebase-queries)
6. [Form Structures & Validation](#form-structures--validation)
7. [Authentication Flow](#authentication-flow)
8. [Data Storage & Security](#data-storage--security)
9. [Implementation Guide](#implementation-guide)
10. [API Reference](#api-reference)

---

## System Architecture

The MedWave application uses a modern Flutter-based architecture with Firebase as the backend infrastructure:

- **Frontend**: Flutter Web (responsive design for desktop/tablet)
- **Backend**: Firebase (Firestore, Auth, Storage, Functions)
- **State Management**: Provider pattern with reactive updates
- **Authentication**: Firebase Auth with email/password
- **Database**: Cloud Firestore with real-time synchronization
- **File Storage**: Firebase Storage for signatures and documents

### Key Components

```
lib/
├── models/              # Data models (Patient, UserProfile, etc.)
├── providers/           # State management (AuthProvider, PatientProvider)
├── services/            # Firebase services and API calls
├── screens/             # UI screens and forms
└── widgets/             # Reusable UI components
```

---

## Practitioner Registration

### Registration Flow

The practitioner registration process is a multi-step form that collects professional credentials and location information for approval workflow.

#### Form Structure (3 Steps)

1. **Personal Information**
   - First Name, Last Name
   - Email (used for authentication)
   - Password (minimum 8 characters)
   - Phone Number

2. **Professional Information**
   - License Number
   - Specialization (dropdown with 20+ options)
   - Years of Experience
   - Practice Location

3. **Location Information**
   - Country (dropdown with 10 countries)
   - Province/State
   - City
   - Physical Address
   - Postal Code

#### Data Model

```dart
class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String licenseNumber;
  final String specialization;
  final int yearsOfExperience;
  final String practiceLocation;
  
  // Location Information
  final String country;
  final String countryName;
  final String province;
  final String city;
  final String address;
  final String postalCode;
  
  // Approval Workflow
  final String accountStatus; // 'pending', 'approved', 'rejected', 'suspended'
  final DateTime? applicationDate;
  final DateTime? approvalDate;
  final String? approvedBy;
  final bool licenseVerified;
  
  // Settings and Metadata
  final UserSettings settings;
  final DateTime createdAt;
  final String role; // 'practitioner', 'super_admin'
  final int totalPatients;
  final int totalSessions;
}
```

#### Firebase Collections Used

1. **`users` Collection**: Stores practitioner profiles
2. **`practitionerApplications` Collection**: Tracks application workflow

---

## Patient Onboarding

### Patient Intake Form

The patient onboarding process captures comprehensive medical and demographic information through a structured intake form.

#### Form Sections

1. **Patient Details**
   - Surname, Full Names
   - ID Number (SA format validation)
   - Date of Birth
   - Contact Information (cell, email, work details)
   - Marital Status, Occupation

2. **Responsible Person Information**
   - Complete contact details for account holder
   - Relationship to patient
   - Work and personal information

3. **Medical Aid Details**
   - Scheme Name
   - Membership Number
   - Plan and DEP Number
   - Main Member Name

4. **Referring Doctor Information**
   - Doctor Name and Contact
   - Additional referrer details (optional)

5. **Medical History**
   - Pre-existing conditions (heart, lungs, diabetes, etc.)
   - Current medications
   - Allergies
   - Smoking status
   - Natural/herbal treatments

6. **Consent & Signatures**
   - Account responsibility agreement
   - Wound photography consent
   - Training photo consent (optional)
   - Digital signatures with timestamps

#### Patient Data Model

```dart
class Patient {
  final String id;
  
  // Basic Information
  final String surname;
  final String fullNames;
  final String idNumber;
  final DateTime dateOfBirth;
  final String patientCell;
  final String email;
  final String? maritalStatus;
  
  // Responsible Person
  final String responsiblePersonSurname;
  final String responsiblePersonFullNames;
  final String responsiblePersonIdNumber;
  final DateTime responsiblePersonDateOfBirth;
  final String responsiblePersonCell;
  final String? relationToPatient;
  
  // Medical Aid
  final String medicalAidSchemeName;
  final String medicalAidNumber;
  final String mainMemberName;
  
  // Medical History
  final Map<String, bool> medicalConditions;
  final Map<String, String?> medicalConditionDetails;
  final String? currentMedications;
  final String? allergies;
  final bool isSmoker;
  
  // Signatures & Consent
  final String? accountResponsibilitySignature;
  final DateTime? accountResponsibilitySignatureDate;
  final String? woundPhotographyConsentSignature;
  final bool? trainingPhotosConsent;
  
  // Firebase Metadata
  final String practitionerId;
  final String? country; // Inherited from practitioner
  final DateTime createdAt;
  
  // Clinical Data
  final double baselineWeight;
  final int baselineVasScore;
  final List<Wound> baselineWounds;
  final List<Session> sessions;
}
```

---

## Firebase Collections & Data Structure

### Core Collections

#### 1. `users/{userId}`
Stores practitioner profile and authentication data.

```javascript
{
  firstName: "John",
  lastName: "Smith", 
  email: "john.smith@clinic.com",
  phoneNumber: "+27821234567",
  licenseNumber: "PR0168238",
  specialization: "Wound Care Specialist",
  yearsOfExperience: 15,
  practiceLocation: "Cape Town Medical Centre",
  
  // Location data for analytics
  country: "ZA",
  countryName: "South Africa", 
  province: "Western Cape",
  city: "Cape Town",
  address: "123 Medical Street",
  postalCode: "8001",
  
  // Approval workflow
  accountStatus: "approved", // 'pending' | 'approved' | 'rejected'
  applicationDate: timestamp,
  approvalDate: timestamp,
  licenseVerified: true,
  
  // Settings
  settings: {
    notificationsEnabled: true,
    darkModeEnabled: false,
    language: "en",
    timezone: "Africa/Johannesburg"
  },
  
  // Metadata
  role: "practitioner",
  totalPatients: 45,
  totalSessions: 180,
  createdAt: timestamp,
  lastUpdated: timestamp
}
```

#### 2. `practitionerApplications/{applicationId}`
Tracks the application approval workflow.

```javascript
{
  userId: "user123",
  email: "john.smith@clinic.com",
  firstName: "John",
  lastName: "Smith",
  licenseNumber: "PR0168238",
  specialization: "Wound Care Specialist",
  country: "ZA",
  province: "Western Cape",
  
  status: "approved", // 'pending' | 'approved' | 'rejected'
  submittedAt: timestamp,
  approvedAt: timestamp,
  approvedBy: "super_admin_user_id",
  
  // Document verification
  documentsVerified: true,
  licenseVerified: true,
  referencesVerified: false
}
```

#### 3. `patients/{patientId}`
Stores comprehensive patient information.

```javascript
{
  id: "patient123",
  surname: "Johnson",
  fullNames: "Mary Elizabeth Johnson",
  idNumber: "8501234567890",
  dateOfBirth: timestamp,
  patientCell: "+27821234567",
  email: "mary.johnson@email.com",
  maritalStatus: "Married",
  
  // Responsible person
  responsiblePersonSurname: "Johnson",
  responsiblePersonFullNames: "Mary Elizabeth Johnson",
  responsiblePersonIdNumber: "8501234567890",
  responsiblePersonDateOfBirth: timestamp,
  responsiblePersonCell: "+27821234567",
  relationToPatient: "Self",
  
  // Medical aid
  medicalAidSchemeName: "Discovery Health",
  medicalAidNumber: "1234567890",
  mainMemberName: "Mary Johnson",
  
  // Medical history
  medicalConditions: {
    heart: false,
    lungs: false,
    diabetes: true,
    cancer: false,
    hiv: false
  },
  medicalConditionDetails: {
    diabetes: "Type 2, controlled with medication"
  },
  currentMedications: "Metformin 500mg twice daily",
  allergies: "Penicillin",
  isSmoker: false,
  
  // Consent & signatures (Firebase Storage URLs)
  accountResponsibilitySignature: "https://storage.googleapis.com/...",
  accountResponsibilitySignatureDate: timestamp,
  woundPhotographyConsentSignature: "https://storage.googleapis.com/...",
  trainingPhotosConsent: true,
  
  // Firebase metadata
  practitionerId: "user123",
  country: "ZA", // Inherited from practitioner
  countryName: "South Africa",
  province: "Western Cape",
  createdAt: timestamp,
  lastUpdated: timestamp,
  
  // Clinical baseline data
  baselineWeight: 70.5,
  baselineVasScore: 7,
  baselineWounds: [...], // Array of wound objects
  currentWeight: 68.2,
  currentVasScore: 4
}
```

#### 4. `patients/{patientId}/sessions/{sessionId}`
Tracks individual treatment sessions.

```javascript
{
  sessionNumber: 3,
  date: timestamp,
  weight: 68.2,
  vasScore: 4,
  wounds: [...], // Current wound state
  notes: "Good healing progress, reduced exudate",
  photos: ["https://storage.googleapis.com/..."], // Storage URLs
  practitionerId: "user123",
  createdAt: timestamp
}
```

---

## Current Firebase Queries

### Authentication Queries

#### User Registration
```dart
// Create Firebase Auth user
final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: signupData['email'],
  password: signupData['password'],
);

// Create user profile in Firestore
await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
  'firstName': signupData['firstName'],
  'lastName': signupData['lastName'],
  'email': signupData['email'],
  'phoneNumber': signupData['phoneNumber'],
  'licenseNumber': signupData['licenseNumber'],
  'specialization': signupData['specialization'],
  'yearsOfExperience': signupData['yearsOfExperience'],
  'practiceLocation': signupData['practiceLocation'],
  'country': signupData['country'],
  'countryName': signupData['countryName'],
  'province': signupData['province'],
  'city': signupData['city'],
  'address': signupData['address'],
  'postalCode': signupData['postalCode'],
  'accountStatus': autoApprovePractitioners ? 'approved' : 'pending',
  'applicationDate': FieldValue.serverTimestamp(),
  'approvalDate': autoApprovePractitioners ? FieldValue.serverTimestamp() : null,
  'role': 'practitioner',
  'licenseVerified': autoApprovePractitioners,
  'professionalReferences': [],
  'settings': {
    'notificationsEnabled': true,
    'darkModeEnabled': false,
    'biometricEnabled': false,
    'language': 'en',
    'timezone': 'UTC',
  },
  'totalPatients': 0,
  'totalSessions': 0,
  'createdAt': FieldValue.serverTimestamp(),
  'lastUpdated': FieldValue.serverTimestamp(),
});

// Create practitioner application for approval workflow
await FirebaseFirestore.instance.collection('practitionerApplications').add({
  'userId': credential.user!.uid,
  'email': signupData['email'],
  'firstName': signupData['firstName'],
  'lastName': signupData['lastName'],
  'licenseNumber': signupData['licenseNumber'],
  'specialization': signupData['specialization'],
  'yearsOfExperience': signupData['yearsOfExperience'],
  'practiceLocation': signupData['practiceLocation'],
  'country': signupData['country'],
  'countryName': signupData['countryName'],
  'province': signupData['province'],
  'city': signupData['city'],
  'status': autoApprovePractitioners ? 'approved' : 'pending',
  'submittedAt': FieldValue.serverTimestamp(),
  'approvedAt': autoApprovePractitioners ? FieldValue.serverTimestamp() : null,
  'approvedBy': autoApprovePractitioners ? 'auto-system' : null,
  'documents': {},
  'documentsVerified': autoApprovePractitioners,
  'licenseVerified': autoApprovePractitioners,
  'referencesVerified': false,
});
```

#### User Login
```dart
final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);

// Load user profile
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(credential.user!.uid)
    .get();
    
if (doc.exists) {
  final userProfile = UserProfile.fromFirestore(doc);
  // Check account status and proceed
}
```

### Patient Management Queries

#### Create Patient
```dart
static Future<String> createPatient(Patient patient) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) throw Exception('User not authenticated');

  // Get practitioner location data for inheritance
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
  final userData = userDoc.data() as Map<String, dynamic>;

  // Create patient with inherited location data
  final patientData = patient.copyWith(
    practitionerId: userId,
    country: userData['country'],
    countryName: userData['countryName'],
    province: userData['province'],
    createdAt: DateTime.now(),
    lastUpdated: DateTime.now(),
  );

  final docRef = await FirebaseFirestore.instance
      .collection('patients')
      .add(patientData.toFirestore());
  
  // Update document with its own ID
  await docRef.update({'id': docRef.id});
  
  return docRef.id;
}
```

#### Get Practitioner's Patients
```dart
static Stream<List<Patient>> getPatientsStream() {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('patients')
      .where('practitionerId', isEqualTo: userId)
      .orderBy('lastUpdated', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Patient.fromFirestore(doc))
          .toList());
}
```

#### Get Patient Sessions
```dart
static Stream<List<Session>> getPatientSessionsStream(String patientId) {
  return FirebaseFirestore.instance
      .collection('patients')
      .doc(patientId)
      .collection('sessions')
      .orderBy('sessionNumber', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Session.fromFirestore(doc))
          .toList());
}
```

### Practitioner Service Queries

#### Get Current Practitioner Details
```dart
static Future<PractitionerApplication?> getCurrentPractitionerDetails() async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return null;

  final querySnapshot = await FirebaseFirestore.instance
      .collection('practitionerApplications')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'approved')
      .limit(1)
      .get();

  if (querySnapshot.docs.isEmpty) return null;

  return PractitionerApplication.fromFirestore(querySnapshot.docs.first);
}
```

---

## Form Structures & Validation

### Practitioner Registration Form

#### Validation Rules
- **Email**: Valid email format, unique in Firebase Auth
- **Password**: Minimum 8 characters, confirmed
- **Phone**: International format with country code
- **License Number**: Required, alphanumeric
- **Location**: All address fields required for approval

#### Form Implementation
```dart
class SignupScreen extends StatefulWidget {
  // Multi-step form with 3 pages
  // Page 1: Personal Information
  // Page 2: Professional Information  
  // Page 3: Location Information
  
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;
  
  // Controllers for each field...
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  // ... etc
}
```

### Patient Intake Form

#### Validation Rules
- **ID Number**: South African ID format (13 digits)
- **Required Fields**: Name, surname, ID, DOB, cell number
- **Medical Aid**: Scheme name and membership number required
- **Signatures**: Digital signatures required for consent
- **Conditional Fields**: Medical condition details if condition selected

#### Form Sections
```dart
class AddPatientScreen extends StatefulWidget {
  // Multi-page form with sections:
  // 1. Patient Details
  // 2. Responsible Person  
  // 3. Medical Aid
  // 4. Medical History
  // 5. Consent & Signatures
  
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  
  // Digital signature pads
  final GlobalKey _accountSignatureKey = GlobalKey();
  final GlobalKey _woundConsentSignatureKey = GlobalKey();
}
```

#### Signature Capture
```dart
// Digital signature implementation
Widget _buildSignaturePad() {
  return SignaturePad(
    key: _accountSignatureKey,
    width: 400,
    height: 200,
    onSignatureChanged: (Uint8List? signature) {
      setState(() {
        _accountSignatureBytes = signature;
      });
    },
  );
}
```

### Field Mapping & Auto-Population

Patient intake data auto-populates wound care motivation forms:

```json
{
  "auto_populate_mapping": {
    "patient_name": {
      "source": "patient_details.full_names",
      "target": "motivation_form.patient_name"
    },
    "medical_aid": {
      "source": "medical_aid_details.scheme_name",
      "target": "motivation_form.medical_aid"
    },
    "referring_doctor": {
      "source": "referring_doctor.doctor_name", 
      "target": "motivation_form.referring_doctor"
    }
  }
}
```

---

## Authentication Flow

### Registration Process

1. **Form Submission**: Multi-step form validates all fields
2. **Firebase Auth**: Create user account with email/password
3. **Profile Creation**: Store practitioner data in Firestore `users` collection
4. **Application Workflow**: Create entry in `practitionerApplications` collection
5. **Approval Status**: Account marked as 'pending' or 'approved' based on configuration
6. **Email Verification**: Optional email verification flow

### Login Process

1. **Credentials**: Email/password authentication via Firebase Auth
2. **Profile Loading**: Fetch user profile from Firestore
3. **Status Check**: Verify account status ('approved' required for access)
4. **Session Management**: Maintain authentication state with Provider
5. **Navigation**: Route to appropriate dashboard based on role

### Access Control

```dart
// Navigation guard checking authentication and approval
bool get canAccessApp {
  return isAuthenticated && 
         userProfile != null && 
         userProfile!.accountStatus == 'approved';
}

// Role-based access
bool get isSuperAdmin => userProfile?.role == 'super_admin';
bool get isPractitioner => userProfile?.role == 'practitioner';
```

---

## Data Storage & Security

### Firebase Security Rules

Current rules are permissive for development:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Production Security Rules (Recommended)

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
    
    function isApprovedPractitioner() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.accountStatus == 'approved';
    }
    
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if isOwner(userId);
    }
    
    // Patients can only be accessed by their practitioner
    match /patients/{patientId} {
      allow read, write: if isApprovedPractitioner() && 
                           resource.data.practitionerId == request.auth.uid;
    }
    
    // Sessions subcollection follows patient access rules
    match /patients/{patientId}/sessions/{sessionId} {
      allow read, write: if isApprovedPractitioner() && 
                           get(/databases/$(database)/documents/patients/$(patientId)).data.practitionerId == request.auth.uid;
    }
  }
}
```

### Data Privacy & Compliance

- **POPIA Compliance**: South African data protection compliance
- **Medical Data**: Encrypted at rest and in transit
- **Signature Storage**: Firebase Storage with secure URLs
- **Access Logging**: Audit trail for data access
- **Data Retention**: Configurable retention policies

---

## Implementation Guide

### Setting Up the Web Desktop Version

#### 1. Environment Setup

```bash
# Clone repository
git clone <repository-url>
cd medwave

# Install dependencies
flutter pub get

# Configure Firebase
# - Add firebase_options.dart from template
# - Configure web app in Firebase Console
# - Enable Authentication and Firestore
```

#### 2. Firebase Configuration

```dart
// lib/firebase_options.dart
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'your-api-key',
    appId: 'your-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
    authDomain: 'your-project.firebaseapp.com',
    storageBucket: 'your-project.appspot.com',
  );
}
```

#### 3. Provider Setup

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => PatientProvider()),
      ],
      child: const MedWaveApp(),
    ),
  );
}
```

#### 4. Routing Configuration

```dart
// Router setup with authentication guards
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) {
        final authProvider = context.read<AuthProvider>();
        if (!authProvider.isAuthenticated) return '/login';
        if (!authProvider.canAccessApp) return '/pending-approval';
        return '/dashboard';
      },
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/add-patient',
      builder: (context, state) => const AddPatientScreen(),
    ),
  ],
);
```

### Deployment

#### Build for Web

```bash
# Build optimized web version
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

#### Environment Variables

```javascript
// firebase.json hosting configuration
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

---

## API Reference

### AuthProvider Methods

```dart
class AuthProvider extends ChangeNotifier {
  // Authentication
  Future<bool> login(String email, String password)
  Future<bool> signup(Map<String, dynamic> signupData)
  Future<void> logout()
  Future<bool> resetPassword(String email)
  
  // User state
  bool get isAuthenticated
  bool get canAccessApp
  UserProfile? get userProfile
  
  // Loading states
  bool get isLoading
  String? get error
}
```

### PatientService Methods

```dart
class PatientService {
  // Patient management
  static Future<String> createPatient(Patient patient)
  static Future<Patient?> getPatient(String patientId)
  static Future<void> updatePatient(String patientId, Patient patient)
  static Future<void> deletePatient(String patientId)
  static Stream<List<Patient>> getPatientsStream()
  
  // Sessions
  static Future<String> createSession(String patientId, Session session)
  static Stream<List<Session>> getPatientSessionsStream(String patientId)
}
```

### PractitionerService Methods

```dart
class PractitionerService {
  // Practitioner info
  static Future<PractitionerApplication?> getCurrentPractitionerDetails()
  static Future<String> getPractitionerName()
  static Future<String> getPractitionerLicenseNumber()
  static Future<Map<String, String?>> getPractitionerInfo()
}
```

---

## Conclusion

This comprehensive documentation covers the complete implementation of Practitioner Registration and Patient Onboarding for the MedWave web desktop application. The system leverages Firebase for scalable, secure data management while providing a responsive Flutter Web interface optimized for desktop workflows.

Key features include:
- Multi-step registration with professional verification
- Comprehensive patient intake with digital signatures
- Real-time data synchronization
- Approval workflows for practitioner applications
- Secure medical data handling with POPIA compliance
- Auto-population between related forms
- Role-based access control

For additional support or implementation questions, refer to the existing codebase documentation or contact the development team.
