import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../../models/notification.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static String? _currentToken;

  /// Initialize Firebase Cloud Messaging
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM permission granted: ${settings.authorizationStatus}');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _updateFCMToken();

      // Set up message handlers
      _setupMessageHandlers();

      _isInitialized = true;
      debugPrint('FCM Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing FCM Service: $e');
    }
  }

  /// Initialize local notifications plugin
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNotificationNavigation(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Handle navigation based on notification data
  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final patientId = data['patientId'] as String?;
    final appointmentId = data['appointmentId'] as String?;

    // Navigation logic would be implemented here
    // This could be handled through a global navigator or route manager
    debugPrint('Navigate to: type=$type, patientId=$patientId, appointmentId=$appointmentId');
  }

  /// Set up FCM message handlers
  static void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Handle messages when app is opened from terminated state
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _onMessageOpenedApp(message);
      }
    });
  }

  /// Handle foreground messages
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');

    // Show local notification for foreground messages
    await _showLocalNotification(message);

    // Store notification in Firestore
    await _storeNotificationInFirestore(message);
  }

  /// Handle message when app is opened from background/terminated
  static void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('App opened from notification: ${message.messageId}');
    
    // Handle navigation or other actions
    if (message.data.isNotEmpty) {
      _handleNotificationNavigation(message.data);
    }
  }

  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medwave_channel',
      'MedWave Notifications',
      channelDescription: 'Medical practice management notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'MedWave',
      message.notification?.body ?? 'New notification',
      platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// Store notification in Firestore
  static Future<void> _storeNotificationInFirestore(RemoteMessage message) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final notification = AppNotification(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? 'MedWave Notification',
        message: message.notification?.body ?? '',
        type: _getNotificationTypeFromData(message.data),
        priority: _getNotificationPriorityFromData(message.data),
        createdAt: DateTime.now(),
        isRead: false,
        patientId: message.data['patientId'],
        patientName: message.data['patientName'],
        data: message.data,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint('Notification stored in Firestore: ${notification.id}');
    } catch (e) {
      debugPrint('Error storing notification in Firestore: $e');
    }
  }

  /// Get notification type from message data
  static NotificationType _getNotificationTypeFromData(Map<String, dynamic> data) {
    final typeString = data['type'] as String?;
    return NotificationType.values.firstWhere(
      (type) => type.name == typeString,
      orElse: () => NotificationType.reminder,
    );
  }

  /// Get notification priority from message data
  static NotificationPriority _getNotificationPriorityFromData(Map<String, dynamic> data) {
    final priorityString = data['priority'] as String?;
    return NotificationPriority.values.firstWhere(
      (priority) => priority.name == priorityString,
      orElse: () => NotificationPriority.medium,
    );
  }

  /// Update FCM token
  static Future<void> _updateFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null && token != _currentToken) {
        _currentToken = token;
        await _saveFCMTokenToFirestore(token);
        debugPrint('FCM Token updated: ${token.substring(0, 20)}...');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        _saveFCMTokenToFirestore(newToken);
        debugPrint('FCM Token refreshed: ${newToken.substring(0, 20)}...');
      });
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  /// Save FCM token to Firestore
  static Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  /// Send push notification to specific user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM tokens
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData == null) return;

      final fcmTokens = List<String>.from(userData['fcmTokens'] ?? []);
      
      if (fcmTokens.isEmpty) {
        debugPrint('No FCM tokens found for user: $userId');
        return;
      }

      // Note: In a real implementation, you would send this to your server
      // which would use the Firebase Admin SDK to send the notification
      debugPrint('Would send notification to ${fcmTokens.length} devices: $title');
      
      // For development, we'll just store the notification in Firestore
      await _storeSystemNotification(userId, title, body, data);
      
    } catch (e) {
      debugPrint('Error sending notification to user: $e');
    }
  }

  /// Store system-generated notification in Firestore
  static Future<void> _storeSystemNotification(
    String userId,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        message: body,
        type: _getNotificationTypeFromData(data ?? {}),
        priority: _getNotificationPriorityFromData(data ?? {}),
        createdAt: DateTime.now(),
        isRead: false,
        patientId: data?['patientId'],
        patientName: data?['patientName'],
        data: data,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint('System notification stored: ${notification.id}');
    } catch (e) {
      debugPrint('Error storing system notification: $e');
    }
  }

  /// Schedule appointment reminder
  static Future<void> scheduleAppointmentReminder({
    required String practitionerId,
    required String patientId,
    required String patientName,
    required String appointmentId,
    required DateTime appointmentDateTime,
    Duration reminderBefore = const Duration(hours: 24),
  }) async {
    try {
      final reminderTime = appointmentDateTime.subtract(reminderBefore);
      
      // Check if reminder time is in the future
      if (reminderTime.isBefore(DateTime.now())) {
        debugPrint('Reminder time is in the past, skipping');
        return;
      }

      final title = 'Appointment Reminder';
      final body = 'You have an appointment with $patientName tomorrow';
      final data = {
        'type': NotificationType.appointment.name,
        'priority': NotificationPriority.medium.name,
        'patientId': patientId,
        'patientName': patientName,
        'appointmentId': appointmentId,
        'appointmentDateTime': appointmentDateTime.toIso8601String(),
      };

      // In a real implementation, you would schedule this with Cloud Functions
      // For now, we'll just store it as a notification
      await sendNotificationToUser(
        userId: practitionerId,
        title: title,
        body: body,
        data: data,
      );

      debugPrint('Appointment reminder scheduled for: ${reminderTime.toIso8601String()}');
    } catch (e) {
      debugPrint('Error scheduling appointment reminder: $e');
    }
  }

  /// Send patient progress alert
  static Future<void> sendProgressAlert({
    required String practitionerId,
    required String patientId,
    required String patientName,
    required String alertType,
    required String message,
    NotificationPriority priority = NotificationPriority.high,
  }) async {
    try {
      final title = 'Patient Progress Alert';
      final body = '$patientName: $message';
      final data = {
        'type': NotificationType.improvement.name,
        'priority': priority.name,
        'patientId': patientId,
        'patientName': patientName,
        'alertType': alertType,
      };

      await sendNotificationToUser(
        userId: practitionerId,
        title: title,
        body: body,
        data: data,
      );

      debugPrint('Progress alert sent for patient: $patientName');
    } catch (e) {
      debugPrint('Error sending progress alert: $e');
    }
  }

  /// Send system alert
  static Future<void> sendSystemAlert({
    required String practitionerId,
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final data = {
        'type': NotificationType.alert.name,
        'priority': priority.name,
        ...?additionalData,
      };

      await sendNotificationToUser(
        userId: practitionerId,
        title: title,
        body: message,
        data: data,
      );

      debugPrint('System alert sent: $title');
    } catch (e) {
      debugPrint('Error sending system alert: $e');
    }
  }

  /// Get current FCM token
  static String? get currentToken => _currentToken;

  /// Check if FCM is initialized
  static bool get isInitialized => _isInitialized;

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Clear specific notification
  static Future<void> clearNotification(int notificationId) async {
    await _localNotifications.cancel(notificationId);
  }
}
