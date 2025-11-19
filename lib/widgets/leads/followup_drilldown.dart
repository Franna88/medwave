import 'package:flutter/material.dart';
import '../../models/leads/lead.dart';
import '../../theme/app_theme.dart';
import 'lead_card.dart';

/// Widget for displaying follow-up leads organized by week
class FollowUpDrilldown extends StatefulWidget {
  final List<Lead> leads;
  final Function(Lead) onLeadTap;
  final Function(Lead, int) onWeekChange;

  const FollowUpDrilldown({
    super.key,
    required this.leads,
    required this.onLeadTap,
    required this.onWeekChange,
  });

  @override
  State<FollowUpDrilldown> createState() => _FollowUpDrilldownState();
}

class _FollowUpDrilldownState extends State<FollowUpDrilldown> {
  final Set<int> _expandedWeeks = {1}; // Week 1 expanded by default
  static const int maxWeeks = 10;

  @override
  Widget build(BuildContext context) {
    // Group leads by week
    final leadsByWeek = <int, List<Lead>>{};
    for (final lead in widget.leads) {
      final week = lead.followUpWeek ?? 1;
      leadsByWeek.putIfAbsent(week, () => []).add(lead);
    }

    return Column(
      children: List.generate(maxWeeks, (index) {
        final week = index + 1;
        final leadsInWeek = leadsByWeek[week] ?? [];
        final isExpanded = _expandedWeeks.contains(week);
        final hasLeads = leadsInWeek.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: hasLeads
                ? AppTheme.primaryColor.withOpacity(0.05)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasLeads
                  ? AppTheme.primaryColor.withOpacity(0.2)
                  : Colors.grey[200]!,
            ),
          ),
          child: Column(
            children: [
          // Week header with drop target
          DragTarget<Lead>(
            onWillAcceptWithDetails: (details) {
              return details.data.followUpWeek != week;
            },
            onAcceptWithDetails: (details) {
              widget.onWeekChange(details.data, week);
            },
            builder: (context, candidateData, rejectedData) {
              final isDraggingOver = candidateData.isNotEmpty;
              return InkWell(
                onTap: hasLeads
                    ? () {
                        setState(() {
                          if (isExpanded) {
                            _expandedWeeks.remove(week);
                          } else {
                            _expandedWeeks.add(week);
                          }
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: isDraggingOver
                      ? BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isDraggingOver
                            ? AppTheme.primaryColor
                            : (hasLeads
                                ? AppTheme.primaryColor
                                : Colors.grey[400]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Week $week',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDraggingOver
                                ? AppTheme.primaryColor
                                : (hasLeads ? Colors.black87 : Colors.grey[500]),
                          ),
                        ),
                      ),
                      // Lead count badge
                      if (hasLeads)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${leadsInWeek.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (hasLeads) ...[
                        const SizedBox(width: 8),
                        Icon(
                          isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

              // Leads in this week (if expanded)
              if (isExpanded && hasLeads)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Column(
                    children: leadsInWeek.map((lead) {
                      return Draggable<Lead>(
                        data: lead,
                        feedback: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 250,
                            child: Opacity(
                              opacity: 0.8,
                              child: LeadCard(
                                lead: lead,
                                isFollowUpStage: true,
                                onTap: () {},
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: LeadCard(
                            lead: lead,
                            isFollowUpStage: true,
                            onTap: () {},
                          ),
                        ),
                        child: LeadCard(
                          lead: lead,
                          isFollowUpStage: true,
                          onTap: () => widget.onLeadTap(lead),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              
              // Drop zone for empty or collapsed weeks
              if (!hasLeads || !isExpanded)
                DragTarget<Lead>(
                  onWillAcceptWithDetails: (details) {
                    // Accept if the lead is not already in this week
                    return details.data.followUpWeek != week;
                  },
                  onAcceptWithDetails: (details) {
                    widget.onWeekChange(details.data, week);
                  },
                  builder: (context, candidateData, rejectedData) {
                    if (candidateData.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Drop here for Week $week',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      }),
    );
  }
}

