import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../models/patient.dart';
import '../../models/conversation_data.dart';
import '../../services/ai/openai_service.dart';
import '../../services/pdf_generation_service.dart';
import '../../theme/app_theme.dart';

class AIReportChatScreen extends StatefulWidget {
  final String patientId;
  final String sessionId;
  final Patient patient;
  final Session session;

  const AIReportChatScreen({
    super.key,
    required this.patientId,
    required this.sessionId,
    required this.patient,
    required this.session,
  });

  @override
  State<AIReportChatScreen> createState() => _AIReportChatScreenState();
}

class _AIReportChatScreenState extends State<AIReportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenAIService _openAIService = OpenAIService();
  
  List<AIMessage> _messages = [];
  ConversationStep _currentStep = ConversationStep.greeting;
  bool _isLoading = false;
  bool _isGeneratingReport = false;
  String? _generatedReport;
  
  // Extracted data for report generation
  String _practitionerName = '';
  String _infectionStatus = '';
  List<String> _testsPerformed = [];
  String _timesAssessment = '';
  String _currentTreatment = '';
  String _additionalNotes = '';

  @override
  void initState() {
    super.initState();
    _initializeConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeConversation() {
    // Start with greeting message that acknowledges existing patient data
    final greetingMessage = AIMessage(
      content: 'Hello! I have ${widget.patient.name}\'s information from their file. I\'ll ask 3-5 questions about this specific session to generate the motivation report. Let\'s begin!',
      isBot: true,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(greetingMessage);
      _currentStep = ConversationStep.practitionerName;
    });
    
    // Ask the first question after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _askNextQuestion();
    });
  }

  void _askNextQuestion() {
    String question;
    
    switch (_currentStep) {
      case ConversationStep.practitionerName:
        question = 'What is your name for the report? (e.g., Sr. Sarah Smith)';
        break;
      case ConversationStep.currentInfection:
        question = 'Does the patient have any signs of infection today? If yes, please describe the symptoms and any test results.';
        break;
      case ConversationStep.testsPerformed:
        question = 'What tests were performed during this session? (e.g., HbA1c, CRP, ESR, wound swabs, ABPI, etc.) Please provide results if available.';
        break;
      case ConversationStep.timesAssessment:
        question = 'Please provide the current TIMES assessment:\n• Tissue type (red/yellow/black)\n• Inflammation/Infection signs\n• Moisture level (low/moderate/high)\n• Edge condition (advancing/non-advancing)\n• Surrounding skin status';
        break;
      case ConversationStep.currentTreatment:
        question = 'What treatments are being applied in this session? Include cleansing methods, dressings, medications, and any planned treatments.';
        break;
      case ConversationStep.additionalNotes:
        question = 'Any additional notes for this session? (Optional - or say "none" to proceed to report generation)';
        break;
      default:
        return;
    }
    
    final botMessage = AIMessage(
      content: question,
      isBot: true,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(botMessage);
    });
    
    _scrollToBottom();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message
    final userMessage = AIMessage(
      content: message.trim(),
      isBot: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Store the answer based on current step
    _storeAnswer(message.trim());

    // Add acknowledgment and determine if we can proceed
    final shouldProceed = await _addAcknowledgmentAndValidate();

    if (shouldProceed) {
      // Move to next step or generate report
      if (_currentStep == ConversationStep.additionalNotes) {
        await _generateReport();
      } else {
        _advanceToNextStep();
        _askNextQuestion();
      }
    }
    // If shouldProceed is false, we stay on the same step and wait for a better response

    setState(() {
      _isLoading = false;
    });
  }

  void _storeAnswer(String answer) {
    switch (_currentStep) {
      case ConversationStep.practitionerName:
        _practitionerName = answer;
        break;
      case ConversationStep.currentInfection:
        _infectionStatus = answer;
        break;
      case ConversationStep.testsPerformed:
        _testsPerformed = answer.split(',').map((e) => e.trim()).toList();
        break;
      case ConversationStep.timesAssessment:
        _timesAssessment = answer;
        break;
      case ConversationStep.currentTreatment:
        _currentTreatment = answer;
        break;
      case ConversationStep.additionalNotes:
        _additionalNotes = answer;
        break;
      default:
        break;
    }
  }

  Future<bool> _addAcknowledgmentAndValidate() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get the last user message
      final lastUserMessage = _messages.where((m) => !m.isBot).last.content;
      
      // Create context for AI to analyze the response
      String context = _buildConversationContext();
      String currentQuestion = _getCurrentQuestionContext();
      
      // Ask AI to analyze the user's response and provide acknowledgment
      final analysisResult = await _openAIService.analyzeUserResponseWithValidation(
        userResponse: lastUserMessage,
        conversationContext: context,
        currentQuestion: currentQuestion,
        stepType: _currentStep.toString(),
      );
      
      final botMessage = AIMessage(
        content: analysisResult['message'] as String,
        isBot: true,
        timestamp: DateTime.now(),
      );
      
      setState(() {
        _messages.add(botMessage);
        _isLoading = false;
      });
      
      _scrollToBottom();
      
      // Return whether we should proceed to next step
      return analysisResult['proceed'] as bool;
      
    } catch (e) {
      // Fallback to simple acknowledgment and proceed if AI fails
      final fallbackMessage = AIMessage(
        content: 'Thank you for your response. Let me continue with the next question.',
        isBot: true,
        timestamp: DateTime.now(),
      );
      
      setState(() {
        _messages.add(fallbackMessage);
        _isLoading = false;
      });
      
      _scrollToBottom();
      
      // Default to proceeding if AI analysis fails
      return true;
    }
  }

  String _buildConversationContext() {
    return '''
Patient: ${widget.patient.fullNames} ${widget.patient.surname}
Session Date: ${widget.session.date.toString().split(' ')[0]}
Session Number: ${widget.session.sessionNumber}
Current Wounds: ${widget.session.wounds.map((w) => '${w.location} (${w.type})').join(', ')}
VAS Score: ${widget.session.vasScore}
Collected Information:
- Practitioner: $_practitionerName
- Infection Status: $_infectionStatus
- Tests: ${_testsPerformed.join(', ')}
- TIMES Assessment: $_timesAssessment
- Treatment: $_currentTreatment
- Notes: $_additionalNotes
''';
  }
  
  String _getCurrentQuestionContext() {
    switch (_currentStep) {
      case ConversationStep.practitionerName:
        return 'Asking for practitioner name for report authorization';
      case ConversationStep.currentInfection:
        return 'Assessing current infection status and symptoms';
      case ConversationStep.testsPerformed:
        return 'Collecting objective test data and results';
      case ConversationStep.timesAssessment:
        return 'Gathering structured TIMES wound assessment';
      case ConversationStep.currentTreatment:
        return 'Documenting current treatment protocols and interventions';
      case ConversationStep.additionalNotes:
        return 'Collecting any additional clinical observations';
      default:
        return 'General clinical conversation';
    }
  }

  void _advanceToNextStep() {
    switch (_currentStep) {
      case ConversationStep.practitionerName:
        _currentStep = ConversationStep.currentInfection;
        break;
      case ConversationStep.currentInfection:
        _currentStep = ConversationStep.testsPerformed;
        break;
      case ConversationStep.testsPerformed:
        _currentStep = ConversationStep.timesAssessment;
        break;
      case ConversationStep.timesAssessment:
        _currentStep = ConversationStep.currentTreatment;
        break;
      case ConversationStep.currentTreatment:
        _currentStep = ConversationStep.additionalNotes;
        break;
      default:
        _currentStep = ConversationStep.completed;
        break;
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGeneratingReport = true;
    });

    try {
      // Create ExtractedClinicalData with patient data + session data
      final clinicalData = ExtractedClinicalData(
        // From patient file
        patientName: widget.patient.name,
        medicalAid: widget.patient.medicalAid,
        membershipNumber: widget.patient.medicalAidNumber,
        referringDoctor: widget.patient.referringDoctorName ?? 'Not specified',
        woundHistory: widget.patient.woundHistory,
        woundOccurrence: widget.patient.woundOccurrence,
        comorbidities: _extractComorbidities(),
        
        // From session conversation
        practitionerName: _practitionerName,
        infectionStatus: _infectionStatus.isEmpty ? null : _infectionStatus,
        testsPerformed: _testsPerformed,
        additionalNotes: _additionalNotes.isEmpty ? null : _additionalNotes,
        
        // Wound details from session
        woundDetails: WoundDetails(
          type: widget.session.wounds.isNotEmpty ? widget.session.wounds.first.type : 'Not specified',
          size: widget.session.wounds.isNotEmpty ? '${widget.session.wounds.first.length} x ${widget.session.wounds.first.width} cm' : 'Not specified',
          location: widget.session.wounds.isNotEmpty ? widget.session.wounds.first.location : 'Not specified',
          timesAssessment: _parseTimesAssessment(),
        ),
        
        // Treatment details
        treatmentDetails: TreatmentDetails(
          cleansing: _extractCleansingFromTreatment(),
          skinProtectant: _extractSkinProtectantFromTreatment(),
          plannedTreatments: _extractPlannedTreatments(),
        ),
      );

      // Generate the report using OpenAI
      final report = await _openAIService.generateMotivationReport(
        clinicalData: clinicalData,
        selectedCodes: [], // Would be populated with ICD-10 codes
        treatmentCodes: ['88002', '88031', '88045'], // Standard codes
      );

      final reportMessage = AIMessage(
        content: 'Report generated successfully! Here\'s your clinical motivation letter:\n\n$report',
        isBot: true,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(reportMessage);
        _generatedReport = report;
        _currentStep = ConversationStep.completed;
      });

      _scrollToBottom();

    } catch (e) {
      final errorMessage = AIMessage(
        content: 'Sorry, there was an error generating the report: $e\n\nPlease try again or contact support.',
        isBot: true,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(errorMessage);
      });
    } finally {
      setState(() {
        _isGeneratingReport = false;
      });
    }
  }

  List<String> _extractComorbidities() {
    final comorbidities = <String>[];
    widget.patient.medicalConditions.forEach((condition, hasCondition) {
      if (hasCondition) {
        final details = widget.patient.medicalConditionDetails[condition];
        if (details != null && details.isNotEmpty) {
          comorbidities.add('$condition: $details');
        } else {
          comorbidities.add(condition);
        }
      }
    });
    return comorbidities;
  }

  TimesAssessment? _parseTimesAssessment() {
    if (_timesAssessment.isEmpty) return null;
    
    // Simple parsing - in a real app, this would be more sophisticated
    return TimesAssessment(
      tissue: _timesAssessment.contains('red') ? 'Red' : 
              _timesAssessment.contains('yellow') ? 'Yellow' : 'Not specified',
      inflammation: _timesAssessment.toLowerCase().contains('inflam') ? 'Present' : 'None',
      moisture: _timesAssessment.toLowerCase().contains('high') ? 'High' :
                _timesAssessment.toLowerCase().contains('low') ? 'Low' : 'Moderate',
      edges: _timesAssessment.toLowerCase().contains('advancing') ? 'Advancing' : 'Non-advancing',
      surrounding: _timesAssessment.toLowerCase().contains('normal') ? 'Normal' : 'Inflamed',
    );
  }

  String _extractCleansingFromTreatment() {
    return _currentTreatment.toLowerCase().contains('hocl') ? 'HOCL' : 
           _currentTreatment.toLowerCase().contains('saline') ? 'Normal Saline' : 'Standard cleansing';
  }

  String _extractSkinProtectantFromTreatment() {
    return _currentTreatment.toLowerCase().contains('cavilon') ? 'Cavilon spray' : 
           'Standard skin protectant';
  }

  List<String> _extractPlannedTreatments() {
    return _currentTreatment.split(',').map((e) => e.trim()).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('AI Report Generator'),
// subtitle: Text('${widget.patient.name} - Session ${widget.session.sessionNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_generatedReport != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportReport,
              tooltip: 'Export Report',
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          
          // Input field
          if (_currentStep != ConversationStep.completed && !_isGeneratingReport)
            _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final totalSteps = ConversationStep.values.length - 2; // Excluding greeting and completed
    final currentStepIndex = _currentStep.index - 1; // Adjust for greeting
    final progress = currentStepIndex / totalSteps;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            _currentStep == ConversationStep.completed 
                ? 'Report Generation Complete'
                : 'Step ${currentStepIndex.clamp(0, totalSteps)} of $totalSteps - ${_currentStep.displayName}',
            style: const TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AIMessage message) {
    return Align(
      alignment: message.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: message.isBot ? Colors.grey[100] : AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: message.isBot ? AppTheme.textColor : Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: message.isBot 
                    ? AppTheme.secondaryColor 
                    : Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('AI is typing...'),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your response...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _sendMessage(_messageController.text),
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _exportReport() {
    if (_generatedReport == null) return;
    
    // Show export options
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Export PDF'),
              onTap: () {
                Navigator.pop(context);
                _shareReport();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportAsPDF() {
    // TODO: Implement PDF export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF export feature coming soon!'),
      ),
    );
  }

  void _shareReport() async {
    if (_generatedReport == null) return;
    
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Generating PDF report...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // Generate PDF
      final File pdfFile = await PDFGenerationService.generateChatReportPDF(
        reportContent: _generatedReport!,
        patient: widget.patient,
        session: widget.session,
        practitionerName: _practitionerName.isNotEmpty ? _practitionerName : 'MedWave Practitioner',
      );

      // Show success message with file path
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✅ PDF generated successfully!'),
              const SizedBox(height: 4),
              Text(
                'Saved to: ${pdfFile.path}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View Info',
            onPressed: () => _showPDFInfo(pdfFile),
          ),
        ),
      );

    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showPDFInfo(File pdfFile) {
    // Show dialog with PDF file information
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your clinical report has been saved as a PDF.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'File Location:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pdfFile.path,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'File Size: ${(pdfFile.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: You can find this file in your device\'s Documents folder and share it via email or other apps.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
