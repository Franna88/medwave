import 'package:flutter/material.dart';
import 'package:medwave_app/theme/app_theme.dart';


class AnalyticsFiltersBar extends StatelessWidget {
  final String dateFilter;
  final String streamFilter;
  final Function(String) onDateFilterChanged;
  final Function(String) onStreamFilterChanged;
  final VoidCallback? onResetFilters;

  const AnalyticsFiltersBar({
    super.key,
    required this.dateFilter,
    required this.streamFilter,
    required this.onDateFilterChanged,
    required this.onStreamFilterChanged,
    this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = dateFilter != 'last30days' || streamFilter != 'all';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date Filter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: dateFilter != 'last30days' 
                      ? AppTheme.primaryColor 
                      : AppTheme.borderColor,
                  width: dateFilter != 'last30days' ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.cardColor,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: dateFilter != 'last30days' 
                        ? AppTheme.primaryColor 
                        : AppTheme.secondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: dateFilter,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.secondaryColor,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textColor,
                        fontWeight: dateFilter != 'last30days' 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'today', child: Text('Today')),
                        DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
                        DropdownMenuItem(value: 'last7days', child: Text('Last 7 Days')),
                        DropdownMenuItem(value: 'last30days', child: Text('Last 30 Days')),
                        DropdownMenuItem(value: 'last90days', child: Text('Last 90 Days')),
                        DropdownMenuItem(value: 'all', child: Text('All Time')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onDateFilterChanged(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Stream Filter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: streamFilter != 'all' 
                      ? AppTheme.primaryColor 
                      : AppTheme.borderColor,
                  width: streamFilter != 'all' ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.cardColor,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.stream,
                    size: 16,
                    color: streamFilter != 'all' 
                        ? AppTheme.primaryColor 
                        : AppTheme.secondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: streamFilter,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.secondaryColor,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textColor,
                        fontWeight: streamFilter != 'all' 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Streams')),
                        DropdownMenuItem(value: 'marketing', child: Text('Marketing')),
                        DropdownMenuItem(value: 'sales', child: Text('Sales')),
                        DropdownMenuItem(value: 'operations', child: Text('Operations')),
                        DropdownMenuItem(value: 'support', child: Text('Support')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onStreamFilterChanged(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Reset Filters Button
          if (isFiltered && onResetFilters != null)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: IconButton(
                onPressed: onResetFilters,
                icon: Icon(Icons.clear, color: AppTheme.primaryColor, size: 20),
                tooltip: 'Reset Filters',
              ),
            ),
        ],
      ),
    );
  }
}
