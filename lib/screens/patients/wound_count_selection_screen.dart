import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class WoundCountSelectionScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const WoundCountSelectionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<WoundCountSelectionScreen> createState() => _WoundCountSelectionScreenState();
}

class _WoundCountSelectionScreenState extends State<WoundCountSelectionScreen> {
  String? _selectedWoundType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildModernHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInstructionCard(),
                  const SizedBox(height: 24),
                  _buildWoundTypeSelection(),
                  const SizedBox(height: 32),
                  _buildInfoCards(),
                ],
              ),
            ),
          ),
          _buildContinueButton(),
        ],
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Case History Setup',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Wound Assessment Type',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.patientName,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the appropriate assessment type for this patient',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline,
              color: AppTheme.infoColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Assessment Type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.infoColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please select whether this patient has a single wound or multiple wounds. This will determine the appropriate case history workflow for optimal documentation and treatment tracking.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.infoColor.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWoundTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How many wounds does this patient have?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 16),
        
        // Single Wound Option
        _buildWoundTypeOption(
          value: 'single',
          title: 'Single Wound',
          subtitle: 'Patient has one wound to assess and track',
          icon: Icons.healing,
          color: AppTheme.successColor,
          features: [
            'Streamlined assessment process',
            'Quick case history setup',
            'Focused progress tracking',
            'Standard reporting format',
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Multiple Wounds Option
        _buildWoundTypeOption(
          value: 'multiple',
          title: 'Multiple Wounds',
          subtitle: 'Patient has 2 or more wounds to assess and track',
          icon: Icons.medical_information,
          color: AppTheme.primaryColor,
          features: [
            'Individual wound tracking',
            'Comprehensive assessment per wound',
            'Detailed progress comparison',
            'Advanced reporting capabilities',
          ],
        ),
      ],
    );
  }

  Widget _buildWoundTypeOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> features,
  }) {
    final isSelected = _selectedWoundType == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWoundType = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? color.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Radio Button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : AppTheme.borderColor,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected 
                          ? color.withOpacity(0.8)
                          : AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Features
                  ...features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? color : AppTheme.secondaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected 
                                  ? color.withOpacity(0.7)
                                  : AppTheme.secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        _buildInfoCard(
          'Single Wound Workflow',
          'Perfect for patients with one wound. Uses our streamlined process that you\'re already familiar with - no changes to your current workflow.',
          Icons.speed,
          AppTheme.successColor,
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          'Multiple Wound Workflow',
          'Designed for complex cases with 2+ wounds. Each wound gets individual tracking, measurements, and photos while maintaining comprehensive patient overview.',
          Icons.analytics,
          AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedWoundType != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedWoundType == 'single' 
                        ? 'Single wound assessment selected'
                        : 'Multiple wound assessment selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedWoundType != null ? _continueToAssessment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _selectedWoundType != null ? 2 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _selectedWoundType == null 
                        ? 'Select wound type to continue'
                        : 'Continue to Case History',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_selectedWoundType != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _continueToAssessment() {
    if (_selectedWoundType == null) return;

    if (_selectedWoundType == 'single') {
      // Route to existing single wound case history (no changes needed)
      context.push('/patients/${widget.patientId}/case-history');
    } else {
      // Route to new multiple wound case history (to be implemented next)
      context.push('/patients/${widget.patientId}/multi-wound-case-history');
    }
  }
}
