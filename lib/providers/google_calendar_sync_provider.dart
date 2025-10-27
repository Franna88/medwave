import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/sync_status.dart';
import '../services/google_calendar_service.dart';
import '../models/appointment.dart';

/// Provider for managing Google Calendar synchronization state
class GoogleCalendarSyncProvider with ChangeNotifier {
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  
  GoogleCalendarConnection _connectionStatus = GoogleCalendarConnection.disconnected();
  bool _isSyncing = false;
  String? _syncError;
  DateTime? _lastSyncTime;
  List<SyncHistoryEntry> _syncHistory = [];
  List<SyncConflict> _pendingConflicts = [];
  Timer? _autoSyncTimer;
  
  // Getters
  GoogleCalendarConnection get connectionStatus => _connectionStatus;
  bool get isSyncing => _isSyncing;
  bool get isConnected => _connectionStatus.isConnected;
  bool get syncEnabled => _connectionStatus.syncEnabled;
  String? get syncError => _syncError;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<SyncHistoryEntry> get syncHistory => List.unmodifiable(_syncHistory);
  List<SyncConflict> get pendingConflicts => List.unmodifiable(_pendingConflicts);
  int get conflictCount => _pendingConflicts.length;
  bool get hasConflicts => _pendingConflicts.isNotEmpty;

  /// Initialize provider and check connection status
  Future<void> initialize() async {
    await refreshConnectionStatus();
    
    // Start auto-sync if enabled
    if (_connectionStatus.isActive) {
      _startAutoSync();
    }
  }

  /// Refresh connection status from Firestore
  Future<void> refreshConnectionStatus() async {
    try {
      _connectionStatus = await _calendarService.getConnectionStatus();
      _lastSyncTime = _connectionStatus.lastSyncTime;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing connection status: $e');
    }
  }

  /// Connect to Google Calendar (OAuth flow)
  Future<bool> connect() async {
    try {
      _setError(null);
      notifyListeners();
      
      final success = await _calendarService.authenticateWithGoogle();
      
      if (success) {
        await refreshConnectionStatus();
        _startAutoSync();
      } else {
        _setError('Failed to connect to Google Calendar');
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _setError('Error connecting to Google Calendar: $e');
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from Google Calendar
  Future<bool> disconnect() async {
    try {
      _setError(null);
      
      final success = await _calendarService.disconnectGoogleCalendar();
      
      if (success) {
        _stopAutoSync();
        await refreshConnectionStatus();
      } else {
        _setError('Failed to disconnect from Google Calendar');
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _setError('Error disconnecting from Google Calendar: $e');
      notifyListeners();
      return false;
    }
  }

  /// Enable or disable auto-sync
  Future<void> toggleAutoSync(bool enabled) async {
    try {
      // Update in provider state
      _connectionStatus = _connectionStatus.copyWith(syncEnabled: enabled);
      
      if (enabled) {
        _startAutoSync();
      } else {
        _stopAutoSync();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling auto-sync: $e');
    }
  }

  /// Manually trigger sync (two-way)
  Future<bool> manualSync() async {
    if (_isSyncing) {
      debugPrint('Sync already in progress');
      return false;
    }

    return await _performSync();
  }

  /// Perform two-way synchronization
  Future<bool> _performSync() async {
    if (!_connectionStatus.isActive) {
      _setError('Google Calendar not connected or sync disabled');
      return false;
    }

    try {
      _setSyncing(true);
      _setError(null);
      final startTime = DateTime.now();

      // Sync from Google Calendar (pull)
      final syncedIds = await _calendarService.syncFromGoogleCalendar();
      
      final duration = DateTime.now().difference(startTime);
      
      // Add to sync history
      _addSyncHistoryEntry(SyncHistoryEntry(
        timestamp: DateTime.now(),
        action: 'pull',
        itemsAffected: syncedIds.length,
        success: true,
        duration: duration,
      ));

      _lastSyncTime = DateTime.now();
      await refreshConnectionStatus();
      
      _setSyncing(false);
      notifyListeners();
      
      debugPrint('Sync completed: ${syncedIds.length} items synced');
      return true;
    } catch (e) {
      _setError('Sync failed: $e');
      _setSyncing(false);
      
      // Add failed entry to history
      _addSyncHistoryEntry(SyncHistoryEntry(
        timestamp: DateTime.now(),
        action: 'pull',
        itemsAffected: 0,
        success: false,
        errorMessage: e.toString(),
        duration: const Duration(seconds: 0),
      ));
      
      notifyListeners();
      return false;
    }
  }

  /// Sync single appointment to Google
  Future<bool> syncAppointmentToGoogle(Appointment appointment) async {
    try {
      _setError(null);
      
      final googleEventId = await _calendarService.syncAppointmentToGoogle(appointment);
      
      if (googleEventId != null) {
        debugPrint('Appointment synced to Google: ${appointment.id}');
        return true;
      } else {
        _setError('Failed to sync appointment to Google Calendar');
        return false;
      }
    } catch (e) {
      _setError('Error syncing appointment: $e');
      return false;
    }
  }

  /// Delete appointment from Google Calendar
  Future<bool> deleteAppointmentFromGoogle(String googleEventId) async {
    try {
      _setError(null);
      
      final success = await _calendarService.deleteAppointmentFromGoogle(googleEventId);
      
      if (!success) {
        _setError('Failed to delete appointment from Google Calendar');
      }
      
      return success;
    } catch (e) {
      _setError('Error deleting appointment from Google: $e');
      return false;
    }
  }

  /// Resolve conflict - choose MedWave version
  Future<bool> resolveConflictWithMedWave(String appointmentId) async {
    try {
      _setError(null);
      
      final success = await _calendarService.resolveConflictWithMedWave(appointmentId);
      
      if (success) {
        // Remove from pending conflicts
        _pendingConflicts.removeWhere((c) => c.appointmentId == appointmentId);
        notifyListeners();
      } else {
        _setError('Failed to resolve conflict');
      }
      
      return success;
    } catch (e) {
      _setError('Error resolving conflict: $e');
      return false;
    }
  }

  /// Resolve conflict - choose Google version
  Future<bool> resolveConflictWithGoogle(String appointmentId) async {
    try {
      _setError(null);
      
      final success = await _calendarService.resolveConflictWithGoogle(appointmentId);
      
      if (success) {
        // Remove from pending conflicts
        _pendingConflicts.removeWhere((c) => c.appointmentId == appointmentId);
        notifyListeners();
      } else {
        _setError('Failed to resolve conflict');
      }
      
      return success;
    } catch (e) {
      _setError('Error resolving conflict: $e');
      return false;
    }
  }

  /// Start automatic sync timer
  void _startAutoSync() {
    _stopAutoSync(); // Cancel existing timer if any
    
    // Auto-sync every 15 minutes by default
    const syncInterval = Duration(minutes: 15);
    
    _autoSyncTimer = Timer.periodic(syncInterval, (timer) {
      if (_connectionStatus.isActive && !_isSyncing) {
        debugPrint('Auto-sync triggered');
        _performSync();
      }
    });
    
    debugPrint('Auto-sync started (interval: $syncInterval)');
  }

  /// Stop automatic sync timer
  void _stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    debugPrint('Auto-sync stopped');
  }

  /// Add entry to sync history
  void _addSyncHistoryEntry(SyncHistoryEntry entry) {
    _syncHistory.insert(0, entry); // Add to beginning
    
    // Keep only last 50 entries
    if (_syncHistory.length > 50) {
      _syncHistory = _syncHistory.sublist(0, 50);
    }
  }

  /// Set syncing state
  void _setSyncing(bool syncing) {
    _isSyncing = syncing;
    notifyListeners();
  }

  /// Set error message
  void _setError(String? error) {
    _syncError = error;
    if (error != null) {
      debugPrint('Google Calendar Sync Error: $error');
    }
  }

  /// Clear error
  void clearError() {
    _syncError = null;
    notifyListeners();
  }

  /// Get sync status for display
  String getSyncStatusText() {
    if (_isSyncing) {
      return 'Syncing...';
    } else if (!_connectionStatus.isConnected) {
      return 'Not connected';
    } else if (!_connectionStatus.syncEnabled) {
      return 'Sync disabled';
    } else if (_syncError != null) {
      return 'Sync error';
    } else if (_lastSyncTime != null) {
      final minutesAgo = DateTime.now().difference(_lastSyncTime!).inMinutes;
      if (minutesAgo < 1) {
        return 'Synced just now';
      } else if (minutesAgo < 60) {
        return 'Synced $minutesAgo min ago';
      } else {
        final hoursAgo = (minutesAgo / 60).floor();
        return 'Synced $hoursAgo hour${hoursAgo > 1 ? 's' : ''} ago';
      }
    } else {
      return 'Ready to sync';
    }
  }

  /// Get connection status icon
  String getConnectionStatusIcon() {
    if (_connectionStatus.isConnected) {
      return '✓';
    } else {
      return '✗';
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    _stopAutoSync();
    super.dispose();
  }
}


