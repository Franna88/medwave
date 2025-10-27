import 'package:flutter/material.dart';

/// Google Calendar API Configuration
/// 
/// This file contains the OAuth 2.0 client IDs and configuration for
/// Google Calendar integration with MedWave.
///
/// SETUP INSTRUCTIONS:
/// 1. Go to Google Cloud Console: https://console.cloud.google.com
/// 2. Select project: medx-ai (or create a new one)
/// 3. Enable Google Calendar API:
///    - APIs & Services → Library → Search "Google Calendar API" → Enable
/// 4. Create OAuth 2.0 credentials:
///    - APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID
///    
/// For Web:
///    - Application type: Web application
///    - Authorized redirect URIs:
///      * https://medx-ai.web.app/auth/google
///      * https://medx-ai.firebaseapp.com/auth/google
///      * http://localhost:3000/auth/google (for testing)
///
/// For Android:
///    - Application type: Android
///    - Package name: com.medwave.app (check AndroidManifest.xml)
///    - SHA-1 certificate fingerprint: (get from keytool command)
///
/// For iOS:
///    - Application type: iOS
///    - Bundle ID: com.medwave.app (check Info.plist)
///
/// 5. Configure OAuth consent screen:
///    - User Type: External
///    - Scopes: calendar.events, calendar.readonly
///    - Test users: Add practitioner email addresses
///
/// IMPORTANT: Replace the placeholder values below with your actual OAuth client IDs

class GoogleCalendarConfig {
  // OAuth 2.0 Client IDs
  // TODO: Replace these with your actual client IDs from Google Cloud Console
  
  /// Web Client ID for OAuth authentication
  /// Get from: Google Cloud Console → Credentials → OAuth 2.0 Client IDs (Web)
  static const String webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
  
  /// Android Client ID for OAuth authentication
  /// Get from: Google Cloud Console → Credentials → OAuth 2.0 Client IDs (Android)
  static const String androidClientId = 'YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com';
  
  /// iOS Client ID for OAuth authentication
  /// Get from: Google Cloud Console → Credentials → OAuth 2.0 Client IDs (iOS)
  static const String iosClientId = 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';
  
  // OAuth Scopes
  /// Required scopes for Google Calendar access
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/calendar.readonly',
  ];
  
  /// Redirect URI for OAuth callback (Web)
  static const String redirectUri = 'https://medx-ai.web.app/auth/google';
  
  /// App name shown in Google consent screen
  static const String appName = 'MedWave';
  
  // Configuration flags
  
  /// Enable/disable Google Calendar sync feature
  static const bool enableGoogleCalendarSync = true;
  
  /// Auto-sync interval in minutes (default: 15 minutes)
  static const int autoSyncIntervalMinutes = 15;
  
  /// Maximum number of sync retries on failure
  static const int maxSyncRetries = 3;
  
  /// Sync conflict resolution strategy
  /// Options: 'manual', 'medwave_wins', 'google_wins', 'last_write_wins'
  static const String defaultConflictResolution = 'manual';
  
  /// Include patient names in Google Calendar events
  /// Set to false for additional privacy (will use generic titles)
  static const bool includePatientNamesInGoogleEvents = true;
  
  /// Generic event title when patient names are hidden
  static const String genericEventTitle = 'Patient Appointment';
  
  // Error messages
  
  static const String errorAuthenticationFailed = 'Failed to authenticate with Google Calendar';
  static const String errorSyncFailed = 'Failed to sync with Google Calendar';
  static const String errorTokenRefreshFailed = 'Failed to refresh Google Calendar access token';
  static const String errorNoConnection = 'Google Calendar is not connected';
  
  // Helper methods
  
  /// Check if configuration is complete (client IDs are set)
  static bool get isConfigured {
    return webClientId != 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com' &&
           !webClientId.isEmpty;
  }
  
  /// Get appropriate client ID based on platform
  static String getClientId(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
        return androidClientId;
      case TargetPlatform.iOS:
        return iosClientId;
      default:
        return webClientId;
    }
  }
}

