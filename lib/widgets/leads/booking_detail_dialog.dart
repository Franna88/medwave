import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leads/lead_booking.dart';
import '../../services/firebase/lead_booking_service.dart';
import '../../theme/app_theme.dart';

/// Dialog for viewing and managing booking details
class BookingDetailDialog extends StatefulWidget {
  final LeadBooking booking;
  final Function(LeadBooking)? onBookingUpdated;

  const BookingDetailDialog({
    super.key,
    required this.booking,
    this.onBookingUpdated,
  });

  @override
  State<BookingDetailDialog> createState() => _BookingDetailDialogState();
}

class _BookingDetailDialogState extends State<BookingDetailDialog> {
  final _callNotesController = TextEditingController();
  final _bookingService = LeadBookingService();
  String? _selectedOutcome;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _callOutcomes = [
    {'value': 'interested', 'label': 'Interested', 'icon': Icons.thumb_up},
    {'value': 'not_ready', 'label': 'Not Ready', 'icon': Icons.schedule},
    {'value': 'no_show', 'label': 'No Show', 'icon': Icons.person_off},
    {'value': 'closed_won', 'label': 'Closed - Won', 'icon': Icons.celebration},
    {'value': 'closed_lost', 'label': 'Closed - Lost', 'icon': Icons.cancel},
  ];

  @override
  void initState() {
    super.initState();
    _callNotesController.text = widget.booking.callNotes ?? '';
    _selectedOutcome = widget.booking.callOutcome;
  }

  @override
  void dispose() {
    _callNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveCallDetails() async {
    setState(() => _isSaving = true);
    try {
      await _bookingService.updateCallDetails(
        bookingId: widget.booking.id,
        callNotes: _callNotesController.text.trim(),
        callOutcome: _selectedOutcome,
      );

      final updatedBooking = widget.booking.copyWith(
        callNotes: _callNotesController.text.trim(),
        callOutcome: _selectedOutcome,
      );

      widget.onBookingUpdated?.call(updatedBooking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call details saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _completeCall() async {
    if (_callNotesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add call notes before completing')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _saveCallDetails();
      await _bookingService.updateBookingStatus(
        widget.booking.id,
        BookingStatus.completed,
      );

      final updatedBooking = widget.booking.copyWith(
        status: BookingStatus.completed,
        callNotes: _callNotesController.text.trim(),
        callOutcome: _selectedOutcome,
      );

      widget.onBookingUpdated?.call(updatedBooking);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call marked as completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing call: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final formattedDate = dateFormat.format(widget.booking.bookingDate);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appointment - ${widget.booking.leadName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '$formattedDate at ${widget.booking.formattedTime}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.booking.duration} min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lead Information
                    _buildSection(
                      title: '👤 Lead Information',
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.person, 'Name', widget.booking.leadName),
                          _buildInfoRow(Icons.email, 'Email', widget.booking.leadEmail),
                          _buildInfoRow(Icons.phone, 'Phone', widget.booking.leadPhone),
                          _buildInfoRow(
                            Icons.source,
                            'Source',
                            widget.booking.leadSource,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Lead Journey
                    if (widget.booking.leadHistory.isNotEmpty)
                      _buildSection(
                        title: '🗺️ Lead Journey',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.booking.leadHistory.map((step) {
                            final index = widget.booking.leadHistory.indexOf(step);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    step,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                if (index < widget.booking.leadHistory.length - 1)
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    if (widget.booking.leadHistory.isNotEmpty)
                      const SizedBox(height: 20),

                    // Call Notes
                    _buildSection(
                      title: '📝 Call Notes',
                      child: TextField(
                        controller: _callNotesController,
                        decoration: InputDecoration(
                          hintText: 'Enter your notes during or after the call...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 6,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // AI Call Preparation
                    _buildSection(
                      title: '🤖 AI Call Preparation',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Suggested Questions
                            const Text(
                              'Suggested Questions:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...widget.booking.aiPrompts.suggestedQuestions.map(
                              (q) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• ', style: TextStyle(color: Colors.blue[700])),
                                    Expanded(
                                      child: Text(
                                        q,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Key Points
                            const Text(
                              'Key Points to Cover:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...widget.booking.aiPrompts.keyPoints.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• ', style: TextStyle(color: Colors.blue[700])),
                                    Expanded(
                                      child: Text(
                                        p,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Call Outcome
                    const Text(
                      'Call Outcome:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _callOutcomes.map((outcome) {
                        final isSelected = _selectedOutcome == outcome['value'];
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedOutcome = outcome['value'] as String;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.warningColor
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.warningColor
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  outcome['icon'] as IconData,
                                  size: 16,
                                  color: isSelected ? Colors.white : Colors.grey[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  outcome['label'] as String,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _isSaving ? null : _saveCallDetails,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Notes'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _completeCall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Complete Call',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

