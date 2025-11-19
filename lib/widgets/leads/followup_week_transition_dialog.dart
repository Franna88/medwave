import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Result data from follow-up week transition
class FollowUpWeekTransitionResult {
  final String reason;
  final String? additionalNote;

  FollowUpWeekTransitionResult({
    required this.reason,
    this.additionalNote,
  });
}

/// Dialog for moving leads between follow-up weeks
class FollowUpWeekTransitionDialog extends StatefulWidget {
  final String leadName;
  final int fromWeek;
  final int toWeek;

  const FollowUpWeekTransitionDialog({
    super.key,
    required this.leadName,
    required this.fromWeek,
    required this.toWeek,
  });

  @override
  State<FollowUpWeekTransitionDialog> createState() =>
      _FollowUpWeekTransitionDialogState();
}

class _FollowUpWeekTransitionDialogState
    extends State<FollowUpWeekTransitionDialog> {
  final _noteController = TextEditingController();
  String? _selectedReason;

  final List<Map<String, dynamic>> _quickReasons = [
    {'label': 'No Answer', 'icon': Icons.phone_missed, 'color': Colors.orange},
    {'label': 'Postponed', 'icon': Icons.schedule, 'color': Colors.blue},
    {'label': 'No Show', 'icon': Icons.event_busy, 'color': Colors.red},
    {'label': 'Rescheduled', 'icon': Icons.event_repeat, 'color': Colors.purple},
    {'label': 'Busy', 'icon': Icons.work, 'color': Colors.amber},
    {'label': 'Not Interested', 'icon': Icons.thumb_down, 'color': Colors.grey},
    {'label': 'Follow Up Later', 'icon': Icons.access_time, 'color': Colors.teal},
    {'label': 'Needs More Time', 'icon': Icons.hourglass_empty, 'color': Colors.indigo},
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMovingForward = widget.toWeek > widget.fromWeek;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Move Follow-up Week',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.leadName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Week transition visual
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Week ${widget.fromWeek}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isMovingForward ? Icons.arrow_forward : Icons.arrow_back,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Week ${widget.toWeek}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick reason selection
            Text(
              'Select reason *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickReasons.map((reason) {
                    final isSelected = _selectedReason == reason['label'];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedReason = reason['label'];
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (reason['color'] as Color).withOpacity(0.15)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? (reason['color'] as Color)
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              reason['icon'] as IconData,
                              size: 18,
                              color: isSelected
                                  ? (reason['color'] as Color)
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              reason['label'],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? (reason['color'] as Color)
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Optional additional note
            Text(
              'Additional note (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add any additional details...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedReason == null
                      ? null
                      : () {
                          final additionalNote = _noteController.text.trim();
                          final result = FollowUpWeekTransitionResult(
                            reason: _selectedReason!,
                            additionalNote:
                                additionalNote.isEmpty ? null : additionalNote,
                          );
                          Navigator.of(context).pop(result);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Confirm Move'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

