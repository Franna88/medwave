import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'models/patient.dart';
import 'providers/patient_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/appointment_provider.dart';
import 'screens/main_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/patients/patient_list_screen.dart';
import 'screens/patients/add_patient_screen.dart';
import 'screens/patients/patient_profile_screen.dart';
import 'screens/patients/session_detail_screen.dart';
import 'screens/sessions/session_logging_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/notifications/notification_preferences_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/user_profile_provider.dart';
import 'services/firebase/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Firebase Analytics
  FirebaseAnalytics.instance;
  
    // Initialize Firebase Performance
  FirebasePerformance.instance;

  // Initialize Firebase Cloud Messaging
  await FCMService.initialize();

  runApp(const MedWaveApp());
}

class MedWaveApp extends StatelessWidget {
  const MedWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..loadNotifications()..initializeFCM()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Show loading screen while auth is initializing
          if (authProvider.isLoading) {
            return MaterialApp(
              title: 'MedWave Provider',
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: AppTheme.primaryColor,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.medical_services,
                          size: 60,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'MedWave',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return MaterialApp.router(
            title: 'MedWave Provider',
            theme: AppTheme.lightTheme,
            routerConfig: _buildRouter(authProvider),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

GoRouter _buildRouter(AuthProvider authProvider) => GoRouter(
  initialLocation: '/welcome',
  redirect: (context, state) {
    final currentPath = state.uri.path;
    
    debugPrint('Router redirect: currentPath=$currentPath, isAuthenticated=${authProvider.isAuthenticated}, canAccessApp=${authProvider.canAccessApp}, isLoading=${authProvider.isLoading}');
    
    // Wait for auth to initialize
    if (authProvider.isLoading) {
      return null; // Stay on current route while loading
    }
    
    // If user is not authenticated, allow access to public routes only
    if (!authProvider.isAuthenticated) {
      if (currentPath.startsWith('/welcome') || 
          currentPath.startsWith('/login') || 
          currentPath.startsWith('/signup')) {
        return null; // Allow access
      }
      return '/welcome'; // Redirect to welcome for protected routes
    }
    
    // If user is authenticated but not approved, redirect to pending approval
    if (authProvider.isAuthenticated && !authProvider.canAccessApp) {
      if (currentPath != '/pending-approval') {
        return '/pending-approval';
      }
      return null;
    }
    
    // If user is authenticated and approved, redirect away from auth screens
    if (authProvider.isAuthenticated && authProvider.canAccessApp) {
      if (currentPath == '/welcome' || 
          currentPath == '/login' || 
          currentPath == '/signup' || 
          currentPath == '/pending-approval') {
        return '/'; // Redirect to dashboard
      }
    }
    
    return null; // No redirect needed
  },
  routes: [
    // Welcome screen
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    // Authentication routes
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/pending-approval',
      name: 'pending-approval',
      builder: (context, state) => const PendingApprovalScreen(),
    ),
    
    // Main app routes (protected)
    ShellRoute(
      builder: (context, state, child) => MainScreen(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/patients',
          name: 'patients',
          builder: (context, state) => const PatientListScreen(),
        ),
        GoRoute(
          path: '/reports',
          name: 'reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/calendar',
          name: 'calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsScreen(),
          routes: [
            GoRoute(
              path: 'preferences',
              name: 'notification-preferences',
              builder: (context, state) => const NotificationPreferencesScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/patients/add',
      name: 'add-patient',
      builder: (context, state) => const AddPatientScreen(),
    ),
    GoRoute(
      path: '/patients/:patientId',
      name: 'patient-profile',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return PatientProfileScreen(patientId: patientId);
      },
    ),
    GoRoute(
      path: '/patients/:patientId/session',
      name: 'session-logging',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return SessionLoggingScreen(patientId: patientId);
      },
    ),
    GoRoute(
      path: '/patients/:patientId/sessions/:sessionId',
      name: 'session-detail',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        final sessionId = state.pathParameters['sessionId']!;
        final extra = state.extra as Map<String, dynamic>;
        final patient = extra['patient'] as Patient;
        final session = extra['session'] as Session;
        return SessionDetailScreen(
          patientId: patientId,
          sessionId: sessionId,
          patient: patient,
          session: session,
        );
      },
    ),
  ],
);

