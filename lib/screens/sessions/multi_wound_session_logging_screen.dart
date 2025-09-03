import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/patient_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../services/firebase/session_service.dart';
import '../../services/firebase/patient_service.dart';
import '../../widgets/wound_assessment_widget.dart';


class MultiWoundSessionLoggingScreen extends StatefulWidget {
  final String patientId;

  const MultiWoundSessionLoggingScreen({super.key, required this.patientId});

  @override
  State<MultiWoundSessionLoggingScreen> createState() => _MultiWoundSessionLoggingScreenState();
}

class _MultiWoundSessionLoggingScreenState extends State<MultiWoundSessionLoggingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _vasScoreController = TextEditingController();
  final _notesController = TextEditingController();

  Patient? _patient;
  List<Session> _previousSessions = [];
  List<WoundAssessmentData> _currentWoundsData = [];
  int _expandedWoundIndex = 0;
  List<String> _sessionPhotos = [];
  bool _isLoading = false;
  
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() => _isLoading = true);
    
    try {
      final patientProvider = context.read<PatientProvider>();
      _patient = patientProvider.patients.firstWhere(
        (p) => p.id == widget.patientId,
        orElse: () => throw Exception('Patient not found'),
      );

      // Load previous sessions
      _previousSessions = await PatientService.getPatientSessions(widget.patientId);
      
      // Initialize wound data from patient's current wounds
      if (_patient!.currentWounds.isNotEmpty) {
        _initializeWoundsFromPatient();
      } else {
        // Fallback: initialize from baseline wounds
        _initializeWoundsFromBaseline();
      }
      
    } catch (e) {
      print('Error loading patient data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading patient data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeWoundsFromPatient() {
    _currentWoundsData = _patient!.currentWounds.map((wound) {
      return WoundAssessmentData(
        id: wound.id,
        location: wound.location,
        type: wound.type,
        length: wound.length,
        width: wound.width,
        depth: wound.depth,
        description: wound.description,
        stage: wound.stage,
        photos: [], // Start with empty photos for new session
      );
    }).toList();
  }

  void _initializeWoundsFromBaseline() {
    _currentWoundsData = _patient!.baselineWounds.map((wound) {
      return WoundAssessmentData(
        id: wound.id,
        location: wound.location,
        type: wound.type,
        length: wound.length,
        width: wound.width,
        depth: wound.depth,
        description: wound.description,
        stage: wound.stage,
        photos: [], // Start with empty photos for new session
      );
    }).toList();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _vasScoreController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _patient == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
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
                    _buildMultiWoundAssessmentCard(),
                    const SizedBox(height: 16),
                    _buildSessionPhotosCard(),
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
    final sessionNumber = _previousSessions.length + 1;
    
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
                    child: Text(
                      'Session #$sessionNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Multi-Wound Session',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_patient!.fullNames} ${_patient!.surname}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentWoundsData.length} wounds to assess',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.medical_information,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_currentWoundsData.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Wounds',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: AppTheme.infoColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    Text(
                      'Update measurements and assess each wound',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Previous session info
          if (_previousSessions.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Previous Session',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPreviousDataItem(
                          'Weight',
                          '${_previousSessions.last.weight.toStringAsFixed(1)} kg',
                          Icons.monitor_weight,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPreviousDataItem(
                          'VAS Score',
                          '${_previousSessions.last.vasScore}/10',
                          Icons.healing,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviousDataItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.secondaryColor),
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
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMeasurementsCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monitor_weight,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Measurements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    Text(
                      'Record today\'s measurements',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg) *',
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
                    labelText: 'VAS Score *',
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
                      return 'Score 0-10';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiWoundAssessmentCard() {
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
                      'Wound Assessments (${_currentWoundsData.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const Text(
                      'Update each wound\'s current status',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Wound assessment widgets
          ...List.generate(_currentWoundsData.length, (index) {
            return WoundAssessmentWidget(
              key: ValueKey(_currentWoundsData[index].id),
              woundIndex: index,
              woundId: _currentWoundsData[index].id,
              initialData: _currentWoundsData[index],
              isExpanded: _expandedWoundIndex == index,
              onToggleExpanded: () {
                setState(() {
                  _expandedWoundIndex = _expandedWoundIndex == index ? -1 : index;
                });
              },
              onWoundDataChanged: (data) {
                setState(() {
                  _currentWoundsData[index] = data;
                });
              },
            );
          }),
          
          const SizedBox(height: 16),
          _buildWoundProgressSummary(),
        ],
      ),
    );
  }

  Widget _buildWoundProgressSummary() {
    final completedWounds = _currentWoundsData.where((w) => w.isValid).length;
    final totalWounds = _currentWoundsData.length;
    final allComplete = completedWounds == totalWounds;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allComplete 
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allComplete 
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.warningColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            allComplete ? Icons.check_circle : Icons.info_outline,
            color: allComplete ? AppTheme.successColor : AppTheme.warningColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              allComplete
                  ? 'All $totalWounds wounds assessed and ready for session'
                  : 'Progress: $completedWounds of $totalWounds wounds completed',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: allComplete ? AppTheme.successColor : AppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPhotosCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_camera,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Photos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    Text(
                      'General photos for this session (wound-specific photos go in each wound assessment)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPhotoSection(),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notes,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    Text(
                      'General observations and treatment notes',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Session Notes',
              hintText: 'Record any observations, treatments, or changes...',
              alignLabelWithHint: true,
            ),
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        if (_sessionPhotos.isNotEmpty)
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _sessionPhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_sessionPhotos[index]),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _sessionPhotos.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final allWoundsComplete = _currentWoundsData.every((w) => w.isValid);
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: allWoundsComplete ? _submitSession : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save),
            const SizedBox(width: 8),
            Text(
              allWoundsComplete 
                  ? 'Complete Session'
                  : 'Complete all wound assessments to continue',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationFormButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          // First save the session, then navigate to AI chat
          if (_patient == null) return;
          
          try {
            // Create session object
            final session = Session(
              id: '', // Will be set by Firestore
              patientId: widget.patientId,
              sessionNumber: _previousSessions.length + 1,
              date: DateTime.now(),
              weight: double.tryParse(_weightController.text) ?? _patient!.baselineWeight,
              vasScore: int.tryParse(_vasScoreController.text) ?? 0,
              notes: _notesController.text,
              wounds: _currentWoundsData.map((data) => Wound(
                id: data.id,
                location: data.location,
                type: data.type,
                stage: data.stage,
                length: data.length,
                width: data.width,
                depth: data.depth,
                photos: data.photos,
                description: data.description,
                assessedAt: DateTime.now(),
              )).toList(),
              photos: _sessionPhotos,
              practitionerId: context.read<AuthProvider>().user?.uid ?? '',
            );
            
            // Save session to get ID
            final savedSessionId = await SessionService.createSession(widget.patientId, session);
            
            // Create session object with the returned ID for navigation
            final savedSession = session.copyWith(id: savedSessionId);
            
            // Navigate to Enhanced AI Report Chat
            if (mounted) {
              context.push(
                '/patients/${widget.patientId}/sessions/$savedSessionId/enhanced-ai-chat',
                extra: {
                  'patient': _patient,
                  'session': savedSession,
                },
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error creating session: $e'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.psychology),
        label: const Text('Generate AI Report'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

    setState(() => _isLoading = true);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Saving multi-wound session...'),
            ],
          ),
        ),
      );

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final sessionNumber = _previousSessions.length + 1;
      
      // Upload session photos
      List<String> uploadedSessionPhotos = [];
      if (_sessionPhotos.isNotEmpty) {
        uploadedSessionPhotos = await SessionService.uploadSessionPhotos(
          widget.patientId, 
          sessionId, 
          _sessionPhotos,
        );
      }
      
      // Create wound objects with uploaded photos
      List<Wound> sessionWounds = [];
      List<String> allWoundPhotos = [];
      
      for (int i = 0; i < _currentWoundsData.length; i++) {
        final woundData = _currentWoundsData[i];
        
        // Upload wound-specific photos
        List<String> uploadedWoundPhotos = [];
        if (woundData.photos.isNotEmpty) {
          uploadedWoundPhotos = await SessionService.uploadSessionPhotos(
            widget.patientId, 
            sessionId, 
            woundData.photos,
          );
        }
        
        final wound = woundData.toWound().copyWith(
          photos: uploadedWoundPhotos,
          assessedAt: DateTime.now(),
        );
        
        sessionWounds.add(wound);
        allWoundPhotos.addAll(uploadedWoundPhotos);
      }

      // Create session
      final session = Session(
        id: sessionId,
        patientId: widget.patientId,
        sessionNumber: sessionNumber,
        date: DateTime.now(),
        weight: double.parse(_weightController.text),
        vasScore: int.parse(_vasScoreController.text),
        wounds: sessionWounds,
        notes: _notesController.text.isEmpty 
            ? 'Multi-wound session #$sessionNumber - ${sessionWounds.length} wounds assessed'
            : _notesController.text,
        photos: [...uploadedSessionPhotos, ...allWoundPhotos],
        practitionerId: '', // Will be set by Firebase service
      );

      // Save session
      await SessionService.createSession(widget.patientId, session);
      
      // Update patient current data
      final updatedPatient = _patient!.copyWith(
        currentWeight: double.parse(_weightController.text),
        currentVasScore: int.parse(_vasScoreController.text),
        currentWounds: sessionWounds,
        lastUpdated: DateTime.now(),
      );
      
      final patientProvider = context.read<PatientProvider>();
      await patientProvider.updatePatient(widget.patientId, updatedPatient);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Multi-wound session #$sessionNumber completed successfully! ${sessionWounds.length} wounds assessed.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        context.pop(); // Return to patient profile
      }
    } catch (e) {
      print('Error submitting multi-wound session: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
