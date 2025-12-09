import 'package:flutter/material.dart';
import '../../models/admin/admin_user.dart';
import '../../services/firebase/lead_booking_service.dart';
import '../../theme/app_theme.dart';

/// Widget to display sales admin availability overview
class SalesAdminAvailabilityWidget extends StatelessWidget {
  final List<AdminUser> salesAdmins;
  final Map<String, AdminAvailability> availabilityMap;
  final String? selectedAdminId;
  final Function(String?) onAdminSelected;
  final bool isLoading;

  const SalesAdminAvailabilityWidget({
    super.key,
    required this.salesAdmins,
    required this.availabilityMap,
    this.selectedAdminId,
    required this.onAdminSelected,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (salesAdmins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No sales admins available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👤 Select Sales Admin',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...salesAdmins.map((admin) {
          final availability = availabilityMap[admin.userId];
          final isSelected = selectedAdminId == admin.userId;
          final isAvailable = availability?.isAvailable ?? false;
          final availableSlots = availability?.availableSlotsCount ?? 0;
          final hasConflicts = (availability?.conflictingBookings.length ?? 0) > 0 ||
              (availability?.conflictingAppointments.length ?? 0) > 0;

          return _buildAdminCard(
            admin: admin,
            isSelected: isSelected,
            isAvailable: isAvailable,
            availableSlots: availableSlots,
            hasConflicts: hasConflicts,
            onTap: () => onAdminSelected(admin.userId),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAdminCard({
    required AdminUser admin,
    required bool isSelected,
    required bool isAvailable,
    required int availableSlots,
    required bool hasConflicts,
    required VoidCallback onTap,
  }) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isAvailable) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Available';
    } else if (hasConflicts) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Busy';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Limited';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.05)
            : Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Selection indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey[400]!,
                      width: 2,
                    ),
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Admin info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        admin.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 14,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$availableSlots slots available',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

