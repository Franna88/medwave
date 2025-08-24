# MedWave System Context & Architecture Documentation

## System Overview

MedWave is a comprehensive wound care management application designed for healthcare professionals. The system tracks patient wound healing progress, manages treatment sessions, schedules appointments, and generates detailed progress reports.

## Current Architecture

### Technology Stack
- **Frontend**: Flutter (Dart)
- **State Management**: Provider pattern
- **Navigation**: GoRouter
- **Charts & Visualization**: FL Chart
- **Calendar**: Table Calendar
- **Image Handling**: Image Picker
- **PDF Generation**: PDF package
- **Date/Time**: Intl package
- **Data Format**: JSON serialization

### Key Features
1. **Patient Management**: Complete patient records with comprehensive intake forms
2. **Wound Tracking**: Detailed wound measurements, photos, and staging
3. **Session Logging**: Treatment session documentation with progress tracking
4. **Appointment Scheduling**: Calendar-based appointment management
5. **Progress Analytics**: Charts and metrics for wound healing progress
6. **Multilingual Support**: English/Afrikaans localization
7. **Reports Generation**: Comprehensive progress reports and analytics
8. **Notification System**: Treatment alerts and progress notifications

## Data Models

### Core Models

#### 1. Patient Model
```dart
class Patient {
  // Personal Information
  String id, surname, fullNames, idNumber, patientCell, email
  DateTime dateOfBirth
  String? maritalStatus, occupation
  
  // Responsible Person (can be same as patient)
  String responsiblePersonSurname, responsiblePersonFullNames
  String responsiblePersonIdNumber, responsiblePersonCell
  DateTime responsiblePersonDateOfBirth
  
  // Medical Aid
  String medicalAidSchemeName, medicalAidNumber, mainMemberName
  String? planAndDepNumber
  
  // Medical History
  Map<String, bool> medicalConditions
  Map<String, String?> medicalConditionDetails
  String? currentMedications, allergies, naturalTreatments
  bool isSmoker
  
  // Consent & Signatures
  String? accountResponsibilitySignature, woundPhotographyConsentSignature
  String? witnessSignature
  DateTime? accountResponsibilitySignatureDate, woundPhotographyConsentDate
  bool? trainingPhotosConsent
  DateTime? trainingPhotosConsentDate
  
  // Baseline Data
  double baselineWeight
  int baselineVasScore
  List<Wound> baselineWounds
  List<String> baselinePhotos
  
  // Current Data
  double? currentWeight
  int? currentVasScore
  List<Wound> currentWounds
  
  // Session History
  List<Session> sessions
  
  // Timestamps
  DateTime createdAt
  DateTime? lastUpdated
}
```

#### 2. Wound Model
```dart
class Wound {
  String id, location, type, description
  double length, width, depth  // in cm
  List<String> photos
  DateTime assessedAt
  WoundStage stage
  
  // Calculated properties
  double get area => length * width
  double get volume => length * width * depth
}

enum WoundStage {
  stage1, stage2, stage3, stage4, unstageable, deepTissueInjury
}
```

#### 3. Session Model
```dart
class Session {
  String id, patientId, practitionerId
  int sessionNumber
  DateTime date
  double weight
  int vasScore  // Visual Analog Scale (0-10)
  List<Wound> wounds
  String notes
  List<String> photos
}
```

#### 4. Appointment Model
```dart
class Appointment {
  String id, patientId, patientName, title
  String? description, practitionerId, practitionerName, location
  DateTime startTime, endTime
  AppointmentType type
  AppointmentStatus status
  List<String> notes
  DateTime createdAt
  DateTime? lastUpdated
  String? reminderSent
  Map<String, dynamic>? metadata
}

enum AppointmentType {
  consultation, followUp, treatment, assessment, emergency
}

enum AppointmentStatus {
  scheduled, confirmed, inProgress, completed, cancelled, noShow, rescheduled
}
```

#### 5. Notification Model
```dart
class AppNotification {
  String id, title, message
  NotificationType type
  NotificationPriority priority
  DateTime createdAt
  bool isRead
  String? patientId, patientName
  Map<String, dynamic>? data
}

enum NotificationType {
  appointment, improvement, reminder, alert
}

enum NotificationPriority {
  low, medium, high, urgent
}
```

#### 6. Progress Metrics Model
```dart
class ProgressMetrics {
  String patientId
  DateTime calculatedAt
  double painReductionPercentage
  double weightChangePercentage
  double woundHealingPercentage
  int totalSessions
  List<ProgressDataPoint> painHistory
  List<ProgressDataPoint> weightHistory
  List<ProgressDataPoint> woundSizeHistory
  bool hasSignificantImprovement
  String improvementSummary
}

class ProgressDataPoint {
  DateTime date
  double value
  int sessionNumber
  String? notes
}
```

## Screen Architecture

### Authentication Flow
1. **WelcomeScreen**: Landing page with feature overview
2. **LoginScreen**: Email/password authentication
3. **SignupScreen**: Multi-step registration form

### Main Application Flow
1. **MainScreen**: Shell with navigation sidebar
2. **DashboardScreen**: Overview with statistics and notifications
3. **PatientListScreen**: Patient management with search/filter
4. **AddPatientScreen**: Multi-page patient intake form
5. **PatientProfileScreen**: Individual patient details
6. **SessionLoggingScreen**: Treatment session documentation
7. **SessionDetailScreen**: Individual session details
8. **CalendarScreen**: Appointment scheduling and management
9. **ReportsScreen**: Analytics and progress reports
10. **NotificationsScreen**: System notifications
11. **ProfileScreen**: User profile and settings

### State Management (Provider Pattern)

#### 1. AuthProvider
- User authentication state
- Login/logout functionality
- User session management

#### 2. PatientProvider
- Patient CRUD operations
- Patient filtering and search
- Progress calculations
- Session management

#### 3. AppointmentProvider
- Appointment CRUD operations
- Calendar integration
- Scheduling conflicts detection
- Appointment filtering

#### 4. NotificationProvider
- Notification management
- Read/unread state
- Automatic notifications generation
- Priority-based sorting

#### 5. UserProfileProvider
- User profile management
- App settings
- Preferences storage

## Current Data Storage (Mock Implementation)

All data is currently stored in-memory using mock data generators:

### Mock Data Features:
- Sample patients with realistic data
- Generated appointments and sessions
- Calculated progress metrics
- Simulated notifications
- Temporary image placeholders

### Data Persistence:
- No actual persistence currently
- Data resets on app restart
- Suitable for development/demo only

## Key Business Logic

### Progress Calculation
- **Pain Reduction**: `(baseline_vas - current_vas) / baseline_vas * 100`
- **Weight Change**: `(current_weight - baseline_weight) / baseline_weight * 100`
- **Wound Healing**: Based on wound area reduction over time
- **Improvement Threshold**: >20% pain reduction or >30% wound healing

### Notification Triggers
- Significant progress improvements (>30% pain reduction)
- Wound healing milestones (>40% healing)
- Missed appointments (compliance alerts)
- Assessment due dates
- Urgent patient status changes

### Session Workflow
1. Patient selection
2. Weight measurement
3. Pain assessment (VAS score)
4. Wound documentation with photos
5. Treatment notes
6. Progress calculation
7. Automatic notification generation

## Responsive Design

### Screen Size Adaptations:
- **Mobile**: Single column layouts, stacked components
- **Tablet**: Two-column layouts, side-by-side content
- **Desktop**: Multi-column dashboards, expanded views

### Navigation Patterns:
- **Mobile**: Bottom navigation + drawer
- **Tablet/Desktop**: Persistent sidebar navigation

## Localization

### Supported Languages:
- English (default)
- Afrikaans

### Localized Elements:
- UI text and labels
- Form validation messages
- Progress reports
- Notification content

## File Structure

```
lib/
├── main.dart                 # App entry point & routing
├── models/                   # Data models
├── providers/                # State management
├── screens/                  # UI screens
│   ├── auth/                # Authentication screens
│   ├── calendar/            # Appointment management
│   ├── dashboard/           # Overview dashboard
│   ├── notifications/       # Notification center
│   ├── patients/           # Patient management
│   ├── reports/            # Analytics & reports
│   └── sessions/           # Session logging
├── services/               # Business logic services
├── theme/                  # UI styling
├── utils/                  # Utilities & helpers
└── widgets/                # Reusable components
```

## Integration Points for Firebase

### Required Firebase Services:
1. **Firebase Auth**: User authentication
2. **Cloud Firestore**: Real-time database
3. **Firebase Storage**: Image/file storage
4. **Cloud Functions**: Server-side logic
5. **FCM**: Push notifications
6. **Analytics**: Usage tracking

### Data Migration Requirements:
- User authentication system
- Patient data with relationships
- Session and appointment data
- Image storage for wound photos
- Real-time synchronization
- Offline capability

## Security Considerations

### Data Protection:
- Patient data encryption
- HIPAA compliance requirements
- Access control and permissions
- Audit trail logging
- Secure image storage

### Authentication:
- Multi-factor authentication
- Session management
- Role-based access control
- Password policies

## Performance Requirements

### Expected Load:
- 100+ patients per practitioner
- 10+ sessions per patient
- Real-time data synchronization
- Image upload/download
- Report generation

### Optimization Needs:
- Image compression
- Lazy loading
- Pagination for large datasets
- Caching strategies
- Offline data access

## Developer Implementation Notes

### Critical Implementation Order
1. **Start with Authentication** - This unlocks user-specific data access
2. **Patient Provider** - Core entity that other features depend on
3. **Appointment Provider** - Depends on patients being implemented
4. **Session Logging** - Requires both patients and appointments
5. **Reports** - Final layer that aggregates all data

### Key Technical Considerations for Implementation
- **User Context**: Every data operation must include the current user's ID for proper data isolation
- **Error Boundaries**: Each provider needs comprehensive error handling with user-friendly messages
- **Loading States**: All async operations need proper loading indicators
- **Offline Support**: Consider implementing local caching for critical operations
- **Data Validation**: Client-side validation must match Firestore security rules

### Mock Data Removal Strategy
- Keep mock data as fallback during development
- Use feature flags to switch between mock and Firebase data
- Remove mock data only after complete testing of Firebase implementation

### Testing Approach
- Test each provider independently before integration
- Use Firebase Emulator Suite for local testing
- Implement proper error scenarios testing

### Provider Migration Pattern
Each provider should follow this pattern:
1. Create Firebase service layer
2. Add loading/error states
3. Implement data transformation
4. Add offline caching if needed
5. Replace mock data calls
6. Add comprehensive error handling

### Critical Firebase Considerations
- **Security Rules**: Must enforce user isolation and data privacy
- **Indexes**: Required for complex queries (especially in reports)
- **Storage Rules**: Strict access control for patient photos
- **Functions**: Server-side validation and automated notifications
- **Triggers**: Automatic progress calculation and notification generation

This documentation provides the complete context for implementing Firebase integration while maintaining the existing functionality and user experience.
