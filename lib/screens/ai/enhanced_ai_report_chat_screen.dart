import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../models/conversation_data.dart';
import '../../services/ai/openai_service.dart';
import '../../services/ai/multi_wound_ai_service.dart';
import '../../services/pdf_generation_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/wound_management_service.dart';
import '../../theme/app_theme.dart';

class EnhancedAIReportChatScreen extends StatefulWidget {
  final String patientId;
  final String sessionId;
  final Patient patient;
  final Session session;

  const EnhancedAIReportChatScreen({
    super.key,
    required this.patientId,
    required this.sessionId,
    required this.patient,
    required this.session,
  });

  @override
  State<EnhancedAIReportChatScreen> createState() => _EnhancedAIReportChatScreenState();
}

class _EnhancedAIReportChatScreenState extends State<EnhancedAIReportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenAIService _openAIService = OpenAIService();
  final MultiWoundAIService _multiWoundAIService = MultiWoundAIService();
  
  List<AIMessage> _messages = [];
  ConversationStep _currentStep = ConversationStep.greeting;
  bool _isLoading = false;
  bool _isGeneratingReport = false;
  bool _isEditingReport = false;
  TextEditingController _reportEditController = TextEditingController();
  String? _generatedReport;
  bool _isMultiWound = false;
  
  // Extracted data for report generation
  String _practitionerName = '';
  String _practitionerPracticeNumber = '';
  String _practitionerContactDetails = '';
  String _woundTypeAndHistory = '';
  String _woundOccurrenceDescription = '';
  List<String> _sessionComorbidities = [];
  String _patientComorbidities = '';
  String _infectionStatus = '';
  List<String> _testsPerformed = [];
  String _woundDetailsClassification = '';
  String _timesAssessment = '';
  String _currentTreatment = '';
  List<String> _treatmentDates = [];
  String _additionalNotes = '';

  @override
  void initState() {
    super.initState();
    _isMultiWound = WoundManagementService.hasMultipleWounds(widget.patient);
    _initializeConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _reportEditController.dispose();
    super.dispose();
  }

  void _initializeConversation() {
    final woundCount = widget.session.wounds.length;
    final welcomeMessage = _isMultiWound
        ? 'Hello! I can see this patient has $woundCount wounds requiring comprehensive assessment. I have their basic information from their file and will ask 4-6 questions about this session to generate a detailed multi-wound motivation report.'
        : 'Hello! I have the patient\'s basic information from their file. I\'ll ask 3-5 questions about this specific session to generate the motivation report.';

    setState(() {
      _messages = [
        AIMessage(
          content: welcomeMessage,
          isBot: true,
          timestamp: DateTime.now(),
        ),
      ];
      _currentStep = ConversationStep.greeting;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildPatientInfoHeader(),
          if (_isMultiWound) _buildMultiWoundSummary(),
          Expanded(child: _buildMessagesList()),
          if (_isEditingReport) _buildReportEditor(),
          if (!_isEditingReport) _buildMessageInput(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isMultiWound ? 'Multi-Wound AI Assistant' : 'AI Report Assistant',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Session #${widget.session.sessionNumber}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        if (_generatedReport != null)
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePDF,
            tooltip: 'Generate PDF',
          ),
      ],
    );
  }

  Widget _buildPatientInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isMultiWound ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.infoColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: _isMultiWound ? AppTheme.primaryColor.withOpacity(0.3) : AppTheme.infoColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isMultiWound ? AppTheme.primaryColor : AppTheme.infoColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              _isMultiWound ? Icons.medical_information : Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.patient.fullNames} ${widget.patient.surname}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                Text(
                  '${widget.patient.medicalAidSchemeName} • ${widget.patient.medicalAidNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiWoundSummary() {
    final woundCount = widget.session.wounds.length;
    final totalArea = widget.session.wounds.fold<double>(0, (sum, w) => sum + w.area);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_information, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Multi-Wound Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric('Total Wounds', '$woundCount'),
              ),
              Expanded(
                child: _buildSummaryMetric('Combined Area', '${totalArea.toStringAsFixed(1)} cm²'),
              ),
              Expanded(
                child: _buildSummaryMetric('Session Weight', '${widget.session.weight} kg'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'AI will provide comprehensive analysis for coordinated multi-wound care',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(AIMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isBot) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isMultiWound ? AppTheme.primaryColor : AppTheme.infoColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isMultiWound ? Icons.medical_information : Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.isBot ? Colors.white : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: message.isBot ? AppTheme.textColor : Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (message.isBot && _generatedReport != null && message.content.contains('Report generated successfully')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _startEditReport,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _generatePDF,
                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text('Generate PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!message.isBot) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Edit Report',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditingReport = false;
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveEditedReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 300,
            child: TextField(
              controller: _reportEditController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Edit your report here...',
              ),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _isMultiWound 
                    ? 'Describe the current status of all wounds...'
                    : 'Type your response...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isLoading,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _isLoading ? AppTheme.borderColor : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(AIMessage(
        content: userMessage,
        isBot: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      OpenAIResponse response;
      
      if (_isMultiWound) {
        response = await _multiWoundAIService.generateMultiWoundResponse(
          patient: widget.patient,
          session: widget.session,
          conversationHistory: _messages.where((m) => m != _messages.last).toList(),
          userMessage: userMessage,
          currentStep: _currentStep,
        );
      } else {
        response = await _openAIService.generateResponse(
          conversationHistory: _messages.where((m) => m != _messages.last).toList(),
          userMessage: userMessage,
          currentStep: _currentStep,
        );
      }

      setState(() {
        _messages.add(AIMessage(
          content: response.content,
          isBot: true,
          timestamp: DateTime.now(),
        ));
        _currentStep = response.nextStep ?? ConversationStep.completed;
        _isLoading = false;
      });

      // Check if conversation is ready for report generation
      if (_currentStep == ConversationStep.completed || 
          response.content.toLowerCase().contains('generate') ||
          response.content.toLowerCase().contains('report')) {
        _showReportGenerationOption();
      }

    } catch (e) {
      setState(() {
        _messages.add(AIMessage(
          content: 'I apologize, but I encountered an error. Please try again.',
          isBot: true,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _showReportGenerationOption() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isMultiWound ? 'Generate Multi-Wound Report?' : 'Generate Report?'),
        content: Text(
          _isMultiWound 
              ? 'I have enough information to generate a comprehensive multi-wound clinical motivation report. Would you like me to create it now?'
              : 'I have enough information to generate the clinical motivation report. Would you like me to create it now?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Chat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateReport();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate Report'),
          ),
        ],
      ),
    );
  }

  void _generateReport() async {
    setState(() {
      _isGeneratingReport = true;
      // Add loading message immediately
      _messages.add(AIMessage(
        content: 'Report is being generated... Please wait while I create your ${_isMultiWound ? 'comprehensive multi-wound' : ''} clinical motivation letter.',
        isBot: true,
        timestamp: DateTime.now(),
      ));
    });

    _scrollToBottom();

    try {
      // Extract clinical data from conversation
      final clinicalData = _extractClinicalDataFromConversation();
      
      String report;
      if (_isMultiWound) {
        report = await _multiWoundAIService.generateMultiWoundMotivationReport(
          patient: widget.patient,
          session: widget.session,
          clinicalData: clinicalData,
          selectedCodes: [], // Would be populated from conversation
          treatmentCodes: [], // Would be populated from conversation
        );
      } else {
        report = await _openAIService.generateMotivationReport(
          clinicalData: clinicalData,
          selectedCodes: [],
          treatmentCodes: [],
        );
      }

      setState(() {
        _generatedReport = report;
        _messages.add(AIMessage(
          content: 'Report generated successfully! Here\'s your ${_isMultiWound ? 'comprehensive multi-wound' : ''} clinical motivation letter:\n\n$report',
          isBot: true,
          timestamp: DateTime.now(),
        ));
        _isGeneratingReport = false;
      });

    } catch (e) {
      setState(() {
        _messages.add(AIMessage(
          content: 'I encountered an error while generating the report. Please try again.',
          isBot: true,
          timestamp: DateTime.now(),
        ));
        _isGeneratingReport = false;
      });
    }

    _scrollToBottom();
  }

  ExtractedClinicalData _extractClinicalDataFromConversation() {
    // Extract data from conversation messages
    // This is a simplified version - in practice would use AI to extract structured data
    return ExtractedClinicalData(
      patientName: '${widget.patient.fullNames} ${widget.patient.surname}',
      medicalAid: widget.patient.medicalAidSchemeName,
      membershipNumber: widget.patient.medicalAidNumber,
      referringDoctor: widget.patient.referringDoctorName ?? 'Not specified',
      practitionerName: _practitionerName.isNotEmpty ? _practitionerName : 'Wound Care Specialist',
      practitionerPracticeNumber: _practitionerPracticeNumber,
      practitionerContactDetails: _practitionerContactDetails,
      patientComorbidities: _getPatientComorbidities(),
      sessionComorbidities: _sessionComorbidities,
      woundHistory: widget.patient.woundHistory,
      woundOccurrence: widget.patient.woundOccurrence,
      // woundOccurrenceDetails: widget.patient.woundOccurrenceDetails,
      infectionStatus: _infectionStatus,
      testsPerformed: _testsPerformed,
      treatmentDates: _treatmentDates,
      additionalNotes: _additionalNotes,
      woundDetails: _buildWoundDetails(),
      treatmentDetails: _buildTreatmentDetails(),
    );
  }

  List<String> _getPatientComorbidities() {
    return widget.patient.medicalConditions.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  WoundDetails? _buildWoundDetails() {
    if (widget.session.wounds.isEmpty) return null;
    
    final primaryWound = widget.session.wounds.first;
    return WoundDetails(
      type: primaryWound.type,
      location: primaryWound.location,
      size: '${primaryWound.length} × ${primaryWound.width} × ${primaryWound.depth} cm',
      timesAssessment: TimesAssessment(
        tissue: 'Assessment from session',
        inflammation: 'Assessment from session',
        moisture: 'Assessment from session',
        edges: 'Assessment from session',
        surrounding: 'Assessment from session',
      ),
    );
  }

  TreatmentDetails? _buildTreatmentDetails() {
    return TreatmentDetails(
      plannedTreatments: [_currentTreatment.isNotEmpty ? _currentTreatment : 'Specialized wound care'],
      cleansing: 'Standard wound cleansing protocol',
      skinProtectant: 'As clinically indicated',
    );
  }

  void _startEditReport() {
    setState(() {
      _isEditingReport = true;
      _reportEditController.text = _generatedReport ?? '';
    });
  }

  void _saveEditedReport() {
    setState(() {
      _generatedReport = _reportEditController.text;
      _isEditingReport = false;
      
      // Update the message in the list
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].isBot && _messages[i].content.contains('Report generated successfully')) {
          _messages[i] = AIMessage(
            content: 'Report generated successfully! Here\'s your updated ${_isMultiWound ? 'multi-wound' : ''} clinical motivation letter:\n\n${_generatedReport!}',
            isBot: true,
            timestamp: _messages[i].timestamp,
          );
          break;
        }
      }
    });
  }

  void _generatePDF() async {
    if (_generatedReport == null) return;

    // Check if running on web and show helpful message
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PDF Generation Not Available on Web',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Please use the mobile app to generate and download PDF reports. This feature requires native file system access.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: AppTheme.infoColor,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Got it',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
      return;
    }

    try {
      const practitionerName = 'Wound Care Specialist'; // Placeholder - would be from user session
      
      if (_isMultiWound) {
        await PDFGenerationService.generateEnhancedClinicalMotivationPDF(
          reportContent: _generatedReport!,
          patient: widget.patient,
          session: widget.session,
          practitionerName: practitionerName,
          selectedCodes: [],
          treatmentCodes: [],
          additionalNotes: 'Generated via Enhanced AI Multi-Wound Assistant',
        );
      } else {
        await PDFGenerationService.generateClinicalMotivationPDF(
          reportContent: _generatedReport!,
          patient: widget.patient,
          session: widget.session,
          practitionerName: practitionerName,
          selectedCodes: [],
          treatmentCodes: [],
          additionalNotes: 'Generated via AI Assistant',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_isMultiWound ? 'Multi-wound' : ''} PDF report generated successfully!'),
          backgroundColor: AppTheme.successColor,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () {
              // Open PDF file
            },
          ),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
