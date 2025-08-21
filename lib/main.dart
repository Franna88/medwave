import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
import 'screens/profile_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/user_profile_provider.dart';

void main() {
  runApp(const MedWaveApp());
}

class MedWaveApp extends StatelessWidget {
  const MedWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()..loadPatients()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..loadNotifications()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
      ],
      child: MaterialApp.router(
        title: 'MedWave Provider',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/welcome',
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

