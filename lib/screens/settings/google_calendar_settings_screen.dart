import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/google_calendar_sync_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/google_calendar_config.dart';

class GoogleCalendarSettingsScreen extends StatefulWidget {
  const GoogleCalendarSettingsScreen({super.key});

  @override
  State<GoogleCalendarSettingsScreen> createState() => _GoogleCalendarSettingsScreenState();
}

class _GoogleCalendarSettingsScreenState extends State<GoogleCalendarSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoogleCalendarSyncProvider>().refreshConnectionStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Calendar Sync'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<GoogleCalendarSyncProvider>(
        builder: (context, syncProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Status Card
                _buildConnectionStatusCard(syncProvider),
                
                const SizedBox(height: 20),
                
                // Sync Controls (only show if connected)
                if (syncProvider.isConnected) ...[
                  _buildSyncControlsCard(syncProvider),
                  const SizedBox(height: 20),
                ],
                
                // Sync History (only show if connected)
                if (syncProvider.isConnected && syncProvider.syncHistory.isNotEmpty) ...[
                  _buildSyncHistoryCard(syncProvider),
                  const SizedBox(height: 20),
                ],
                
                // Conflicts (only show if there are conflicts)
                if (syncProvider.hasConflicts) ...[
                  _buildConflictsCard(syncProvider),
                  const SizedBox(height: 20),
                ],
                
                // Settings Card
                _buildSettingsCard(syncProvider),
                
                const SizedBox(height: 20),
                
                // Help & Info Card
                _buildHelpCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatusCard(GoogleCalendarSyncProvider syncProvider) {
    final isConnected = syncProvider.isConnected;
    final connection = syncProvider.connectionStatus;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: isConnected ? AppTheme.successColor : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'Connected' : 'Not Connected',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected 
                            ? 'Your Google Calendar is synced'
                            : 'Connect to enable calendar sync',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (isConnected) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Last Sync Time
              _buildInfoRow(
                Icons.access_time,
                'Last Synced',
                connection.lastSyncTime != null
                    ? _formatDateTime(connection.lastSyncTime!)
                    : 'Never',
              ),
              const SizedBox(height: 12),
              
              // Calendar ID
              if (connection.googleCalendarId != null)
                _buildInfoRow(
                  Icons.calendar_today,
                  'Calendar',
                  connection.googleCalendarId!,
                ),
            ],
            
            const SizedBox(height: 20),
            
            // Connect/Disconnect Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: syncProvider.isSyncing
                    ? null
                    : () => isConnected
                        ? _handleDisconnect(context, syncProvider)
                        : _handleConnect(context, syncProvider),
                icon: Icon(isConnected ? Icons.link_off : Icons.link),
                label: Text(isConnected ? 'Disconnect' : 'Connect Google Calendar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? AppTheme.errorColor : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            // Show error if any
            if (syncProvider.syncError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        syncProvider.syncError!,
                        style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncControlsCard(GoogleCalendarSyncProvider syncProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync Controls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Auto-Sync Toggle
            SwitchListTile(
              value: syncProvider.syncEnabled,
              onChanged: (value) => syncProvider.toggleAutoSync(value),
              title: const Text('Auto-Sync'),
              subtitle: const Text('Automatically sync every 15 minutes'),
              secondary: const Icon(Icons.sync),
              activeColor: AppTheme.primaryColor,
            ),
            
            const Divider(),
            
            // Manual Sync Button
            ListTile(
              leading: syncProvider.isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              title: const Text('Manual Sync'),
              subtitle: Text(syncProvider.getSyncStatusText()),
              trailing: ElevatedButton(
                onPressed: syncProvider.isSyncing
                    ? null
                    : () => syncProvider.manualSync(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sync Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncHistoryCard(GoogleCalendarSyncProvider syncProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Sync History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ...syncProvider.syncHistory.take(5).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      entry.success ? Icons.check_circle : Icons.error,
                      color: entry.success ? AppTheme.successColor : AppTheme.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.itemsAffected} items synced',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _formatDateTime(entry.timestamp),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${entry.duration.inSeconds}s',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictsCard(GoogleCalendarSyncProvider syncProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.warningColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: AppTheme.warningColor),
                const SizedBox(width: 8),
                const Text(
                  'Sync Conflicts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${syncProvider.conflictCount} appointment${syncProvider.conflictCount > 1 ? 's' : ''} need${syncProvider.conflictCount > 1 ? '' : 's'} your attention',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to conflicts screen
                Navigator.pushNamed(context, '/calendar/conflicts');
              },
              icon: const Icon(Icons.rule),
              label: const Text('Resolve Conflicts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(GoogleCalendarSyncProvider syncProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              value: GoogleCalendarConfig.includePatientNamesInGoogleEvents,
              onChanged: null, // TODO: Make this configurable
              title: const Text('Include Patient Names'),
              subtitle: const Text('Show patient names in Google Calendar events'),
              secondary: const Icon(Icons.person),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help & Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildHelpItem(
              Icons.info_outline,
              'How it works',
              'Appointments sync automatically between MedWave and your Google Calendar',
            ),
            const SizedBox(height: 12),
            
            _buildHelpItem(
              Icons.schedule,
              'Sync frequency',
              'Auto-sync runs every 15 minutes when enabled',
            ),
            const SizedBox(height: 12),
            
            _buildHelpItem(
              Icons.security,
              'Your privacy',
              'Your Google account connection is secure and can be revoked anytime',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM d, y h:mm a').format(dateTime);
    }
  }

  Future<void> _handleConnect(BuildContext context, GoogleCalendarSyncProvider syncProvider) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to Google Calendar...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    final success = await syncProvider.connect();
    
    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to Google Calendar'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncProvider.syncError ?? 'Failed to connect'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleDisconnect(BuildContext context, GoogleCalendarSyncProvider syncProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'Your appointments will no longer sync with Google Calendar. '
          'Existing appointments will remain in both calendars.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      final success = await syncProvider.disconnect();
      
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Disconnected from Google Calendar'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(syncProvider.syncError ?? 'Failed to disconnect'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }
}


