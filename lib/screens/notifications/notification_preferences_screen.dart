import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../models/notification.dart';
import '../../services/firebase/fcm_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Notification preferences
  NotificationPreferences _preferences = NotificationPreferences();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .get();

      if (doc.exists) {
        setState(() {
          _preferences = NotificationPreferences.fromFirestore(doc);
          _isLoading = false;
        });
      } else {
        // Create default preferences
        await _savePreferences();
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .set(_preferences.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification preferences saved'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving notification preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _savePreferences,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Push Notifications'),
                  _buildPreferenceCard([
                    _buildSwitchTile(
                      'Enable Push Notifications',
                      'Receive notifications on your device',
                      _preferences.pushNotificationsEnabled,
                      (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(pushNotificationsEnabled: value);
                        });
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  _buildSectionHeader('Appointment Notifications'),
                  _buildPreferenceCard([
                    _buildSwitchTile(
                      'Appointment Reminders',
                      'Get notified before appointments',
                      _preferences.appointmentReminders,
                      (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(appointmentReminders: value);
                        });
                      },
                    ),
                    _buildDropdownTile(
                      'Reminder Time',
                      'When to send appointment reminders',
                      _preferences.reminderTime,
                      [
                        '15 minutes',
                        '30 minutes',
                        '1 hour',
                        '2 hours',
                        '1 day',
                        '2 days',
                      ],
                      (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(reminderTime: value);
                        });
                      },
                      enabled: _preferences.appointmentReminders,
                    ),
                    _buildSwitchTile(
                      'Appointment Confirmations',
                      'Get notified when appointments are confirmed',
                      _preferences.appointmentConfirmations,
                      (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(appointmentConfirmations: value);
                        });
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  _buildSectionHeader('Patient Progress Notifications'),
                  _buildPreferenceCard([
                    _buildSwitchTile(
                      'Progress Alerts',
                      'Get notified about patient improvements',
                      _preferences.progressAlerts,
                      (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(progressAlerts: value);
                        });
                      },
                    ),
                    _buildSwitchTile(
                      'Urgent Patient Alerts',
                      'Get notified about urgent patient conditions',
                      _preferences.urgentAlerts,
                      (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(urgentAlerts: value);
                        });
                      },
                    ),
                    _buildDropdownTile(
                      'Progress Threshold',
                      'Minimum improvement percentage for alerts',
                      _preferences.progressThreshold,
                      ['10%', '20%', '30%', '40%', '50%'],
                      (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(progressThreshold: value);
                        });
                      },
                      enabled: _preferences.progressAlerts,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  _buildSectionHeader('System Notifications'),
                  _buildPreferenceCard([
                    _buildSwitchTile(
                      'System Updates',
                      'Get notified about app updates and maintenance',
                      _preferences.systemUpdates,
                      (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(systemUpdates: value);
                        });
                      },
                    ),
                    _buildSwitchTile(
                      'Security Alerts',
                      'Get notified about security-related events',
                      _preferences.securityAlerts,
                      (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(securityAlerts: value);
                        });
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  _buildSectionHeader('Notification Timing'),
                  _buildPreferenceCard([
                    _buildTimeTile(
                      'Do Not Disturb Start',
                      'Stop notifications from this time',
                      _preferences.doNotDisturbStart,
                      (time) {
                        setState(() {
                          _preferences = _preferences.copyWith(doNotDisturbStart: time);
                        });
                      },
                    ),
                    _buildTimeTile(
                      'Do Not Disturb End',
                      'Resume notifications from this time',
                      _preferences.doNotDisturbEnd,
                      (time) {
                        setState(() {
                          _preferences = _preferences.copyWith(doNotDisturbEnd: time);
                        });
                      },
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // Test notification button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _sendTestNotification,
                      icon: const Icon(Icons.notification_add),
                      label: const Text('Send Test Notification'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Clear all notifications button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _clearAllNotifications,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear All Notifications'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
      ),
    );
  }

  Widget _buildPreferenceCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.primaryColor,
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String> onChanged, {
    bool enabled = true,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? AppTheme.textColor : Colors.grey,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: enabled ? (newValue) => onChanged(newValue!) : null,
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeTile(
    String title,
    String subtitle,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: GestureDetector(
        onTap: () async {
          final newTime = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (newTime != null) {
            onChanged(newTime);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            time.format(context),
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      await FCMService.sendNotificationToUser(
        userId: _auth.currentUser?.uid ?? '',
        title: 'Test Notification',
        body: 'This is a test notification from MedWave!',
        data: {
          'type': NotificationType.reminder.name,
          'priority': NotificationPriority.medium.name,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await FCMService.clearAllNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Notification preferences model
class NotificationPreferences {
  final bool pushNotificationsEnabled;
  final bool appointmentReminders;
  final String reminderTime;
  final bool appointmentConfirmations;
  final bool progressAlerts;
  final bool urgentAlerts;
  final String progressThreshold;
  final bool systemUpdates;
  final bool securityAlerts;
  final TimeOfDay doNotDisturbStart;
  final TimeOfDay doNotDisturbEnd;

  NotificationPreferences({
    this.pushNotificationsEnabled = true,
    this.appointmentReminders = true,
    this.reminderTime = '1 day',
    this.appointmentConfirmations = true,
    this.progressAlerts = true,
    this.urgentAlerts = true,
    this.progressThreshold = '20%',
    this.systemUpdates = true,
    this.securityAlerts = true,
    this.doNotDisturbStart = const TimeOfDay(hour: 22, minute: 0),
    this.doNotDisturbEnd = const TimeOfDay(hour: 8, minute: 0),
  });

  NotificationPreferences copyWith({
    bool? pushNotificationsEnabled,
    bool? appointmentReminders,
    String? reminderTime,
    bool? appointmentConfirmations,
    bool? progressAlerts,
    bool? urgentAlerts,
    String? progressThreshold,
    bool? systemUpdates,
    bool? securityAlerts,
    TimeOfDay? doNotDisturbStart,
    TimeOfDay? doNotDisturbEnd,
  }) {
    return NotificationPreferences(
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      appointmentReminders: appointmentReminders ?? this.appointmentReminders,
      reminderTime: reminderTime ?? this.reminderTime,
      appointmentConfirmations: appointmentConfirmations ?? this.appointmentConfirmations,
      progressAlerts: progressAlerts ?? this.progressAlerts,
      urgentAlerts: urgentAlerts ?? this.urgentAlerts,
      progressThreshold: progressThreshold ?? this.progressThreshold,
      systemUpdates: systemUpdates ?? this.systemUpdates,
      securityAlerts: securityAlerts ?? this.securityAlerts,
      doNotDisturbStart: doNotDisturbStart ?? this.doNotDisturbStart,
      doNotDisturbEnd: doNotDisturbEnd ?? this.doNotDisturbEnd,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'appointmentReminders': appointmentReminders,
      'reminderTime': reminderTime,
      'appointmentConfirmations': appointmentConfirmations,
      'progressAlerts': progressAlerts,
      'urgentAlerts': urgentAlerts,
      'progressThreshold': progressThreshold,
      'systemUpdates': systemUpdates,
      'securityAlerts': securityAlerts,
      'doNotDisturbStart': '${doNotDisturbStart.hour}:${doNotDisturbStart.minute}',
      'doNotDisturbEnd': '${doNotDisturbEnd.hour}:${doNotDisturbEnd.minute}',
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationPreferences(
      pushNotificationsEnabled: data['pushNotificationsEnabled'] ?? true,
      appointmentReminders: data['appointmentReminders'] ?? true,
      reminderTime: data['reminderTime'] ?? '1 day',
      appointmentConfirmations: data['appointmentConfirmations'] ?? true,
      progressAlerts: data['progressAlerts'] ?? true,
      urgentAlerts: data['urgentAlerts'] ?? true,
      progressThreshold: data['progressThreshold'] ?? '20%',
      systemUpdates: data['systemUpdates'] ?? true,
      securityAlerts: data['securityAlerts'] ?? true,
      doNotDisturbStart: _parseTimeOfDay(data['doNotDisturbStart']) ?? const TimeOfDay(hour: 22, minute: 0),
      doNotDisturbEnd: _parseTimeOfDay(data['doNotDisturbEnd']) ?? const TimeOfDay(hour: 8, minute: 0),
    );
  }

  static TimeOfDay? _parseTimeOfDay(String? timeString) {
    if (timeString == null) return null;
    
    final parts = timeString.split(':');
    if (parts.length != 2) return null;
    
    try {
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (e) {
      return null;
    }
  }
}
