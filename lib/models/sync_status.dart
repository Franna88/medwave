import 'package:cloud_firestore/cloud_firestore.dart';

/// Sync status enum for Google Calendar synchronization
enum SyncStatus {
  synced('synced'),
  pending('pending'),
  error('error'),
  conflict('conflict');

  const SyncStatus(this.value);
  final String value;

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SyncStatus.pending,
    );
  }
}

/// Represents the synchronization state for an appointment with Google Calendar
class AppointmentSyncInfo {
  final String? googleEventId;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final String? syncError;
  final DateTime? lastModifiedInGoogle;
  final DateTime? lastModifiedInMedwave;

  const AppointmentSyncInfo({
    this.googleEventId,
    required this.syncStatus,
    this.lastSyncedAt,
    this.syncError,
    this.lastModifiedInGoogle,
    this.lastModifiedInMedwave,
  });

  /// Create from Firestore document
  factory AppointmentSyncInfo.fromMap(Map<String, dynamic> map) {
    return AppointmentSyncInfo(
      googleEventId: map['googleEventId'] as String?,
      syncStatus: SyncStatus.fromString(map['syncStatus'] as String? ?? 'pending'),
      lastSyncedAt: map['lastSyncedAt'] != null
          ? (map['lastSyncedAt'] as Timestamp).toDate()
          : null,
      syncError: map['syncError'] as String?,
      lastModifiedInGoogle: map['lastModifiedInGoogle'] != null
          ? (map['lastModifiedInGoogle'] as Timestamp).toDate()
          : null,
      lastModifiedInMedwave: map['lastModifiedInMedwave'] != null
          ? (map['lastModifiedInMedwave'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'googleEventId': googleEventId,
      'syncStatus': syncStatus.value,
      'lastSyncedAt': lastSyncedAt != null ? Timestamp.fromDate(lastSyncedAt!) : null,
      'syncError': syncError,
      'lastModifiedInGoogle': lastModifiedInGoogle != null
          ? Timestamp.fromDate(lastModifiedInGoogle!)
          : null,
      'lastModifiedInMedwave': lastModifiedInMedwave != null
          ? Timestamp.fromDate(lastModifiedInMedwave!)
          : null,
    };
  }

  /// Create a copy with updated fields
  AppointmentSyncInfo copyWith({
    String? googleEventId,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    String? syncError,
    DateTime? lastModifiedInGoogle,
    DateTime? lastModifiedInMedwave,
  }) {
    return AppointmentSyncInfo(
      googleEventId: googleEventId ?? this.googleEventId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncError: syncError ?? this.syncError,
      lastModifiedInGoogle: lastModifiedInGoogle ?? this.lastModifiedInGoogle,
      lastModifiedInMedwave: lastModifiedInMedwave ?? this.lastModifiedInMedwave,
    );
  }

  /// Check if sync is needed
  bool get needsSync => syncStatus == SyncStatus.pending || syncStatus == SyncStatus.error;

  /// Check if there's a conflict
  bool get hasConflict => syncStatus == SyncStatus.conflict;

  /// Check if successfully synced
  bool get isSynced => syncStatus == SyncStatus.synced;
}

/// Represents Google Calendar connection status for a practitioner
class GoogleCalendarConnection {
  final bool isConnected;
  final String? googleCalendarId;
  final DateTime? lastSyncTime;
  final bool syncEnabled;
  final String? refreshToken;
  final String? accessToken;
  final DateTime? tokenExpiresAt;
  final int syncErrorCount;
  final String? lastSyncError;

  const GoogleCalendarConnection({
    required this.isConnected,
    this.googleCalendarId,
    this.lastSyncTime,
    required this.syncEnabled,
    this.refreshToken,
    this.accessToken,
    this.tokenExpiresAt,
    this.syncErrorCount = 0,
    this.lastSyncError,
  });

  /// Create from Firestore document
  factory GoogleCalendarConnection.fromMap(Map<String, dynamic> map) {
    return GoogleCalendarConnection(
      isConnected: map['googleCalendarConnected'] as bool? ?? false,
      googleCalendarId: map['googleCalendarId'] as String?,
      lastSyncTime: map['lastSyncTime'] != null
          ? (map['lastSyncTime'] as Timestamp).toDate()
          : null,
      syncEnabled: map['syncEnabled'] as bool? ?? true,
      refreshToken: map['googleRefreshToken'] as String?,
      accessToken: map['googleAccessToken'] as String?,
      tokenExpiresAt: map['tokenExpiresAt'] != null
          ? (map['tokenExpiresAt'] as Timestamp).toDate()
          : null,
      syncErrorCount: map['syncErrorCount'] as int? ?? 0,
      lastSyncError: map['lastSyncError'] as String?,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'googleCalendarConnected': isConnected,
      'googleCalendarId': googleCalendarId,
      'lastSyncTime': lastSyncTime != null ? Timestamp.fromDate(lastSyncTime!) : null,
      'syncEnabled': syncEnabled,
      'googleRefreshToken': refreshToken,
      'googleAccessToken': accessToken,
      'tokenExpiresAt': tokenExpiresAt != null ? Timestamp.fromDate(tokenExpiresAt!) : null,
      'syncErrorCount': syncErrorCount,
      'lastSyncError': lastSyncError,
    };
  }

  /// Create disconnected state
  factory GoogleCalendarConnection.disconnected() {
    return const GoogleCalendarConnection(
      isConnected: false,
      syncEnabled: false,
    );
  }

  /// Create a copy with updated fields
  GoogleCalendarConnection copyWith({
    bool? isConnected,
    String? googleCalendarId,
    DateTime? lastSyncTime,
    bool? syncEnabled,
    String? refreshToken,
    String? accessToken,
    DateTime? tokenExpiresAt,
    int? syncErrorCount,
    String? lastSyncError,
  }) {
    return GoogleCalendarConnection(
      isConnected: isConnected ?? this.isConnected,
      googleCalendarId: googleCalendarId ?? this.googleCalendarId,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      refreshToken: refreshToken ?? this.refreshToken,
      accessToken: accessToken ?? this.accessToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      syncErrorCount: syncErrorCount ?? this.syncErrorCount,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }

  /// Check if token needs refresh
  bool get needsTokenRefresh {
    if (tokenExpiresAt == null) return false;
    // Refresh if token expires within 5 minutes
    return tokenExpiresAt!.isBefore(DateTime.now().add(const Duration(minutes: 5)));
  }

  /// Check if connection is active and working
  bool get isActive => isConnected && syncEnabled && !needsTokenRefresh;
}

/// Sync conflict information
class SyncConflict {
  final String appointmentId;
  final Map<String, dynamic> medwaveData;
  final Map<String, dynamic> googleData;
  final DateTime detectedAt;
  final String? conflictReason;

  const SyncConflict({
    required this.appointmentId,
    required this.medwaveData,
    required this.googleData,
    required this.detectedAt,
    this.conflictReason,
  });

  /// Create from Firestore document
  factory SyncConflict.fromMap(Map<String, dynamic> map) {
    return SyncConflict(
      appointmentId: map['appointmentId'] as String,
      medwaveData: map['medwaveData'] as Map<String, dynamic>,
      googleData: map['googleData'] as Map<String, dynamic>,
      detectedAt: (map['detectedAt'] as Timestamp).toDate(),
      conflictReason: map['conflictReason'] as String?,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'medwaveData': medwaveData,
      'googleData': googleData,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'conflictReason': conflictReason,
    };
  }
}

/// Sync history entry
class SyncHistoryEntry {
  final DateTime timestamp;
  final String action; // 'push', 'pull', 'update', 'delete'
  final int itemsAffected;
  final bool success;
  final String? errorMessage;
  final Duration duration;

  const SyncHistoryEntry({
    required this.timestamp,
    required this.action,
    required this.itemsAffected,
    required this.success,
    this.errorMessage,
    required this.duration,
  });

  /// Create from Firestore document
  factory SyncHistoryEntry.fromMap(Map<String, dynamic> map) {
    return SyncHistoryEntry(
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      action: map['action'] as String,
      itemsAffected: map['itemsAffected'] as int,
      success: map['success'] as bool,
      errorMessage: map['errorMessage'] as String?,
      duration: Duration(milliseconds: map['durationMs'] as int),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'action': action,
      'itemsAffected': itemsAffected,
      'success': success,
      'errorMessage': errorMessage,
      'durationMs': duration.inMilliseconds,
    };
  }
}


