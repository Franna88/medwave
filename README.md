# MedWave Provider App

A comprehensive Flutter application for medical practitioners to manage patients, track treatment progress, and generate reports. Built for MedWave medical services.

## Features

### 🏥 Dashboard
- **Real-time notifications** for patient improvements and alerts
- **Upcoming appointments** overview
- **Recently updated patients** with progress indicators
- **Quick stats** showing total patients, sessions, and improvements
- **Welcome card** with personalized greeting

### 👥 Patient Management
- **Patient List** with search, filtering, and sorting capabilities
- **Add New Patient** with comprehensive onboarding process:
  - Basic information (name, age, medical aid, contact details)
  - Baseline measurements (weight, VAS pain score)
  - Wound documentation with photos
  - Multi-step form with progress indicator
- **Patient Profile** with detailed view including:
  - Patient information and contact details
  - Progress summary with visual indicators
  - Current status (weight, pain score, wound details)
  - Treatment timeline and session history

### 📊 Session Logging
- **Comprehensive session recording** with:
  - Weight and VAS pain score tracking
  - Wound assessment with measurements
  - Photo documentation (camera/gallery)
  - Session notes and observations
  - Real-time comparison to baseline measurements
- **Progress indicators** showing improvement trends
- **Wound healing tracking** with size calculations

### 📈 Progress Visualization
- **Interactive charts** showing:
  - Pain score progression over time
  - Weight changes throughout treatment
  - Wound size reduction tracking
- **Progress metrics** with percentage improvements
- **Timeline view** of all treatment sessions
- **Photo gallery** with before/after comparisons

### 📋 Reports & Analytics
- **Overview Dashboard** with:
  - Treatment outcomes pie chart
  - Session distribution analysis
  - Recent achievements highlighting
- **Progress Analytics** including:
  - Average pain reduction trends
  - Weight change distributions
  - Treatment effectiveness metrics
- **Individual Patient Reports** with detailed progress summaries

## Technical Features

### 🎨 Design System
- **MedWave Brand Colors**:
  - Primary: #EC2B00 (Highlight)
  - Background: #FFFFFF
  - Text: #1A1A1A
  - Secondary: #353535
- **Poppins Font** from Google Fonts
- **Material Design 3** with custom theming
- **Responsive design** for various screen sizes

### 🏗️ Architecture
- **Provider Pattern** for state management
- **Go Router** for navigation and routing
- **Modular structure** with separate screens, models, and providers
- **Clean code architecture** with separation of concerns

### 📱 Core Technologies
- **Flutter 3.8.1+**
- **Google Fonts** for typography
- **FL Chart** for data visualization
- **Image Picker** for photo capture/selection
- **Provider** for state management
- **Go Router** for navigation
- **Intl** for date/time formatting

## Getting Started

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart SDK
- Android Studio or VS Code
- iOS/Android device or emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd medwave_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Project Structure

```
lib/
├── main.dart                 # App entry point
├── theme/
│   └── app_theme.dart       # App theme and styling
├── models/
│   ├── patient.dart         # Patient and wound models
│   ├── notification.dart    # Notification model
│   └── progress_metrics.dart # Progress tracking models
├── providers/
│   ├── patient_provider.dart      # Patient state management
│   └── notification_provider.dart # Notification state management
├── screens/
│   ├── main_screen.dart           # Main navigation wrapper
│   ├── dashboard/
│   │   └── dashboard_screen.dart  # Dashboard with overview
│   ├── patients/
│   │   ├── patient_list_screen.dart    # Patient listing
│   │   ├── add_patient_screen.dart     # New patient onboarding
│   │   └── patient_profile_screen.dart # Patient details & progress
│   ├── sessions/
│   │   └── session_logging_screen.dart # Session recording
│   └── reports/
│       └── reports_screen.dart    # Analytics and reports
└── images/                   # MedWave logo assets
```

## Key Features Implemented

### ✅ Patient Onboarding
- Multi-step form for comprehensive patient registration
- Baseline measurements collection
- Photo documentation system
- Form validation and error handling

### ✅ Session Management
- Real-time progress comparison
- Wound measurement tracking
- Photo capture integration
- Notes and observations

### ✅ Progress Tracking
- Visual progress indicators
- Chart-based analytics
- Improvement calculations
- Timeline visualization

### ✅ Notifications System
- Automated improvement alerts
- Appointment reminders
- Priority-based notifications
- Real-time updates

### ✅ Reports & Analytics
- Treatment outcome analysis
- Session effectiveness metrics
- Patient progress summaries
- Visual data representation

## Sample Data

The app includes comprehensive sample data for demonstration:
- **3 sample patients** with realistic medical data
- **Multiple treatment sessions** showing progress over time
- **Various wound types** and healing stages
- **Notification examples** for different scenarios

## Future Enhancements

- **PDF Report Generation** for insurance/motivation letters
- **Data Export** functionality
- **Appointment Scheduling** system
- **Multi-practitioner Support**
- **Cloud Synchronization**
- **Advanced Analytics** with ML insights

## License

This project is developed for MedWave medical services. All rights reserved.

## Support

For technical support or feature requests, please contact the development team.
