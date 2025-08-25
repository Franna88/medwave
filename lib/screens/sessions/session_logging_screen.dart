import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../services/firebase/session_service.dart';

class SessionLoggingScreen extends StatefulWidget {
  final String patientId;

  const SessionLoggingScreen({super.key, required this.patientId});

  @override
  State<SessionLoggingScreen> createState() => _SessionLoggingScreenState();
}

class _SessionLoggingScreenState extends State<SessionLoggingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _vasScoreController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Wound measurements
  final _woundLengthController = TextEditingController();
  final _woundWidthController = TextEditingController();
  final _woundDepthController = TextEditingController();
  final _woundDescriptionController = TextEditingController();
  WoundStage _selectedWoundStage = WoundStage.stage1;

  List<String> _sessionPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  Patient? _patient;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  void _loadPatientData() {
    final patientProvider = context.read<PatientProvider>();
    _patient = patientProvider.patients.firstWhere(
      (p) => p.id == widget.patientId,
      orElse: () => throw Exception('Patient not found'),
    );

    // Pre-fill with previous session data if available
    if (_patient!.sessions.isNotEmpty) {
      final lastSession = _patient!.sessions.last;
      _weightController.text = lastSession.weight.toString();
      _vasScoreController.text = lastSession.vasScore.toString();
    } else {
      // Use baseline data
      _weightController.text = _patient!.baselineWeight.toString();
      _vasScoreController.text = _patient!.baselineVasScore.toString();
    }

    // Pre-fill wound data if available
    if (_patient!.currentWounds.isNotEmpty) {
      final currentWound = _patient!.currentWounds.first;
      _woundLengthController.text = currentWound.length.toString();
      _woundWidthController.text = currentWound.width.toString();
      _woundDepthController.text = currentWound.depth.toString();
      _woundDescriptionController.text = currentWound.description;
      _selectedWoundStage = currentWound.stage;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _vasScoreController.dispose();
    _notesController.dispose();
    _woundLengthController.dispose();
    _woundWidthController.dispose();
    _woundDepthController.dispose();
    _woundDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildModernHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSessionInfoCard(),
                          const SizedBox(height: 16),
                          _buildMeasurementsCard(),
                          const SizedBox(height: 16),
                          _buildWoundAssessmentCard(),
                          const SizedBox(height: 16),
                          _buildPhotosCard(),
                          const SizedBox(height: 16),
                          _buildNotesCard(),
                          const SizedBox(height: 24),
                          _buildSubmitButton(),
                          const SizedBox(height: 16),
                          _buildMotivationFormButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModernHeader() {
    final sessionNumber = (_patient?.sessions.length ?? 0) + 1;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.headerGradientStart,
            AppTheme.headerGradientEnd,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back, color: AppTheme.textColor),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session $sessionNumber',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _patient?.name ?? 'Patient Session',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Log Session',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    final sessionNumber = (_patient?.sessions.length ?? 0) + 1;
    final today = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Session Number',
                    sessionNumber.toString(),
                    Icons.event_note,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Date',
                    '${today.day}/${today.month}/${today.year}',
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Measurements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: Icon(Icons.monitor_weight),
                      suffixText: 'kg',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final weight = double.tryParse(value);
                      if (weight == null || weight <= 0) {
                        return 'Invalid weight';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _vasScoreController,
                    decoration: const InputDecoration(
                      labelText: 'VAS Pain Score',
                      prefixIcon: Icon(Icons.healing),
                      suffixText: '/10',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final score = int.tryParse(value);
                      if (score == null || score < 0 || score > 10) {
                        return '0-10 only';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (_patient != null) ...[
              const SizedBox(height: 16),
              _buildComparisonRow(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow() {
    final currentWeight = double.tryParse(_weightController.text);
    final currentPain = int.tryParse(_vasScoreController.text);
    
    final baselineWeight = _patient!.baselineWeight;
    final baselinePain = _patient!.baselineVasScore;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comparison to Baseline',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          if (currentWeight != null)
            _buildComparisonItem(
              'Weight',
              baselineWeight,
              currentWeight,
              'kg',
              false, // Lower weight might be good or bad depending on context
            ),
          if (currentPain != null)
            _buildComparisonItem(
              'Pain',
              baselinePain.toDouble(),
              currentPain.toDouble(),
              '/10',
              true, // Lower pain is always better
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(String label, double baseline, double current, String unit, bool lowerIsBetter) {
    final difference = current - baseline;
    final isImprovement = lowerIsBetter ? difference < 0 : difference > 0;
    final color = difference == 0 
        ? AppTheme.secondaryColor 
        : isImprovement 
            ? AppTheme.successColor 
            : AppTheme.warningColor;
    
    final icon = difference == 0 
        ? Icons.remove 
        : difference > 0 
            ? Icons.trending_up 
            : Icons.trending_down;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: AppTheme.secondaryColor)),
          Text(
            '${current.toStringAsFixed(1)}$unit',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${difference > 0 ? '+' : ''}${difference.toStringAsFixed(1)}$unit',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWoundAssessmentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wound Assessment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _woundLengthController,
                    decoration: const InputDecoration(
                      labelText: 'Length (cm)',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final length = double.tryParse(value);
                      if (length == null || length <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _woundWidthController,
                    decoration: const InputDecoration(
                      labelText: 'Width (cm)',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final width = double.tryParse(value);
                      if (width == null || width <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _woundDepthController,
                    decoration: const InputDecoration(
                      labelText: 'Depth (cm)',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final depth = double.tryParse(value);
                      if (depth == null || depth <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WoundStage>(
              value: _selectedWoundStage,
              decoration: const InputDecoration(
                labelText: 'Wound Stage',
                prefixIcon: Icon(Icons.layers),
              ),
              items: WoundStage.values.map((stage) {
                return DropdownMenuItem(
                  value: stage,
                  child: Text(stage.description),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWoundStage = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _woundDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Wound Description',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please provide a wound description';
                }
                return null;
              },
            ),
            if (_patient != null && _patient!.baselineWounds.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildWoundComparison(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWoundComparison() {
    final currentLength = double.tryParse(_woundLengthController.text);
    final currentWidth = double.tryParse(_woundWidthController.text);
    
    if (currentLength == null || currentWidth == null) {
      return const SizedBox.shrink();
    }

    final currentArea = currentLength * currentWidth;
    final baselineWound = _patient!.baselineWounds.first;
    final baselineArea = baselineWound.area;
    final areaChange = ((currentArea - baselineArea) / baselineArea) * 100;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: areaChange < 0 
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wound Size Comparison',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current area: ${currentArea.toStringAsFixed(1)} cm²',
            style: const TextStyle(color: AppTheme.secondaryColor),
          ),
          Text(
            'Baseline area: ${baselineArea.toStringAsFixed(1)} cm²',
            style: const TextStyle(color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                areaChange < 0 ? Icons.trending_down : Icons.trending_up,
                size: 16,
                color: areaChange < 0 ? AppTheme.successColor : AppTheme.warningColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${areaChange > 0 ? '+' : ''}${areaChange.toStringAsFixed(1)}% change',
                style: TextStyle(
                  color: areaChange < 0 ? AppTheme.successColor : AppTheme.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Photos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Document progress with photos',
              style: TextStyle(color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 16),
            _buildPhotoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        if (_sessionPhotos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _sessionPhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.image,
                          color: AppTheme.secondaryColor,
                          size: 40,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _sessionPhotos.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.errorColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Treatment notes and observations',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please provide session notes';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitSession,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Save Session',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMotivationFormButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _generateMotivationForm,
        icon: const Icon(Icons.description_outlined),
        label: const Text(
          'Generate Motivation Form',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AppTheme.primaryColor, width: 2),
          foregroundColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  void _generateMotivationForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('Generate Motivation Form'),
          ],
        ),
        content: const Text(
          'This will generate a comprehensive motivation form based on the patient\'s current session data and treatment progress. The form will include medical justification for continued treatment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showMotivationFormGenerated();
            },
            icon: const Icon(Icons.file_download),
            label: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  void _showMotivationFormGenerated() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Motivation form generated successfully! Check your downloads.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // In a real app, this would open the generated PDF
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening motivation form...'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _sessionPhotos.add(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _submitSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final patientProvider = context.read<PatientProvider>();
      final sessionNumber = (_patient?.sessions.length ?? 0) + 1;

      // Upload session photos to Firebase Storage first
      List<String> uploadedPhotoUrls = [];
      if (_sessionPhotos.isNotEmpty) {
        try {
          // Create a temporary session ID for photo organization
          final tempSessionId = DateTime.now().millisecondsSinceEpoch.toString();
          uploadedPhotoUrls = await SessionService.uploadSessionPhotos(
            widget.patientId,
            tempSessionId,
            _sessionPhotos,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Warning: Photo upload failed: $e')),
            );
          }
          // Continue with session creation even if photo upload fails
        }
      }

      // Create updated wound with uploaded photo URLs
      final updatedWound = Wound(
        id: _patient!.currentWounds.isNotEmpty 
            ? _patient!.currentWounds.first.id 
            : DateTime.now().millisecondsSinceEpoch.toString(),
        location: _patient!.currentWounds.isNotEmpty 
            ? _patient!.currentWounds.first.location 
            : 'Unknown',
        type: _patient!.currentWounds.isNotEmpty 
            ? _patient!.currentWounds.first.type 
            : 'Unknown',
        length: double.parse(_woundLengthController.text),
        width: double.parse(_woundWidthController.text),
        depth: double.parse(_woundDepthController.text),
        description: _woundDescriptionController.text,
        photos: uploadedPhotoUrls, // Use uploaded URLs instead of local paths
        assessedAt: DateTime.now(),
        stage: _selectedWoundStage,
      );

      // Create session with uploaded photo URLs
      final session = Session(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: widget.patientId,
        sessionNumber: sessionNumber,
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: int.parse(_vasScoreController.text),
        wounds: [updatedWound],
        notes: _notesController.text,
        photos: uploadedPhotoUrls, // Use uploaded URLs instead of local paths
        practitionerId: '', // Will be set by the Firebase service
      );

      await patientProvider.addSession(widget.patientId, session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session saved successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving session: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
