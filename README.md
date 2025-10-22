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
- Node.js (for proxy server and Firebase Functions)

### Installation

> ⚠️ **IMPORTANT**: This project uses sensitive API keys and credentials that are NOT included in the repository for security reasons. Follow the complete setup guide below.

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd medwave
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API Keys and Secrets**
   
   The project requires several configuration files. See the complete [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions.
   
   Quick setup checklist:
   - [ ] Copy and configure `lib/config/api_keys.dart` from template
   - [ ] Copy and configure `lib/firebase_options.dart` from template
   - [ ] Set up `ghl-proxy/.env` for the proxy server
   - [ ] Set up `functions/.env` for Firebase Functions (local dev)
   - [ ] Configure `android/key.properties` for Android builds (if needed)

4. **Start required services** (for full functionality)
   
   **Proxy Server** (for GoHighLevel integration):
   ```bash
   cd ghl-proxy
   npm install
   npm start
   ```
   
   **Firebase Functions** (optional, for local testing):
   ```bash
   cd functions
   npm install
   firebase emulators:start --only functions
   ```

5. **Run the Flutter app**
   ```bash
   flutter run
   ```

### 🔒 Security Notice

This project handles sensitive medical data and API credentials. **Please ensure**:
- ✅ Never commit API keys or credentials to git
- ✅ All `.env` files are gitignored and kept local only
- ✅ Firebase Admin SDK keys are stored securely
- ✅ Follow the security guidelines in [SETUP_GUIDE.md](SETUP_GUIDE.md)

For detailed security configuration, see:
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Complete setup instructions
- [FIREBASE_ADMIN_SDK_SETUP.md](FIREBASE_ADMIN_SDK_SETUP.md) - Firebase Admin SDK security

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
