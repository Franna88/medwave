import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../services/firebase/session_service.dart';
import '../../services/firebase/patient_service.dart';
import '../../utils/validation_utils.dart';

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
  
  // Focus nodes for better keyboard management
  final _weightFocusNode = FocusNode();
  final _vasScoreFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  final _woundLengthFocusNode = FocusNode();
  final _woundWidthFocusNode = FocusNode();
  final _woundDepthFocusNode = FocusNode();
  final _woundDescriptionFocusNode = FocusNode();
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

  // Simplified keyboard dismissal - single clean method
  void _dismissKeyboard() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }

  void _loadPatientData() {
    final patientProvider = context.read<PatientProvider>();
    _patient = patientProvider.patients.firstWhere(
      (p) => p.id == widget.patientId,
      orElse: () => throw Exception('Patient not found'),
    );

    // Leave all form fields empty for fresh data entry
    // Practitioners should enter current measurements for each session
    _weightController.clear();
    _vasScoreController.clear();
    _notesController.clear();
    _woundLengthController.clear();
    _woundWidthController.clear();
    _woundDepthController.clear();
    _woundDescriptionController.clear();
    
    // Reset wound stage to default
    _selectedWoundStage = WoundStage.stage1;
    
    // Clear any existing photos
    _sessionPhotos.clear();
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
    
    // Dispose focus nodes
    _weightFocusNode.dispose();
    _vasScoreFocusNode.dispose();
    _notesFocusNode.dispose();
    _woundLengthFocusNode.dispose();
    _woundWidthFocusNode.dispose();
    _woundDepthFocusNode.dispose();
    _woundDescriptionFocusNode.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: _dismissKeyboard,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  _buildModernHeader(),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // Only dismiss keyboard on user-initiated scroll with actual movement
                        // UserScrollNotification fires when user touches and drags, not on programmatic scroll
                        if (notification is UserScrollNotification) {
                          _dismissKeyboard();
                        }
                        return false;
                      },
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildModernHeader() {
    return FutureBuilder<List<Session>>(
      future: PatientService.getPatientSessions(widget.patientId),
      builder: (context, snapshot) {
        final sessionNumber = (snapshot.hasData ? snapshot.data!.length : 0) + 1;
        return _buildHeaderContent(sessionNumber);
      },
    );
  }
  
  Widget _buildHeaderContent(int sessionNumber) {
    
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
    return FutureBuilder<List<Session>>(
      future: PatientService.getPatientSessions(widget.patientId),
      builder: (context, snapshot) {
        final sessionNumber = (snapshot.hasData ? snapshot.data!.length : 0) + 1;
        return _buildSessionInfoContent(sessionNumber);
      },
    );
  }
  
  Widget _buildSessionInfoContent(int sessionNumber) {
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
      height: 100, // Fixed height to ensure consistency
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
                    focusNode: _weightFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: Icon(Icons.monitor_weight),
                      suffixText: 'kg',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_vasScoreFocusNode);
                    },
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
                    focusNode: _vasScoreFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'VAS Pain Score',
                      prefixIcon: Icon(Icons.healing),
                      suffixText: '/10',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_woundLengthFocusNode);
                    },
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
                    focusNode: _woundLengthFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Length (cm)',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_woundWidthFocusNode);
                    },
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
                    focusNode: _woundWidthFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Width (cm)',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_woundDepthFocusNode);
                    },
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
                    focusNode: _woundDepthFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Depth (cm)',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_woundDescriptionFocusNode);
                    },
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
              isExpanded: true,
              items: WoundStage.values.map((stage) {
                return DropdownMenuItem(
                  value: stage,
                  child: Text(
                    stage.description,
                    overflow: TextOverflow.ellipsis,
                  ),
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
              focusNode: _woundDescriptionFocusNode,
              decoration: const InputDecoration(
                labelText: 'Wound Description',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                FocusScope.of(context).requestFocus(_notesFocusNode);
              },
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_sessionPhotos[index]),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: AppTheme.errorColor,
                                size: 40,
                              ),
                            );
                          },
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
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text(
                  'Camera',
                  style: TextStyle(fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, size: 20),
                label: const Text(
                  'Gallery',
                  style: TextStyle(fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
              focusNode: _notesFocusNode,
              decoration: const InputDecoration(
                labelText: 'Treatment notes and observations',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                FocusScope.of(context).unfocus();
              },
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
    print('🔥 SESSION CREATION DEBUG: Starting _submitSession()');
    
    // Dismiss keyboard when submitting
    FocusScope.of(context).unfocus();
    
    // Validate required fields with popup
    List<String> missingFields = [];
    
    if (_weightController.text.trim().isEmpty) {
      missingFields.add('Patient Weight');
    }
    if (_vasScoreController.text.trim().isEmpty) {
      missingFields.add('VAS Pain Score');
    }
    if (_notesController.text.trim().isEmpty) {
      missingFields.add('Session Notes');
    }
    
    if (missingFields.isNotEmpty) {
      await ValidationUtils.showValidationDialog(
        context,
        title: 'Session Incomplete',
        missingFields: missingFields,
        additionalMessage: 'All session information is required for proper patient care documentation.',
      );
      return;
    }
    
    if (!_formKey.currentState!.validate()) {
      print('❌ SESSION CREATION DEBUG: Form validation failed');
      return;
    }

    print('✅ SESSION CREATION DEBUG: Form validation passed');
    setState(() {
      _isLoading = true;
    });

    try {
      print('📊 SESSION CREATION DEBUG: Patient ID: ${widget.patientId}');
      print('📊 SESSION CREATION DEBUG: Current patient sessions count: ${_patient?.sessions.length ?? 0}');
      print('📊 SESSION CREATION DEBUG: Session number will be auto-generated by SessionService');

      // Create session ID first so photo paths are consistent
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      print('🆔 SESSION CREATION DEBUG: Generated session ID: $sessionId');

      // Upload session photos to Firebase Storage with the correct session ID
      List<String> uploadedPhotoUrls = [];
      print('📷 SESSION CREATION DEBUG: Number of photos to upload: ${_sessionPhotos.length}');
      
      if (_sessionPhotos.isNotEmpty) {
        try {
          print('📤 SESSION CREATION DEBUG: Starting photo upload...');
          print('📤 SESSION CREATION DEBUG: Photo paths: $_sessionPhotos');
          
          uploadedPhotoUrls = await SessionService.uploadSessionPhotos(
            widget.patientId,
            sessionId, // Use the actual session ID, not a temporary one
            _sessionPhotos,
          );
          
          print('✅ SESSION CREATION DEBUG: Photo upload successful!');
          print('📤 SESSION CREATION DEBUG: Uploaded photo URLs: $uploadedPhotoUrls');
        } catch (e) {
          print('❌ SESSION CREATION DEBUG: Photo upload failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Warning: Photo upload failed: $e')),
            );
          }
          // Continue with session creation even if photo upload fails
        }
      } else {
        print('📷 SESSION CREATION DEBUG: No photos to upload');
      }

      // Create updated wound with uploaded photo URLs
      print('🩹 SESSION CREATION DEBUG: Creating wound object...');
      print('🩹 SESSION CREATION DEBUG: Current wounds count: ${_patient!.currentWounds.length}');
      print('🩹 SESSION CREATION DEBUG: Wound measurements - L:${_woundLengthController.text}, W:${_woundWidthController.text}, D:${_woundDepthController.text}');
      print('🩹 SESSION CREATION DEBUG: Wound stage: $_selectedWoundStage');
      
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
      print('✅ SESSION CREATION DEBUG: Wound object created with ID: ${updatedWound.id}');

      // Create session with the same ID used for photo uploads
      print('📋 SESSION CREATION DEBUG: Creating session object...');
      print('📋 SESSION CREATION DEBUG: Session data - Weight:${_weightController.text}, VAS:${_vasScoreController.text}');
      print('📋 SESSION CREATION DEBUG: Session notes: ${_notesController.text}');
      
      final session = Session(
        id: sessionId, // Use the same ID that was used for photo uploads
        patientId: widget.patientId,
        sessionNumber: 0, // Will be auto-generated by SessionService
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: int.parse(_vasScoreController.text),
        wounds: [updatedWound],
        notes: _notesController.text,
        photos: uploadedPhotoUrls, // Use uploaded URLs instead of local paths
        practitionerId: '', // Will be set by the Firebase service
      );
      print('✅ SESSION CREATION DEBUG: Session object created with ID: ${session.id}');
      print('📋 SESSION CREATION DEBUG: Session object: ${session.toString()}');

      print('🚀 SESSION CREATION DEBUG: Calling SessionService.createSession directly...');
      final createdSessionId = await SessionService.createSession(widget.patientId, session);
      print('✅ SESSION CREATION DEBUG: SessionService.createSession completed successfully with ID: $createdSessionId');

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
