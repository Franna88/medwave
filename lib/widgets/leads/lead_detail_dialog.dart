import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leads/lead.dart';
import '../../models/leads/lead_channel.dart';
import '../../theme/app_theme.dart';

/// Dialog for viewing full lead details and history
class LeadDetailDialog extends StatelessWidget {
  final Lead lead;
  final LeadChannel channel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const LeadDetailDialog({
    super.key,
    required this.lead,
    required this.channel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      lead.initials,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current Stage: ${_getStageName(lead.currentStage)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
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
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contact Information
                    _buildSection(
                      'Contact Information',
                      Icons.contact_mail,
                      [
                        _buildInfoRow(Icons.email, 'Email', lead.email),
                        _buildInfoRow(Icons.phone, 'Phone', lead.phone),
                        if (lead.source.isNotEmpty)
                          _buildInfoRow(Icons.source, 'Source', lead.source),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // UTM Tracking Information (if available)
                    if (lead.utmCampaign != null || lead.utmAdset != null || lead.utmAd != null)
                      _buildSection(
                        'Campaign Tracking',
                        Icons.track_changes,
                        [
                          if (lead.utmCampaign != null)
                            _buildInfoRow(
                              Icons.campaign,
                              'Campaign',
                              lead.utmCampaign!,
                            ),
                          if (lead.utmAdset != null)
                            _buildInfoRow(
                              Icons.group_work,
                              'Ad Set',
                              lead.utmAdset!,
                            ),
                          if (lead.utmAd != null)
                            _buildInfoRow(
                              Icons.image,
                              'Ad Name',
                              lead.utmAd!,
                            ),
                          if (lead.utmSource != null)
                            _buildInfoRow(
                              Icons.source,
                              'UTM Source',
                              lead.utmSource!,
                            ),
                          if (lead.utmMedium != null)
                            _buildInfoRow(
                              Icons.trending_up,
                              'UTM Medium',
                              lead.utmMedium!,
                            ),
                        ],
                      ),
                    if (lead.utmCampaign != null || lead.utmAdset != null || lead.utmAd != null)
                      const SizedBox(height: 24),

                    // Current Status
                    _buildSection(
                      'Current Status',
                      Icons.info_outline,
                      [
                        _buildInfoRow(
                          Icons.access_time,
                          'Time in Stage',
                          _formatDuration(lead.timeInStage),
                        ),
                        if (lead.followUpWeek != null)
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Follow-up Week',
                            'Week ${lead.followUpWeek}',
                          ),
                        _buildInfoRow(
                          Icons.person,
                          'Created By',
                          lead.createdByName ?? 'Unknown',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Booking Information
                    if (lead.bookingId != null)
                      _buildSection(
                        'Booking Information',
                        Icons.calendar_today,
                        [
                          if (lead.bookingDate != null)
                            _buildInfoRow(
                              Icons.event,
                              'Booking Date',
                              DateFormat('MMM dd, yyyy').format(lead.bookingDate!),
                            ),
                          if (lead.bookingStatus != null)
                            _buildInfoRow(
                              Icons.info,
                              'Status',
                              lead.bookingStatus!.toUpperCase(),
                            ),
                          _buildInfoRow(
                            Icons.link,
                            'Booking ID',
                            lead.bookingId!,
                          ),
                        ],
                      ),
                    if (lead.bookingId != null)
                      const SizedBox(height: 24),

                    // Payment Information
                    if (lead.depositAmount != null || lead.cashCollectedAmount != null)
                      _buildSection(
                        'Payment Information',
                        Icons.payments,
                        [
                          if (lead.depositAmount != null) ...[
                            _buildInfoRow(
                              Icons.account_balance_wallet,
                              'Deposit Amount',
                              'R ${lead.depositAmount!.toStringAsFixed(2)}',
                            ),
                            if (lead.depositInvoiceNumber != null)
                              _buildInfoRow(
                                Icons.receipt,
                                'Deposit Invoice',
                                lead.depositInvoiceNumber!,
                              ),
                          ],
                          if (lead.cashCollectedAmount != null) ...[
                            _buildInfoRow(
                              Icons.money,
                              'Cash Collected',
                              'R ${lead.cashCollectedAmount!.toStringAsFixed(2)}',
                            ),
                            if (lead.cashCollectedInvoiceNumber != null)
                              _buildInfoRow(
                                Icons.receipt_long,
                                'Cash Invoice',
                                lead.cashCollectedInvoiceNumber!,
                              ),
                          ],
                        ],
                      ),
                    if (lead.depositAmount != null || lead.cashCollectedAmount != null)
                      const SizedBox(height: 24),

                    // Stage History (newest first)
                    _buildSection(
                      'Stage History',
                      Icons.timeline,
                      [
                        ...lead.stageHistory.reversed.map((entry) {
                          return _buildHistoryEntry(entry);
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Notes (newest first)
                    if (lead.notes.isNotEmpty)
                      _buildSection(
                        'Notes',
                        Icons.note,
                        [
                          ...lead.notes.reversed.map((note) {
                            return _buildNoteEntry(note);
                          }).toList(),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDelete();
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Delete Lead',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEdit();
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Lead'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
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

  Widget _buildHistoryEntry(StageHistoryEntry entry) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: entry.exitedAt == null
                      ? Colors.green
                      : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getStageName(entry.stage),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Entered: ${dateFormat.format(entry.enteredAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (entry.exitedAt != null)
            Text(
              'Exited: ${dateFormat.format(entry.exitedAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.note!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteEntry(note) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final isWeekTransition = note.stageTransition != null && 
                             note.stageTransition!.contains('Week');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWeekTransition ? Colors.orange[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWeekTransition ? Colors.orange[100]! : Colors.blue[100]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWeekTransition ? Icons.calendar_month : Icons.person,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                note.createdByName ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                dateFormat.format(note.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          if (note.stageTransition != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isWeekTransition 
                    ? Colors.orange[100]
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isWeekTransition ? Icons.event_repeat : Icons.swap_horiz,
                    size: 12,
                    color: isWeekTransition ? Colors.orange[700] : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    note.stageTransition!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isWeekTransition ? Colors.orange[700] : AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            note.text,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _getStageName(String stageId) {
    final stage = channel.getStageById(stageId);
    return stage?.name ?? stageId;
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays == 1 ? '' : 's'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours == 1 ? '' : 's'}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'}';
    }
  }
}

