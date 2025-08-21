import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              if (notificationProvider.unreadCount > 0) {
                return TextButton(
                  onPressed: () {
                    _showMarkAllReadDialog(context, notificationProvider);
                  },
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: Consumer<NotificationProvider>(
              builder: (context, notificationProvider, child) {
                if (notificationProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  );
                }

                final filteredNotifications = _getFilteredNotifications(
                  notificationProvider.notifications,
                );

                if (filteredNotifications.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () => notificationProvider.loadNotifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = filteredNotifications[index];
                      return _buildNotificationCard(notification, notificationProvider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', 'All', Icons.all_inbox),
            const SizedBox(width: 8),
            _buildFilterChip('unread', 'Unread', Icons.mark_email_unread),
            const SizedBox(width: 8),
            _buildFilterChip('urgent', 'Urgent', Icons.priority_high),
            const SizedBox(width: 8),
            _buildFilterChip('appointments', 'Appointments', Icons.calendar_today),
            const SizedBox(width: 8),
            _buildFilterChip('improvements', 'Improvements', Icons.trending_up),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppTheme.primaryColor,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
    );
  }

  List<AppNotification> _getFilteredNotifications(List<AppNotification> notifications) {
    switch (_selectedFilter) {
      case 'unread':
        return notifications.where((n) => !n.isRead).toList();
      case 'urgent':
        return notifications.where((n) => n.priority == NotificationPriority.urgent).toList();
      case 'appointments':
        return notifications.where((n) => n.type == NotificationType.appointment).toList();
      case 'improvements':
        return notifications.where((n) => n.type == NotificationType.improvement).toList();
      default:
        return notifications;
    }
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    switch (_selectedFilter) {
      case 'unread':
        message = 'No unread notifications';
        icon = Icons.mark_email_read;
        break;
      case 'urgent':
        message = 'No urgent notifications';
        icon = Icons.priority_high;
        break;
      case 'appointments':
        message = 'No appointment notifications';
        icon = Icons.calendar_today;
        break;
      case 'improvements':
        message = 'No improvement notifications';
        icon = Icons.trending_up;
        break;
      default:
        message = 'No notifications yet';
        icon = Icons.notifications_off;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see updates about patients and appointments here',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, NotificationProvider provider) {
    Color priorityColor;
    IconData priorityIcon;
    
    switch (notification.priority) {
      case NotificationPriority.urgent:
        priorityColor = AppTheme.errorColor;
        priorityIcon = Icons.priority_high;
        break;
      case NotificationPriority.high:
        priorityColor = AppTheme.warningColor;
        priorityIcon = Icons.notification_important;
        break;
      case NotificationPriority.medium:
        priorityColor = AppTheme.infoColor;
        priorityIcon = Icons.notifications;
        break;
      case NotificationPriority.low:
        priorityColor = AppTheme.secondaryColor;
        priorityIcon = Icons.notifications_none;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: notification.isRead ? null : Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            provider.markAsRead(notification.id);
          }
          if (notification.patientId != null) {
            context.push('/patients/${notification.patientId}');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(priorityIcon, color: priorityColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.secondaryColor.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, HH:mm').format(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor.withOpacity(0.6),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getTypeColor(notification.type).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            notification.type.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getTypeColor(notification.type),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppTheme.secondaryColor.withOpacity(0.4),
                ),
                onSelected: (value) {
                  if (value == 'mark_read' && !notification.isRead) {
                    provider.markAsRead(notification.id);
                  } else if (value == 'delete') {
                    _showDeleteDialog(context, notification, provider);
                  }
                },
                itemBuilder: (context) => [
                  if (!notification.isRead)
                    const PopupMenuItem(
                      value: 'mark_read',
                      child: Row(
                        children: [
                          Icon(Icons.mark_email_read, size: 18),
                          SizedBox(width: 8),
                          Text('Mark as read'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.improvement:
        return AppTheme.successColor;
      case NotificationType.appointment:
        return AppTheme.infoColor;
      case NotificationType.reminder:
        return AppTheme.warningColor;
      case NotificationType.alert:
        return AppTheme.errorColor;
    }
  }

  void _showMarkAllReadDialog(BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('Mark all as read'),
          ],
        ),
        content: const Text(
          'Are you sure you want to mark all notifications as read?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.markAllAsRead();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark all read'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AppNotification notification, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.errorColor),
            SizedBox(width: 12),
            Text('Delete notification'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this notification? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteNotification(notification.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
