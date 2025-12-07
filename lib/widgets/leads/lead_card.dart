import 'package:flutter/material.dart';
import '../../models/leads/lead.dart';
import '../../theme/app_theme.dart';
import '../../utils/stream_utils.dart';

/// Compact card widget for displaying a lead in the Kanban board
class LeadCard extends StatelessWidget {
  final Lead lead;
  final bool isFollowUpStage;
  final VoidCallback onTap;

  const LeadCard({
    super.key,
    required this.lead,
    this.isFollowUpStage = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with avatar and time in stage
              Row(
                children: [
                  // Avatar with initials
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _getAvatarColor(),
                    child: Text(
                      lead.initials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name
                  Expanded(
                    child: Text(
                      lead.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Time in stage badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getTimeColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      lead.timeInStageDisplay,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getTimeColor(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Contact info
              if (lead.email.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lead.email,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              if (lead.phone.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      lead.phone,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],

              // Assigned to badge
              if (lead.assignedToName != null &&
                  lead.assignedToName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 10,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Assigned: ${lead.assignedToName}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Badges row
              if ((isFollowUpStage && lead.followUpWeek != null) ||
                  lead.bookingId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Follow-up week badge
                    if (isFollowUpStage && lead.followUpWeek != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Week ${lead.followUpWeek}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Booking badge
                    if (lead.bookingId != null) ...[
                      if (isFollowUpStage && lead.followUpWeek != null)
                        const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.successColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event,
                              size: 12,
                              color: AppTheme.successColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Booked',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              if (lead.formScore != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _getScoreColor().withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Score ${lead.formScore!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getScoreColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Get avatar color based on lead name
  Color _getAvatarColor() {
    final colors = [
      AppTheme.primaryColor,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final index = lead.fullName.hashCode % colors.length;
    return colors[index.abs()];
  }

  /// Get time color based on duration in stage
  Color _getTimeColor() {
    final hours = lead.timeInStage.inHours;
    if (hours < 24) {
      return Colors.green;
    } else if (hours < 72) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Color _getScoreColor() {
    final tier = StreamUtils.getFormScoreTier(lead.formScore);
    switch (tier) {
      case FormScoreTier.high:
        return Colors.green;
      case FormScoreTier.mid:
        return Colors.orange;
      case FormScoreTier.low:
        return Colors.red;
      case FormScoreTier.none:
        return Colors.grey;
    }
  }
}
