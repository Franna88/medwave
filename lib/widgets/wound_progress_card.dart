import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import 'firebase_image.dart';

class WoundProgressCard extends StatelessWidget {
  final Wound currentWound;
  final Wound? previousWound;
  final int woundIndex;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  const WoundProgressCard({
    super.key,
    required this.currentWound,
    this.previousWound,
    required this.woundIndex,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? AppTheme.primaryColor : AppTheme.borderColor,
          width: isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded 
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: isExpanded ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildWoundHeader(),
          if (isExpanded) _buildWoundDetails(),
        ],
      ),
    );
  }

  Widget _buildWoundHeader() {
    final hasProgress = previousWound != null;
    final areaChange = hasProgress 
        ? ((previousWound!.area - currentWound.area) / previousWound!.area * 100)
        : 0.0;
    final isImproving = areaChange > 0;
    
    return GestureDetector(
      onTap: onToggleExpanded,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isExpanded 
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isExpanded ? Radius.zero : const Radius.circular(16),
            bottomRight: isExpanded ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            // Wound number and status indicator
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: _getStatusColor(), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${woundIndex + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(),
                    ),
                  ),
                  if (hasProgress)
                    Icon(
                      isImproving ? Icons.trending_up : Icons.trending_down,
                      color: _getStatusColor(),
                      size: 12,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Wound info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentWound.location,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentWound.type,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuickStat(
                        'Area',
                        '${currentWound.area.toStringAsFixed(1)} cm²',
                        Icons.crop_free,
                      ),
                      const SizedBox(width: 16),
                      _buildQuickStat(
                        'Stage',
                        _getStageShort(currentWound.stage),
                        Icons.layers,
                      ),
                      if (hasProgress) ...[
                        const SizedBox(width: 16),
                        _buildProgressIndicator(areaChange, isImproving),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Expand/collapse icon
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppTheme.secondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWoundDetails() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current measurements
          _buildMeasurementsSection(),
          const SizedBox(height: 20),
          
          // Progress comparison if available
          if (previousWound != null) ...[
            _buildProgressSection(),
            const SizedBox(height: 20),
          ],
          
          // Description
          if (currentWound.description.isNotEmpty) ...[
            _buildDescriptionSection(),
            const SizedBox(height: 20),
          ],
          
          // Photos
          if (currentWound.photos.isNotEmpty) _buildPhotosSection(),
        ],
      ),
    );
  }

  Widget _buildMeasurementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Measurements',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMeasurementItem(
                      'Length',
                      '${currentWound.length.toStringAsFixed(1)} cm',
                      Icons.straighten,
                    ),
                  ),
                  Expanded(
                    child: _buildMeasurementItem(
                      'Width',
                      '${currentWound.width.toStringAsFixed(1)} cm',
                      Icons.width_full,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMeasurementItem(
                      'Depth',
                      '${currentWound.depth.toStringAsFixed(1)} cm',
                      Icons.height,
                    ),
                  ),
                  Expanded(
                    child: _buildMeasurementItem(
                      'Volume',
                      '${currentWound.volume.toStringAsFixed(1)} cm³',
                      Icons.view_in_ar,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    final lengthChange = currentWound.length - previousWound!.length;
    final widthChange = currentWound.width - previousWound!.width;
    final depthChange = currentWound.depth - previousWound!.depth;
    final areaChange = currentWound.area - previousWound!.area;
    final volumeChange = currentWound.volume - previousWound!.volume;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progress Since Last Session',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildProgressItem('Length', lengthChange, 'cm'),
              _buildProgressItem('Width', widthChange, 'cm'),
              _buildProgressItem('Depth', depthChange, 'cm'),
              _buildProgressItem('Area', areaChange, 'cm²'),
              _buildProgressItem('Volume', volumeChange, 'cm³'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assessment Notes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            currentWound.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textColor,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentWound.photos.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: currentWound.photos.length,
            itemBuilder: (context, index) {
              return Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FirebaseImage(
                    imagePath: currentWound.photos[index],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      width: 80,
                      height: 80,
                      color: AppTheme.backgroundColor,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: AppTheme.secondaryColor,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.secondaryColor),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.secondaryColor,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(double changePercent, bool isImproving) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isImproving 
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImproving ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
          ),
          const SizedBox(width: 4),
          Text(
            '${changePercent.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryColor,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressItem(String label, double change, String unit) {
    final isImproving = change < 0; // Negative change is improvement (smaller wound)
    final color = isImproving ? AppTheme.successColor : AppTheme.errorColor;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textColor,
            ),
          ),
          Row(
            children: [
              Icon(
                isImproving ? Icons.trending_down : Icons.trending_up,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (previousWound == null) return AppTheme.infoColor;
    
    final areaChange = (previousWound!.area - currentWound.area) / previousWound!.area;
    
    if (areaChange > 0.1) return AppTheme.successColor; // Significant improvement
    if (areaChange < -0.1) return AppTheme.errorColor; // Getting worse
    return AppTheme.warningColor; // Stable/minimal change
  }

  String _getStageShort(WoundStage stage) {
    switch (stage) {
      case WoundStage.stage1:
        return 'I';
      case WoundStage.stage2:
        return 'II';
      case WoundStage.stage3:
        return 'III';
      case WoundStage.stage4:
        return 'IV';
      case WoundStage.unstageable:
        return 'U';
      case WoundStage.deepTissueInjury:
        return 'DTI';
    }
  }
}
