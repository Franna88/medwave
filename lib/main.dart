import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
// Conditional import: uses web plugin on web, stub on mobile
import 'url_strategy_stub.dart' if (dart.library.html) 'url_strategy_web.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'models/patient.dart';
import 'providers/patient_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/performance_cost_provider.dart';
import 'screens/main_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/patients/patient_list_screen.dart';
import 'screens/patients/add_patient_screen.dart';
import 'screens/patients/edit_patient_screen.dart';
import 'screens/patients/patient_profile_screen.dart';
import 'screens/patients/patient_case_history_screen.dart';
import 'screens/patients/wound_count_selection_screen.dart';
import 'screens/patients/multi_wound_case_history_screen.dart';
import 'screens/patients/weight_case_history_screen.dart';
import 'screens/patients/pain_case_history_screen.dart';
import 'screens/ai/enhanced_ai_report_chat_screen.dart';
import 'screens/patients/session_detail_screen.dart';
import 'screens/sessions/session_logging_screen.dart';
import 'screens/sessions/multi_wound_session_logging_screen.dart';
import 'screens/sessions/weight_session_logging_screen.dart';
import 'screens/sessions/pain_session_logging_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/download/download_app_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/notifications/notification_preferences_screen.dart';
import 'screens/web/mobile_warning_screen.dart';
import 'screens/forms/public_form_screen.dart';
import 'screens/public/deposit_confirmation_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_provider_management_screen.dart';
import 'screens/admin/admin_provider_approvals_screen.dart';
import 'screens/admin/admin_sales_performance_screen.dart';
import 'screens/admin/admin_analytics_screen.dart';
import 'utils/role_manager.dart';
import 'screens/admin/admin_patient_management_screen.dart';
import 'screens/admin/admin_product_management_screen.dart';
import 'screens/admin/adverts/admin_adverts_overview_screen.dart';
import 'screens/admin/adverts/admin_adverts_campaigns_screen.dart';
import 'screens/admin/adverts/admin_adverts_campaigns_old_screen.dart';
import 'screens/admin/adverts/admin_adverts_comparison_screen.dart';
import 'screens/admin/adverts/admin_adverts_ads_screen.dart';
import 'screens/admin/admin_user_management_screen.dart';
import 'screens/admin/admin_report_builder_screen.dart';
import 'screens/admin/admin_forms_screen.dart';
import 'screens/admin/forms/form_builder_screen.dart';
import 'screens/admin/admin_leads_screen.dart';
import 'screens/admin/admin_contract_content_screen.dart';
import 'screens/admin/streams/marketing_stream_screen.dart';
import 'screens/admin/streams/sales_stream_screen.dart';
import 'screens/admin/streams/operations_stream_screen.dart';
import 'screens/admin/streams/support_stream_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/gohighlevel_provider.dart';
import 'providers/product_items_provider.dart';
import 'providers/contract_content_provider.dart';
import 'providers/inventory_provider.dart';
import 'screens/warehouse/warehouse_main_screen.dart';
import 'screens/warehouse/inventory_list_screen.dart';
import 'screens/warehouse/orders_placeholder_screen.dart';
import 'services/firebase/fcm_service.dart';
import 'services/web_image_service.dart';
import 'utils/responsive_utils.dart';
import 'services/firebase/app_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase Analytics
  FirebaseAnalytics.instance;

  // Initialize Firebase Performance
  FirebasePerformance.instance;

  // Initialize Firebase Cloud Messaging
  await FCMService.initialize();

  // Configure web image caching
  WebImageService.configureWebImageCache();

  // Initialize app settings with defaults if they don't exist
  final appSettingsService = AppSettingsService();
  await appSettingsService.initializeDefaultSettings();

  // Configure path-based URL strategy for web (removes # from URLs)
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }

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
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()
            ..loadNotifications()
            ..initializeFCM(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppointmentProvider()..loadAppointments(),
        ),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        // Admin provider for superadmin functionality
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        // Product items provider for admin product management
        ChangeNotifierProvider(create: (_) => ProductItemsProvider()),
        // Inventory provider for warehouse stock management
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        // GoHighLevel CRM provider for advertisement performance monitoring
        ChangeNotifierProvider(create: (_) => GoHighLevelProvider()),
        // Performance Cost provider for ad budget and profitability tracking
        ChangeNotifierProvider(create: (_) => PerformanceCostProvider()),
        // Contract Content provider for managing contract templates
        ChangeNotifierProvider(create: (_) => ContractContentProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Always use MaterialApp.router so GoRouter can handle initial routes
          // The redirect logic will handle showing appropriate content during loading
          return MaterialApp.router(
            title: 'MedX AI',
            theme: AppTheme.lightTheme,
            routerConfig: _buildRouter(authProvider),
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en', 'US')],
          );
        },
      ),
    );
  }
}

GoRouter _buildRouter(AuthProvider authProvider) => GoRouter(
  // Don't set initialLocation - let the URL determine where to go
  // initialLocation: '/welcome',
  redirect: (context, state) {
    final currentPath = state.uri.path;

    debugPrint(
      'Router redirect: currentPath=$currentPath, isAuthenticated=${authProvider.isAuthenticated}, canAccessApp=${authProvider.canAccessApp}, isLoading=${authProvider.isLoading}',
    );

    // Explicitly allow /fb-form routes - always accessible regardless of authentication status
    if (currentPath.startsWith('/fb-form')) {
      return null; // Always allow access to public forms
    }

    // Check for mobile browser warning on web platform
    if (ResponsiveUtils.isWeb() &&
        ResponsiveUtils.shouldShowMobileWarning(context) &&
        currentPath != '/mobile-warning') {
      return '/mobile-warning';
    }

    // Block session creation routes on web platform, but allow viewing
    if (ResponsiveUtils.shouldRestrictSessions()) {
      // Block session creation and wound selection (conducting sessions)
      if ((currentPath.contains('/session') &&
              !currentPath.contains(
                '/sessions/',
              )) || // '/session' but not '/sessions/:id'
          currentPath.contains('/wound-selection') ||
          currentPath.contains('/case-history')) {
        return '/'; // Redirect to dashboard
      }
      // Note: Allow session viewing routes like '/sessions/:sessionId' to pass through
    }

    // Allow access to public routes immediately, even while loading
    final isPublicRoute =
        currentPath.startsWith('/welcome') ||
        currentPath.startsWith('/login') ||
        currentPath.startsWith('/signup') ||
        currentPath.startsWith('/download-app') ||
        currentPath.startsWith('/mobile-warning') ||
        currentPath.startsWith('/fb-form') ||
        currentPath.startsWith('/verify-email') ||
        currentPath.startsWith('/deposit-confirmation');

    // Wait for auth to initialize - preserve current route during loading
    // This prevents redirecting authenticated users away from their current page on reload
    if (authProvider.isLoading) {
      if (isPublicRoute) {
        return null; // Allow public routes while loading
      }
      // Preserve current route while auth is loading (prevents redirect on page reload)
      return null; // Stay on current route while loading
    }

    // If user is not authenticated, allow access to public routes only
    if (!authProvider.isAuthenticated) {
      if (isPublicRoute) {
        return null; // Allow access
      }
      // Redirect root or any protected route to welcome
      return '/welcome';
    }

    // If user is authenticated but not approved, redirect to pending approval
    // Exception: Allow public routes like /fb-form, /verify-email
    if (authProvider.isAuthenticated && !authProvider.canAccessApp) {
      if (currentPath != '/pending-approval' &&
          currentPath != '/verify-email' &&
          !currentPath.startsWith('/fb-form')) {
        return '/pending-approval';
      }
      return null;
    }

    // If user is authenticated and approved, redirect away from auth screens only
    // Don't redirect from their current protected route (preserves route on reload)
    if (authProvider.isAuthenticated && authProvider.canAccessApp) {
      // Only redirect if they're on an auth screen, not from their current working route
      if (currentPath == '/' ||
          currentPath == '/welcome' ||
          currentPath == '/login' ||
          currentPath == '/signup' ||
          currentPath == '/pending-approval') {
        // Redirect to role-appropriate dashboard
        return authProvider.dashboardRoute;
      }

      // Check stream route access
      if (currentPath.startsWith('/admin/streams/')) {
        final userRole = authProvider.userRole;
        String? streamName;

        if (currentPath == '/admin/streams/marketing' ||
            currentPath.startsWith('/admin/streams/marketing/')) {
          streamName = 'marketing';
        } else if (currentPath == '/admin/streams/sales' ||
            currentPath.startsWith('/admin/streams/sales/')) {
          streamName = 'sales';
        } else if (currentPath == '/admin/streams/operations' ||
            currentPath.startsWith('/admin/streams/operations/')) {
          streamName = 'operations';
        } else if (currentPath == '/admin/streams/support' ||
            currentPath.startsWith('/admin/streams/support/')) {
          streamName = 'support';
        }

        if (streamName != null &&
            !RoleManager.canAccessStream(userRole, streamName)) {
          final accessibleStreams = RoleManager.getAccessibleStreams(userRole);
          if (accessibleStreams.isNotEmpty) {
            return '/admin/streams/${accessibleStreams.first}';
          }
          return authProvider.dashboardRoute;
        }
      }

      // Restrict product management to super admin and country admin
      if (currentPath.startsWith('/admin/product-management') &&
          !RoleManager.canManageProducts(authProvider.userRole)) {
        return authProvider.dashboardRoute;
      }

      // Restrict warehouse routes to warehouse role and admins
      if (currentPath.startsWith('/warehouse') &&
          !RoleManager.canAccessWarehouse(authProvider.userRole)) {
        return authProvider.dashboardRoute;
      }
    }

    return null; // No redirect needed - preserve current route
  },
  routes: [
    // Root route - global redirect will handle where to go
    GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
    // Mobile warning screen (web only)
    GoRoute(
      path: '/mobile-warning',
      name: 'mobile-warning',
      builder: (context, state) => const MobileWarningScreen(),
    ),
    // Welcome screen
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    // Download app screen (public)
    GoRoute(
      path: '/download-app',
      name: 'download-app',
      builder: (context, state) => const DownloadAppScreen(),
    ),
    // Public Facebook form (no authentication required)
    GoRoute(
      path: '/fb-form/:formId',
      name: 'fb-form',
      builder: (context, state) {
        final formId = state.pathParameters['formId']!;
        return PublicFormScreen(formId: formId);
      },
    ),
    GoRoute(
      path: '/deposit-confirmation',
      name: 'deposit-confirmation',
      builder: (context, state) => DepositConfirmationScreen(
        appointmentId: state.uri.queryParameters['appointmentId'],
        decision: state.uri.queryParameters['decision'],
        token: state.uri.queryParameters['token'],
      ),
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
    GoRoute(
      path: '/verify-email',
      name: 'verify-email',
      builder: (context, state) => const EmailVerificationScreen(),
    ),

    // Main app routes (protected)
    ShellRoute(
      builder: (context, state, child) => MainScreen(child: child),
      routes: [
        // Practitioner Dashboard
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/patients',
          name: 'patients',
          builder: (context, state) {
            final successMessage = state.uri.queryParameters['success'];
            return PatientListScreen(successMessage: successMessage);
          },
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
              builder: (context, state) =>
                  const NotificationPreferencesScreen(),
            ),
          ],
        ),

        // Admin routes - protected by role-based access control
        GoRoute(
          path: '/admin/dashboard',
          name: 'admin-dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/providers',
          name: 'admin-providers',
          builder: (context, state) => const AdminProviderManagementScreen(),
        ),
        GoRoute(
          path: '/admin/approvals',
          name: 'admin-approvals',
          builder: (context, state) => const AdminProviderApprovalsScreen(),
        ),
        GoRoute(
          path: '/admin/analytics',
          name: 'admin-analytics',
          builder: (context, state) => const AdminAnalyticsScreen(),
        ),
        GoRoute(
          path: '/admin/patients',
          name: 'admin-patients',
          builder: (context, state) => const AdminPatientManagementScreen(),
        ),
        GoRoute(
          path: '/admin/product-management',
          name: 'admin-product-management',
          builder: (context, state) => const AdminProductManagementScreen(),
        ),
        GoRoute(
          path: '/admin/contract-content',
          name: 'admin-contract-content',
          builder: (context, state) => const AdminContractContentScreen(),
        ),
        GoRoute(
          path: '/admin/adverts',
          name: 'admin-adverts',
          redirect: (context, state) {
            // Redirect base route to overview
            if (state.uri.path == '/admin/adverts') {
              return '/admin/adverts/overview';
            }
            return null; // Allow sub-routes to proceed
          },
          routes: [
            // Sub-routes for Advertisement Performance
            GoRoute(
              path: 'overview',
              name: 'admin-adverts-overview',
              builder: (context, state) => const AdminAdvertsOverviewScreen(),
            ),
            GoRoute(
              path: 'campaigns',
              name: 'admin-adverts-campaigns',
              builder: (context, state) => const AdminAdvertsCampaignsScreen(),
            ),
            GoRoute(
              path: 'campaigns-old',
              name: 'admin-adverts-campaigns-old',
              builder: (context, state) =>
                  const AdminAdvertsCampaignsOldScreen(),
            ),
            GoRoute(
              path: 'ads',
              name: 'admin-adverts-ads',
              builder: (context, state) => const AdminAdvertsAdsScreen(),
            ),
            GoRoute(
              path: 'comparison',
              name: 'admin-adverts-comparison',
              builder: (context, state) => const AdminAdvertsComparisonScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/admin/sales-performance',
          name: 'admin-sales-performance',
          builder: (context, state) => const AdminSalesPerformanceScreen(),
        ),
        GoRoute(
          path: '/admin/users',
          name: 'admin-users',
          builder: (context, state) => const AdminUserManagementScreen(),
        ),
        GoRoute(
          path: '/admin/report-builder',
          name: 'admin-report-builder',
          builder: (context, state) => const AdminReportBuilderScreen(),
        ),
        GoRoute(
          path: '/admin/forms',
          name: 'admin-forms',
          builder: (context, state) => const AdminFormsScreen(),
        ),
        GoRoute(
          path: '/admin/forms/builder/:formId',
          name: 'form-builder',
          builder: (context, state) {
            final formId = state.pathParameters['formId']!;
            return FormBuilderScreen(formId: formId);
          },
        ),
        GoRoute(
          path: '/admin/leads',
          name: 'admin-leads',
          builder: (context, state) => const AdminLeadsScreen(),
        ),
        // Streams routes
        GoRoute(
          path: '/admin/streams',
          name: 'admin-streams',
          redirect: (context, state) {
            // Redirect base route to marketing
            if (state.uri.path == '/admin/streams') {
              return '/admin/streams/marketing';
            }
            return null; // Allow sub-routes to proceed
          },
          routes: [
            GoRoute(
              path: 'marketing',
              name: 'admin-streams-marketing',
              builder: (context, state) => const MarketingStreamScreen(),
            ),
            GoRoute(
              path: 'sales',
              name: 'admin-streams-sales',
              builder: (context, state) => const SalesStreamScreen(),
            ),
            GoRoute(
              path: 'operations',
              name: 'admin-streams-operations',
              builder: (context, state) => const OperationsStreamScreen(),
            ),
            GoRoute(
              path: 'support',
              name: 'admin-streams-support',
              builder: (context, state) => const SupportStreamScreen(),
            ),
          ],
        ),
      ],
    ),

    // Warehouse routes (protected) - separate shell for warehouse staff
    ShellRoute(
      builder: (context, state, child) => WarehouseMainScreen(child: child),
      routes: [
        GoRoute(
          path: '/warehouse/inventory',
          name: 'warehouse-inventory',
          builder: (context, state) => const InventoryListScreen(),
        ),
        GoRoute(
          path: '/warehouse/orders',
          name: 'warehouse-orders',
          builder: (context, state) => const OrdersPlaceholderScreen(),
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
      path: '/patients/:patientId/edit',
      name: 'edit-patient',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return EditPatientScreen(patientId: patientId);
      },
    ),
    GoRoute(
      path: '/patients/:patientId/wound-selection',
      name: 'wound-count-selection',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        final patientName = state.uri.queryParameters['name'] ?? 'Patient';
        return WoundCountSelectionScreen(
          patientId: patientId,
          patientName: patientName,
        );
      },
    ),
    GoRoute(
      path: '/patients/:patientId/case-history',
      name: 'patient-case-history',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return PatientCaseHistoryScreen(patientId: patientId);
      },
    ),
    GoRoute(
      path: '/patients/:patientId/multi-wound-case-history',
      name: 'multi-wound-case-history',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return MultiWoundCaseHistoryScreen(patientId: patientId);
      },
    ),
    GoRoute(
      path: '/patients/:patientId/weight-case-history',
      name: 'weight-case-history',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return WeightCaseHistoryScreen(patientId: patientId);
      },
    ),
    GoRoute(
      path: '/patients/:patientId/pain-case-history',
      name: 'pain-case-history',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return PainCaseHistoryScreen(patientId: patientId);
      },
    ),
    GoRoute(
      path: '/patients/:patientId/sessions/:sessionId/enhanced-ai-chat',
      name: 'enhanced-ai-chat',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        final sessionId = state.pathParameters['sessionId']!;
        final extra = state.extra as Map<String, dynamic>?;

        if (extra == null ||
            extra['patient'] == null ||
            extra['session'] == null) {
          // Fallback - redirect to patient profile
          return const Scaffold(
            body: Center(
              child: Text('Invalid session data. Please try again.'),
            ),
          );
        }

        return EnhancedAIReportChatScreen(
          patientId: patientId,
          sessionId: sessionId,
          patient: extra['patient'] as Patient,
          session: extra['session'] as Session,
        );
      },
    ),
    GoRoute(
      path: '/patients/:patientId/session',
      name: 'session-logging',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;

        // Get patient and route based on treatment type
        final patientProvider = Provider.of<PatientProvider>(
          context,
          listen: false,
        );
        final patient = patientProvider.patients.firstWhere(
          (p) => p.id == patientId,
          orElse: () => throw Exception('Patient not found'),
        );

        // Route to appropriate session screen based on treatment type
        switch (patient.treatmentType) {
          case TreatmentType.weight:
            return WeightSessionLoggingScreen(patientId: patientId);
          case TreatmentType.pain:
            return PainSessionLoggingScreen(patientId: patientId);
          case TreatmentType.wound:
            return SessionLoggingScreen(patientId: patientId);
        }
      },
    ),
    GoRoute(
      path: '/patients/:patientId/multi-wound-session',
      name: 'multi-wound-session-logging',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return MultiWoundSessionLoggingScreen(patientId: patientId);
      },
    ),
    GoRoute(
      path: '/patients/:patientId/weight-session',
      name: 'weight-session-logging',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return WeightSessionLoggingScreen(patientId: patientId);
      },
    ),
    GoRoute(
      path: '/patients/:patientId/pain-session',
      name: 'pain-session-logging',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        return PainSessionLoggingScreen(patientId: patientId);
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
