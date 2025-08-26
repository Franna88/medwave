# MedWave Patient Profile Implementation Plan

## Overview
This document outlines the comprehensive implementation plan for all four sections of the Patient Profile screen, ensuring that all components display real data from session recordings and eliminating dummy/mock data throughout the system.

---

## Section Analysis & Implementation Requirements

### 🧑‍⚕️ **1. OVERVIEW TAB**

#### **Current Sub-sections:**
1. **Patient Info Card** - Patient basic demographics and contact
2. **Personal Details Card** - Extended personal information  
3. **Responsible Person Card** - Emergency contact and responsible party
4. **Medical Aid Card** - Insurance and medical aid details
5. **Medical History Card** - Pre-existing conditions and medications
6. **Consent Card** - Photography and treatment consents
7. **Progress Summary Card** - Quick metrics overview
8. **Current Status Card** - Latest session data and status
9. **Next Appointment Card** - Upcoming appointments

#### **Implementation Status:**
- ✅ **Patient Info Card** - Uses real patient data
- ✅ **Personal Details Card** - Uses real patient data  
- ✅ **Responsible Person Card** - Uses real patient data
- ✅ **Medical Aid Card** - Uses real patient data
- ✅ **Medical History Card** - Uses real patient data
- ✅ **Consent Card** - Uses real patient data
- ⚠️ **Progress Summary Card** - Partially uses real data but session count needs fix
- ⚠️ **Current Status Card** - Uses placeholder data for weight/VAS
- ❌ **Next Appointment Card** - Uses dummy appointment data

#### **Required Changes:**

##### **Progress Summary Card (Lines 1180-1272)**
```dart
// CURRENT ISSUE: Uses patient.sessions.length (old subcollection)
'Total Sessions': '${patient.sessions.length}'

// REQUIRED FIX: Use FutureBuilder with PatientService
FutureBuilder<List<Session>>(
  future: PatientService.getPatientSessions(patient.id),
  builder: (context, snapshot) {
    final sessionCount = snapshot.hasData ? snapshot.data!.length : 0;
    return _buildModernProgressIndicator(
      'Total Sessions',
      '$sessionCount',
      sessionCount / 20,
      AppTheme.infoColor,
      Icons.event_note_outlined,
    );
  },
)
```

##### **Current Status Card (Lines 1328-1455)**
```dart
// CURRENT ISSUE: Hardcoded placeholder values
Text('100.0 kg'), // Hardcoded weight
Text('3/10'), // Hardcoded VAS score

// REQUIRED FIX: Get latest session data
FutureBuilder<Session?>(
  future: PatientService.getLatestSession(patient.id),
  builder: (context, snapshot) {
    final latestSession = snapshot.data;
    return Column(
      children: [
        Text('${latestSession?.weight ?? patient.baselineWeight ?? 0.0} kg'),
        Text('${latestSession?.vasScore ?? patient.baselineVasScore ?? 0}/10'),
      ],
    );
  },
)
```

##### **Next Appointment Card (Lines 1456-1619)**
```dart
// CURRENT ISSUE: Uses dummy appointment logic
final hasAppointment = true; // Hardcoded
final appointmentDate = DateTime.now().add(Duration(days: 7)); // Dummy

// REQUIRED FIX: Integrate with appointment system
FutureBuilder<Appointment?>(
  future: AppointmentService.getNextAppointment(patient.id),
  builder: (context, snapshot) {
    final appointment = snapshot.data;
    final hasAppointment = appointment != null;
    // Display real appointment data or scheduling options
  },
)
```

---

### 📈 **2. PROGRESS TAB**

#### **Current Sub-sections:**
1. **Progress Summary Card** - High-level metrics overview
2. **Pain Chart** - VAS score progression over time
3. **Weight Chart** - Weight changes across sessions
4. **Wound Size Chart** - Wound healing progression  
5. **Treatment Timeline Card** - Session history timeline
6. **Goals and Milestones Card** - Treatment objectives

#### **Implementation Status:**
- ✅ **Progress Summary Card** - Uses calculated progress metrics
- ❌ **Pain Chart** - Shows "No pain data available" even with sessions
- ❌ **Weight Chart** - Shows "No weight data available" even with sessions  
- ❌ **Wound Size Chart** - Shows "No wound data available" even with sessions
- ❌ **Treatment Timeline Card** - Uses dummy timeline data
- ❌ **Goals and Milestones Card** - Uses hardcoded goals

#### **Root Problem:**
The `calculateProgress` method (lines 285-316) uses `patient.sessions` which is empty because sessions are now in the main collection, not the patient subcollection.

#### **Required Changes:**

##### **Update Progress Calculation (PatientProvider)**
```dart
// CURRENT ISSUE: Uses patient.sessions (empty list)
ProgressMetrics calculateProgress(String patientId) {
  final patient = _patients.firstWhere((p) => p.id == patientId);
  
  return ProgressMetrics(
    painHistory: patient.sessions.map(...), // Empty because sessions is []
    weightHistory: patient.sessions.map(...), // Empty
    woundSizeHistory: patient.sessions.map(...), // Empty
  );
}

// REQUIRED FIX: Fetch sessions from main collection
Future<ProgressMetrics> calculateProgress(String patientId) async {
  final patient = _patients.firstWhere((p) => p.id == patientId);
  final sessions = await PatientService.getPatientSessions(patientId);
  
  return ProgressMetrics(
    painHistory: sessions.map((session) => ProgressDataPoint(
      date: session.date,
      value: session.vasScore.toDouble(),
      sessionNumber: session.sessionNumber,
    )).toList(),
    weightHistory: sessions.map((session) => ProgressDataPoint(
      date: session.date,
      value: session.weight,
      sessionNumber: session.sessionNumber,
    )).toList(),
    woundSizeHistory: sessions.map((session) => ProgressDataPoint(
      date: session.date,
      value: session.wounds.fold(0.0, (sum, w) => sum + w.area),
      sessionNumber: session.sessionNumber,
    )).toList(),
  );
}
```

##### **Update Progress Tab to Use Async Data**
```dart
// CURRENT: Synchronous progress calculation
Widget _buildModernProgressTab(Patient patient, PatientProvider patientProvider) {
  ProgressMetrics? progress = patientProvider.calculateProgress(patient.id);
  
// REQUIRED: Asynchronous progress calculation  
Widget _buildModernProgressTab(Patient patient, PatientProvider patientProvider) {
  return FutureBuilder<ProgressMetrics>(
    future: patientProvider.calculateProgress(patient.id),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      
      final progress = snapshot.data;
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildProgressSummaryCard(patient, progress),
            _buildModernPainChart(progress.painHistory),
            _buildModernWeightChart(progress.weightHistory),
            _buildModernWoundSizeChart(progress.woundSizeHistory),
            _buildTreatmentTimelineCard(patient, progress.sessions),
            _buildGoalsAndMilestonesCard(patient, progress),
          ],
        ),
      );
    },
  );
}
```

##### **Fix Chart Components**
```dart
// CURRENT: Charts show "No data available" due to empty history
Widget _buildModernPainChart(List<ProgressDataPoint> painData) {
  if (painData.isEmpty) {
    return _buildNoDataCard('No pain data available');
  }
  // Chart implementation...
}

// REQUIRED: Ensure charts receive real data from sessions
// Charts are correctly implemented, issue is in data source
```

##### **Treatment Timeline Card**
```dart
// CURRENT: Uses dummy timeline data
final timelineEvents = [
  {'date': '2024-01-15', 'event': 'Initial Assessment', 'type': 'assessment'},
  {'date': '2024-01-22', 'event': 'First Treatment', 'type': 'treatment'},
]; // Hardcoded

// REQUIRED: Generate timeline from real sessions
Future<List<TimelineEvent>> _generateTimelineFromSessions(List<Session> sessions) {
  return sessions.map((session) => TimelineEvent(
    date: session.date,
    title: 'Session ${session.sessionNumber}',
    description: session.notes.isNotEmpty ? session.notes : 'Treatment session',
    type: 'treatment',
    vasScore: session.vasScore,
    weight: session.weight,
    woundCount: session.wounds.length,
  )).toList();
}
```

##### **Goals and Milestones Card**
```dart
// CURRENT: Hardcoded goals
final goals = [
  {'title': 'Pain Reduction', 'target': 'Reduce VAS by 50%', 'progress': 0.65},
  {'title': 'Wound Healing', 'target': 'Complete healing', 'progress': 0.40},
]; // Hardcoded

// REQUIRED: Calculate goals based on patient baseline and current status
Future<List<Goal>> _calculatePatientGoals(Patient patient, List<Session> sessions) {
  final latestSession = sessions.isNotEmpty ? sessions.last : null;
  
  return [
    Goal(
      title: 'Pain Reduction',
      target: 'Reduce VAS to ≤2',
      baseline: patient.baselineVasScore?.toDouble() ?? 10.0,
      current: latestSession?.vasScore.toDouble() ?? patient.baselineVasScore?.toDouble() ?? 10.0,
      targetValue: 2.0,
    ),
    Goal(
      title: 'Weight Stability',
      target: 'Maintain ±2kg',
      baseline: patient.baselineWeight ?? 70.0,
      current: latestSession?.weight ?? patient.baselineWeight ?? 70.0,
      targetRange: [patient.baselineWeight! - 2, patient.baselineWeight! + 2],
    ),
  ];
}
```

---

### 🗓️ **3. SESSIONS TAB**

#### **Current Sub-sections:**
1. **Session List** - Chronological list of all sessions
2. **Session Cards** - Individual session summaries with key metrics
3. **Empty State** - Guidance when no sessions exist
4. **Session Detail Navigation** - Links to detailed session views

#### **Implementation Status:**
- ✅ **Session List** - Uses FutureBuilder with PatientService.getPatientSessions
- ✅ **Session Cards** - Display real session data (weight, VAS, date, photos)
- ✅ **Empty State** - Proper messaging and call-to-action
- ✅ **Session Detail Navigation** - Working navigation to session details

#### **Current Implementation Quality:**
**EXCELLENT** - This section is fully implemented and working correctly with real data.

#### **Session Card Data Mapping:**
```dart
// Real data being displayed:
- Session Number: session.sessionNumber
- Date: DateFormat('MMM dd, yyyy').format(session.date)
- Weight: '${session.weight.toStringAsFixed(1)} kg'
- VAS Score: '${session.vasScore}/10'
- Photos Count: '${session.photos.length} photos'
- Wounds Count: '${session.wounds.length} wounds'
- Notes Preview: session.notes (truncated)
```

---

### 📸 **4. PHOTOS TAB**

#### **Current Sub-sections:**
1. **Photo Grid** - Gallery view of all patient photos
2. **Photo Categories** - Baseline, Session, and Wound photos
3. **Photo Cards** - Individual photo displays with metadata
4. **Empty State** - Guidance when no photos exist

#### **Implementation Status:**
- ⚠️ **Photo Grid** - Grid layout implemented but may not show real photos
- ❌ **Photo Categories** - Uses mock photo categorization
- ❌ **Photo Cards** - May not display real Firebase Storage URLs
- ✅ **Empty State** - Proper messaging

#### **Current Issues:**

##### **Photo Data Source Problem**
```dart
// CURRENT: Uses patient.sessions for photos (empty list)
List<PhotoItem> _buildPhotoItemsList(Patient patient) {
  List<PhotoItem> photoItems = [];
  
  // Baseline photos
  if (patient.baselinePhotos.isNotEmpty) {
    for (String photoPath in patient.baselinePhotos) {
      photoItems.add(PhotoItem(
        photoPath: photoPath,
        type: PhotoType.baseline,
        // ...
      ));
    }
  }
  
  // Session photos - BROKEN because patient.sessions is empty
  for (Session session in patient.sessions) {
    for (String photoPath in session.photos) {
      photoItems.add(PhotoItem(
        photoPath: photoPath,
        type: PhotoType.session,
        sessionNumber: session.sessionNumber,
        // ...
      ));
    }
  }
  
  return photoItems;
}
```

#### **Required Changes:**

##### **Fix Photo Data Source**
```dart
// REQUIRED: Fetch sessions for photos
Widget _buildModernPhotosTab(Patient patient) {
  return FutureBuilder<List<Session>>(
    future: PatientService.getPatientSessions(patient.id),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      
      final sessions = snapshot.data ?? [];
      final photoItems = _buildPhotoItemsList(patient, sessions);
      
      if (photoItems.isEmpty) {
        return _buildEmptyPhotoState();
      }
      
      return _buildPhotoGrid(photoItems);
    },
  );
}

List<PhotoItem> _buildPhotoItemsList(Patient patient, List<Session> sessions) {
  List<PhotoItem> photoItems = [];
  
  // Baseline photos
  for (String photoUrl in patient.baselinePhotos ?? []) {
    photoItems.add(PhotoItem(
      photoPath: photoUrl,
      type: PhotoType.baseline,
      timestamp: patient.createdAt ?? DateTime.now(),
      label: 'Baseline',
    ));
  }
  
  // Session photos
  for (Session session in sessions) {
    for (int i = 0; i < session.photos.length; i++) {
      photoItems.add(PhotoItem(
        photoPath: session.photos[i],
        type: PhotoType.session,
        timestamp: session.date,
        sessionNumber: session.sessionNumber,
        label: 'Session ${session.sessionNumber} - Photo ${i + 1}',
      ));
    }
  }
  
  // Sort by date (newest first)
  photoItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  
  return photoItems;
}
```

##### **Verify Photo URL Display**
```dart
// CURRENT: May not handle Firebase Storage URLs correctly
Widget _buildPhotoCard(PhotoItem photoItem) {
  return Container(
    child: Image.network(
      photoItem.photoPath, // Ensure this is a valid Firebase Storage URL
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: Icon(Icons.error),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(child: CircularProgressIndicator());
      },
    ),
  );
}
```

---

## Implementation Priority & Dependencies

### **Phase 1: Critical Data Flow Fixes**
1. **Update PatientProvider.calculateProgress** to use main sessions collection
2. **Fix Progress Tab** to use FutureBuilder for async progress calculation  
3. **Fix Photos Tab** to fetch sessions for photo display

### **Phase 2: Real Data Integration**
1. **Current Status Card** - Get latest session data
2. **Treatment Timeline** - Generate from real sessions
3. **Goals and Milestones** - Calculate from baseline vs current

### **Phase 3: Appointment Integration**
1. **Next Appointment Card** - Integrate with appointment system
2. **Create AppointmentService** if not exists

### **Phase 4: Data Validation & Testing**
1. **Test all tabs** with real session data
2. **Verify photo URLs** display correctly
3. **Validate progress calculations** are accurate

---

## New Service Requirements

### **AppointmentService** (if not exists)
```dart
class AppointmentService {
  static Future<Appointment?> getNextAppointment(String patientId) async;
  static Future<List<Appointment>> getPatientAppointments(String patientId) async;
  static Future<String> scheduleAppointment(String patientId, Appointment appointment) async;
}
```

### **Enhanced PatientService Methods**
```dart
class PatientService {
  static Future<Session?> getLatestSession(String patientId) async;
  static Future<Map<String, double>> getPatientBaselines(String patientId) async;
}
```

---

## Success Criteria

### **Overview Tab**
- [ ] Progress Summary shows correct session count from main collection
- [ ] Current Status displays latest session weight and VAS score
- [ ] Next Appointment shows real appointment data or scheduling option

### **Progress Tab**  
- [ ] Pain Chart displays actual VAS scores from sessions
- [ ] Weight Chart shows weight progression from sessions
- [ ] Wound Size Chart shows healing progression from sessions
- [ ] Treatment Timeline generated from real sessions
- [ ] Goals calculated from baseline vs current data

### **Sessions Tab**
- [x] Already fully functional with real data

### **Photos Tab**
- [ ] All session photos display correctly
- [ ] Photos show real Firebase Storage URLs
- [ ] Photo metadata shows correct session information
- [ ] Photos sorted chronologically

### **Overall**
- [ ] No hardcoded/dummy data anywhere in patient profile
- [ ] All components load real data from Firebase
- [ ] Proper loading states and error handling
- [ ] Performance optimized with appropriate caching

---

## Testing Checklist

1. **Create multiple sessions** for a patient with varying data
2. **Verify Overview tab** shows latest session data
3. **Check Progress tab** displays all charts with real data
4. **Confirm Photos tab** shows all session photos
5. **Test empty states** when no sessions/photos exist
6. **Validate calculations** are mathematically correct
7. **Check error handling** for network failures
8. **Test performance** with many sessions/photos

This implementation plan ensures the complete elimination of dummy data and establishes a robust, data-driven patient profile system that accurately reflects real patient progress and treatment history.
