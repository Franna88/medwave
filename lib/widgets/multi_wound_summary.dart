import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';

class MultiWoundSummary extends StatelessWidget {
  final List<Wound> currentWounds;
  final List<Wound>? previousWounds;
  final Session currentSession;
  final Session? previousSession;

  const MultiWoundSummary({
    super.key,
    required this.currentWounds,
    this.previousWounds,
    required this.currentSession,
    this.previousSession,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverallSummaryCard(),
        const SizedBox(height: 16),
        _buildWoundStageDistribution(),
        const SizedBox(height: 16),
        _buildHealingProgressChart(),
        const SizedBox(height: 16),
        _buildQuickWoundList(),
      ],
    );
  }

  Widget _buildOverallSummaryCard() {
    final totalArea = currentWounds.fold<double>(0, (sum, wound) => sum + wound.area);
    final totalVolume = currentWounds.fold<double>(0, (sum, wound) => sum + wound.volume);
    final averageStage = _calculateAverageStage();
    
    double? areaChange;
    if (previousWounds != null && previousWounds!.isNotEmpty) {
      final previousTotalArea = previousWounds!.fold<double>(0, (sum, wound) => sum + wound.area);
      areaChange = ((previousTotalArea - totalArea) / previousTotalArea * 100);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medical_information,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multi-Wound Summary',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    Text(
                      '${currentWounds.length} wounds assessed',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (areaChange != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: areaChange > 0 
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        areaChange > 0 ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: areaChange > 0 ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${areaChange.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: areaChange > 0 ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Key metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Total Area',
                  '${totalArea.toStringAsFixed(1)} cm²',
                  Icons.crop_free,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Total Volume',
                  '${totalVolume.toStringAsFixed(1)} cm³',
                  Icons.view_in_ar,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Avg Stage',
                  _formatAverageStage(averageStage),
                  Icons.layers,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWoundStageDistribution() {
    final stageDistribution = <WoundStage, int>{};
    
    for (final wound in currentWounds) {
      stageDistribution[wound.stage] = (stageDistribution[wound.stage] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wound Stage Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          // Stage distribution bars
          ...stageDistribution.entries.map((entry) {
            final percentage = (entry.value / currentWounds.length * 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getStageDisplayName(entry.key),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                      Text(
                        '${entry.value} wound${entry.value != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percentage / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getStageColor(entry.key),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHealingProgressChart() {
    if (previousWounds == null || previousWounds!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Healing Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.infoColor),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Progress tracking will be available after the next session',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.infoColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Individual Wound Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          // Progress bars for each wound
          ...currentWounds.asMap().entries.map((entry) {
            final index = entry.key;
            final currentWound = entry.value;
            final previousWound = _findMatchingPreviousWound(currentWound);
            
            if (previousWound == null) {
              return const SizedBox.shrink();
            }
            
            final areaChange = (previousWound.area - currentWound.area) / previousWound.area * 100;
            final isImproving = areaChange > 0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Wound ${index + 1}: ${currentWound.location}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            isImproving ? Icons.trending_up : Icons.trending_down,
                            size: 16,
                            color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${areaChange.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (areaChange.abs() / 50).clamp(0.1, 1.0), // Scale to 50% max change
                      child: Container(
                        decoration: BoxDecoration(
                          color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildQuickWoundList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wound Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          ...currentWounds.asMap().entries.map((entry) {
            final index = entry.key;
            final wound = entry.value;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wound.location,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor,
                          ),
                        ),
                        Text(
                          '${wound.type} • ${_getStageDisplayName(wound.stage)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${wound.area.toStringAsFixed(1)} cm²',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryColor,
          ),
        ),
      ],
    );
  }

  double _calculateAverageStage() {
    if (currentWounds.isEmpty) return 0;
    
    final totalStageValue = currentWounds.fold<int>(0, (sum, wound) {
      return sum + (wound.stage.index + 1); // +1 because index starts at 0
    });
    
    return totalStageValue / currentWounds.length;
  }

  String _formatAverageStage(double avgStage) {
    if (avgStage <= 1.5) return 'Stage I';
    if (avgStage <= 2.5) return 'Stage II';
    if (avgStage <= 3.5) return 'Stage III';
    if (avgStage <= 4.5) return 'Stage IV';
    return 'Mixed';
  }

  String _getStageDisplayName(WoundStage stage) {
    switch (stage) {
      case WoundStage.stage1:
        return 'Stage I';
      case WoundStage.stage2:
        return 'Stage II';
      case WoundStage.stage3:
        return 'Stage III';
      case WoundStage.stage4:
        return 'Stage IV';
      case WoundStage.unstageable:
        return 'Unstageable';
      case WoundStage.deepTissueInjury:
        return 'Deep Tissue';
    }
  }

  Color _getStageColor(WoundStage stage) {
    switch (stage) {
      case WoundStage.stage1:
        return AppTheme.successColor;
      case WoundStage.stage2:
        return AppTheme.warningColor;
      case WoundStage.stage3:
        return Colors.orange;
      case WoundStage.stage4:
        return AppTheme.errorColor;
      case WoundStage.unstageable:
        return Colors.purple;
      case WoundStage.deepTissueInjury:
        return Colors.indigo;
    }
  }

  Wound? _findMatchingPreviousWound(Wound currentWound) {
    if (previousWounds == null) return null;
    
    return previousWounds!.firstWhere(
      (w) => w.id == currentWound.id,
      orElse: () => previousWounds!.first, // Fallback to first wound if no ID match
    );
  }
}
