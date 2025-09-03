import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../models/patient.dart';
import '../../models/conversation_data.dart';
import '../../services/ai/openai_service.dart';
import '../../services/ai/icd10_service.dart';
import '../../services/pdf_generation_service.dart';
import '../../services/firebase/practitioner_service.dart';
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
  bool _isEditingReport = false;
  TextEditingController _reportEditController = TextEditingController();
  String? _generatedReport;
  
  // Extracted data for report generation
  String _practitionerName = '';
  String _practitionerPracticeNumber = '';
  String _practitionerContactDetails = '';
  String _woundTypeAndHistory = '';
  String _woundOccurrenceDescription = '';
  List<String> _sessionComorbidities = [];
  String _patientComorbidities = ''; // Auto-populated from patient medical history
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
    _initializeConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _reportEditController.dispose();
    super.dispose();
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
            content: 'Report generated successfully! Here\'s your updated clinical motivation letter:\n\n${_generatedReport!}',
            isBot: true,
            timestamp: _messages[i].timestamp,
          );
          break;
        }
      }
    });
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Report updated successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _cancelEditReport() {
    setState(() {
      _isEditingReport = false;
      _reportEditController.clear();
    });
  }

  void _initializeConversation() async {
    // Pre-populate data from patient and session
    _populateExistingData();
    
    // Start with greeting message that shows what data we already have
    final patientSummary = _buildPatientDataSummary();
    final sessionSummary = _buildSessionDataSummary();
    
    final greetingMessage = AIMessage(
      content: '''Report Generator - ${widget.patient.fullNames} ${widget.patient.surname}

**Available Data:**
$patientSummary

**Session Data:**
$sessionSummary

**Data Collection Required:**
I need to collect additional information to complete the motivation report. Please answer the following questions.''',
      isBot: true,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(greetingMessage);
      _isLoading = true;
    });

    // Try to auto-populate practitioner details
    await _loadPractitionerDetails();

    setState(() {
      _isLoading = false;
    });
    
    // Ask the first question after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _askNextQuestion();
    });
  }

  Future<void> _loadPractitionerDetails() async {
    try {
      final practitionerInfo = await PractitionerService.getPractitionerInfo();
      
      if (practitionerInfo['name'] != null) {
        _practitionerName = practitionerInfo['name']!;
        
        if (practitionerInfo['licenseNumber'] != null) {
          _practitionerPracticeNumber = practitionerInfo['licenseNumber']!;
        }
        
        if (practitionerInfo['contactDetails'] != null) {
          _practitionerContactDetails = practitionerInfo['contactDetails']!;
        }
        
        // Auto-populate patient comorbidities from existing medical history
        _loadPatientComorbidities();
        
        // Auto-populate wound history if available
        _loadPatientWoundHistory();
        
        // Add a message showing auto-populated details
        final autoPopulatedMessage = AIMessage(
          content: 'Perfect! I\'ve loaded your practitioner details and ${widget.patient.fullNames}\'s medical history:\n'
                  '• Practitioner: $_practitionerName\n'
                  '• License: ${_practitionerPracticeNumber.isNotEmpty ? _practitionerPracticeNumber : 'Not found'}\n'
                  '• Patient has existing medical history: ${_patientComorbidities.isNotEmpty ? 'Yes' : 'No'}\n'
                  '• Previous wound history: ${widget.patient.woundHistory?.isNotEmpty == true ? 'Yes' : 'No'}\n\n'
                  'I\'ll focus on this session\'s specific clinical details.',
          isBot: true,
          timestamp: DateTime.now(),
        );
        
        setState(() {
          _messages.add(autoPopulatedMessage);
        });
        
        // Skip practitioner questions and patient demographics
        if (_practitionerName.isNotEmpty) {
          _currentStep = ConversationStep.woundHistoryAndType;
        }
      } else {
        // No practitioner details found, proceed with manual entry
        final noDetailsMessage = AIMessage(
          content: 'I couldn\'t find your practitioner details in the system. I\'ll ask you to provide them manually.',
          isBot: true,
          timestamp: DateTime.now(),
        );
        
        setState(() {
          _messages.add(noDetailsMessage);
          _currentStep = ConversationStep.practitionerName;
        });
      }
    } catch (e) {
      print('Error loading practitioner details: $e');
      // Continue with manual entry if auto-load fails
      final errorMessage = AIMessage(
        content: 'I encountered an issue loading your details, so I\'ll ask you to provide them manually.',
        isBot: true,
        timestamp: DateTime.now(),
      );
      
      setState(() {
        _messages.add(errorMessage);
        _currentStep = ConversationStep.practitionerName;
      });
    }
  }

  void _loadPatientComorbidities() {
    // Extract comorbidities from patient's medical conditions
    final conditions = <String>[];
    
    widget.patient.medicalConditions.forEach((key, value) {
      if (value == true) {
        switch (key) {
          case 'heart':
            conditions.add('Cardiovascular disease');
            break;
          case 'lungs':
            conditions.add('Respiratory conditions');
            break;
          case 'diabetes':
            conditions.add('Diabetes mellitus');
            break;
          case 'hypertension':
            conditions.add('Hypertension');
            break;
          case 'kidney':
            conditions.add('Kidney disease');
            break;
          case 'liver':
            conditions.add('Liver disease');
            break;
          case 'neurological':
            conditions.add('Neurological conditions');
            break;
          case 'autoimmune':
            conditions.add('Autoimmune conditions');
            break;
          case 'cancer':
            conditions.add('Cancer/malignancy');
            break;
          case 'mental_health':
            conditions.add('Mental health conditions');
            break;
          case 'other':
            conditions.add('Other medical conditions');
            break;
        }
      }
    });
    
    _patientComorbidities = conditions.join(', ');
  }

  void _populateExistingData() {
    // Pre-populate patient comorbidities
    _loadPatientComorbidities();
    
    // Debug: Check what wound data we have
    print('🔍 AI DEBUG: Patient wound history: "${widget.patient.woundHistory}"');
    print('🔍 AI DEBUG: Patient wound occurrence: "${widget.patient.woundOccurrence}"');
    print('🔍 AI DEBUG: Patient wound occurrence details: "${widget.patient.woundOccurrenceDetails}"');
    print('🔍 AI DEBUG: Patient baseline wounds count: ${widget.patient.baselineWounds.length}');
    if (widget.patient.baselineWounds.isNotEmpty) {
      final baselineWound = widget.patient.baselineWounds.first;
      print('🔍 AI DEBUG: Baseline wound: ${baselineWound.type} at ${baselineWound.location}');
    }
    print('🔍 AI DEBUG: Session wounds count: ${widget.session.wounds.length}');
    if (widget.session.wounds.isNotEmpty) {
      final sessionWound = widget.session.wounds.first;
      print('🔍 AI DEBUG: Session wound: ${sessionWound.type} at ${sessionWound.location}');
    }
    
    // Pre-populate wound information from patient onboarding
    if (widget.patient.woundHistory != null && widget.patient.woundHistory!.isNotEmpty) {
      _woundTypeAndHistory = widget.patient.woundHistory!;
      print('✅ AI DEBUG: Pre-populated wound history: "$_woundTypeAndHistory"');
    } else {
      // Try to build wound history from baseline wounds
      if (widget.patient.baselineWounds.isNotEmpty) {
        final baselineWound = widget.patient.baselineWounds.first;
        _woundTypeAndHistory = '${baselineWound.type} at ${baselineWound.location}';
        print('✅ AI DEBUG: Built wound history from baseline: "$_woundTypeAndHistory"');
      }
    }
    
    if (widget.patient.woundOccurrence != null && widget.patient.woundOccurrence!.isNotEmpty) {
      _woundOccurrenceDescription = widget.patient.woundOccurrence!;
      print('✅ AI DEBUG: Pre-populated wound occurrence: "$_woundOccurrenceDescription"');
    }
    
    // Pre-populate wound details from current session
    if (widget.session.wounds.isNotEmpty) {
      final wound = widget.session.wounds.first;
      if (_woundDetailsClassification.isEmpty) {
        _woundDetailsClassification = '${wound.type} - ${wound.location} (${wound.length}x${wound.width}x${wound.depth}cm)';
      }
    }
    
    // Pre-populate session notes if available
    if (widget.session.notes.isNotEmpty) {
      _additionalNotes = widget.session.notes;
    }
  }

  String _buildPatientDataSummary() {
    final summary = StringBuffer();
    
    // Basic demographics
    summary.writeln('• Patient: ${widget.patient.fullNames} ${widget.patient.surname}');
    summary.writeln('• Medical Aid: ${widget.patient.medicalAidSchemeName}');
    summary.writeln('• Member Number: ${widget.patient.medicalAidNumber}');
    
    if (widget.patient.referringDoctorName != null) {
      summary.writeln('• Referring Doctor: ${widget.patient.referringDoctorName}');
    }
    
    // Wound history
    if (widget.patient.woundHistory != null && widget.patient.woundHistory!.isNotEmpty) {
      summary.writeln('• Wound History: ${widget.patient.woundHistory}');
    } else if (widget.patient.baselineWounds.isNotEmpty) {
      final wound = widget.patient.baselineWounds.first;
      summary.writeln('• Wound History: ${wound.type} at ${wound.location} (from baseline)');
    }
    
    if (widget.patient.woundOccurrence != null && widget.patient.woundOccurrence!.isNotEmpty) {
      summary.writeln('• How Wound Occurred: ${widget.patient.woundOccurrence}');
    }
    
    if (widget.patient.woundStartDate != null) {
      summary.writeln('• Wound Start Date: ${widget.patient.woundStartDate!.day}/${widget.patient.woundStartDate!.month}/${widget.patient.woundStartDate!.year}');
    }
    
    // Medical conditions
    if (_patientComorbidities.isNotEmpty) {
      summary.writeln('• Medical Conditions: $_patientComorbidities');
    }
    
    return summary.toString();
  }

  String _buildSessionDataSummary() {
    final summary = StringBuffer();
    
    summary.writeln('• Session Date: ${widget.session.date.day}/${widget.session.date.month}/${widget.session.date.year}');
    summary.writeln('• Session Number: ${widget.session.sessionNumber}');
    summary.writeln('• Weight: ${widget.session.weight} kg');
    summary.writeln('• VAS Pain Score: ${widget.session.vasScore}/10');
    
    if (widget.session.wounds.isNotEmpty) {
      final wound = widget.session.wounds.first;
      summary.writeln('• Current Wound: ${wound.type} at ${wound.location}');
      summary.writeln('• Wound Size: ${wound.length} x ${wound.width} x ${wound.depth} cm');
      summary.writeln('• Wound Stage: ${wound.stage}');
    }
    
    if (widget.session.notes.isNotEmpty) {
      summary.writeln('• Session Notes: ${widget.session.notes}');
    }
    
    if (widget.session.photos.isNotEmpty) {
      summary.writeln('• Photos: ${widget.session.photos.length} photos taken');
    }
    
    return summary.toString();
  }



  void _loadPatientWoundHistory() {
    // Use existing wound history if available
    if (widget.patient.woundHistory?.isNotEmpty == true) {
      _woundTypeAndHistory = widget.patient.woundHistory!;
    }
    
    // Use wound occurrence details if available
    if (widget.patient.woundOccurrenceDetails?.isNotEmpty == true) {
      _woundOccurrenceDescription = widget.patient.woundOccurrenceDetails!;
    }
  }

  void _askNextQuestion() {
    String question;
    
    switch (_currentStep) {
      case ConversationStep.practitionerName:
        question = 'What is your name for the report? (e.g., Sr. Sarah Smith)';
        break;
      case ConversationStep.practitionerDetails:
        question = 'Please provide your practice number and contact details for the report. For example: "Practice Number: 0168238, Tel: 082 828 2476, Email: wounds@hauteCare.co.za"';
        break;
      case ConversationStep.woundHistoryAndType:
        print('🔍 AI DEBUG: Checking wound history step. _woundTypeAndHistory: "$_woundTypeAndHistory"');
        if (_woundTypeAndHistory.isNotEmpty) {
          print('✅ AI DEBUG: Skipping wound history step - already have data');
          // Skip this step since we have the data
          _advanceToNextStep();
          _askNextQuestion();
          return;
        } else {
          print('❌ AI DEBUG: No wound history found, asking question');
          question = 'Please describe the wound history and type. For example: "Type 1 diabetic patient with a pressure injury stage 2 on her left heel after a left hip replacement." This helps determine the primary ICD-10 code.';
        }
        break;
      case ConversationStep.woundOccurrence:
        if (_woundOccurrenceDescription.isNotEmpty) {
          // Skip this step since we have the data
          _advanceToNextStep();
          _askNextQuestion();
          return;
        } else {
          question = 'How did the patient get this wound? For example, did they fall down stairs, off a bike, or is it due to a chronic condition like diabetes? This helps determine external cause codes.';
        }
        break;
      case ConversationStep.comorbidities:
        // Check if we have complete medical conditions from patient registration
        final hasExistingConditions = widget.patient.medicalConditions.values.any((hasCondition) => hasCondition);
        
        if (hasExistingConditions && _patientComorbidities.isNotEmpty) {
          // We have complete medical history from registration - skip this step
          print('🏥 AI DEBUG: Skipping comorbidities step - data from registration: $_patientComorbidities');
          _sessionComorbidities = [_patientComorbidities];
          _advanceToNextStep();
          _askNextQuestion();
          return;
        } else {
          question = 'What comorbidities does the patient have, such as diabetes, hypertension, or vascular disease? Please list any relevant medical conditions.';
        }
        break;
      case ConversationStep.currentInfection:
        question = 'Does the patient have any signs of infection today? If yes, please describe the symptoms and any test results.';
        break;
      case ConversationStep.testsPerformed:
        question = 'What tests were performed during this session? (e.g., HbA1c, CRP, ESR, wound swabs, ABPI, SWMT, etc.) Please provide results if available.';
        break;
      case ConversationStep.woundDetailsClassification:
        // Check if we have complete wound data from session
        if (widget.session.wounds.isNotEmpty) {
          final wound = widget.session.wounds.first;
          if (wound.length > 0 && wound.width > 0 && wound.depth >= 0) {
            // We have complete measurements, skip this step
            print('✅ AI DEBUG: Skipping wound details step - complete measurements available');
            _advanceToNextStep();
            _askNextQuestion();
            return;
          }
        }
        
        if (_woundDetailsClassification.isNotEmpty) {
          question = 'From the session data, I have these wound details: ${_woundDetailsClassification}. Is this accurate, or would you like to add any additional classification information?';
        } else {
          question = 'Please provide specific wound details: wound type/classification (e.g., NPUAP for pressure injuries, CEAP for leg ulcers), size measurements, and exact location on the body.';
        }
        break;
      case ConversationStep.timesAssessment:
        question = 'Please provide the current TIMES assessment:\n• Tissue type (red/yellow/black/mixed)\n• Inflammation/Infection signs\n• Moisture level (low/moderate/high) and exudate type\n• Edge condition (advancing/non-advancing)\n• Surrounding skin status';
        break;
      case ConversationStep.currentTreatment:
        question = 'What treatments are being applied in this session? Include cleansing methods (e.g., HOCL), dressings, medications, and any planned treatments or products.';
        break;
      case ConversationStep.treatmentDates:
        question = 'When are the treatment sessions scheduled? Please provide dates for this month and planned future sessions.';
        break;
      case ConversationStep.additionalNotes:
        question = 'Any additional notes? Is this treatment in lieu of hospitalization? Any other relevant clinical information? (Optional - or say "none" to proceed to report generation)';
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
      case ConversationStep.practitionerDetails:
        // Parse practice number and contact details from the response
        _practitionerContactDetails = answer;
        // Try to extract practice number if provided in a structured way
        final practiceNumberMatch = RegExp(r'[Pp]ractice\s*[Nn]umber:?\s*([^\s,]+)').firstMatch(answer);
        if (practiceNumberMatch != null) {
          _practitionerPracticeNumber = practiceNumberMatch.group(1) ?? '';
        }
        break;
      case ConversationStep.woundHistoryAndType:
        // If we had existing data and user confirms it, keep existing data
        if (_woundTypeAndHistory.isNotEmpty && 
            (answer.toLowerCase().contains('yes') || answer.toLowerCase().contains('accurate') || answer.toLowerCase().contains('correct'))) {
          // Keep existing wound history
        } else {
          // Update with new information
          _woundTypeAndHistory = answer;
        }
        break;
      case ConversationStep.woundOccurrence:
        // If we had existing data and user confirms it, keep existing data
        if (_woundOccurrenceDescription.isNotEmpty && 
            (answer.toLowerCase().contains('yes') || answer.toLowerCase().contains('relevant') || answer.toLowerCase().contains('correct'))) {
          // Keep existing occurrence description
        } else {
          // Update with new information
          _woundOccurrenceDescription = answer;
        }
        break;
      case ConversationStep.comorbidities:
        // If we had existing comorbidities, combine with new information
        if (_patientComorbidities.isNotEmpty) {
          if (answer.toLowerCase().contains('no') || answer.toLowerCase().contains('none')) {
            _sessionComorbidities = [_patientComorbidities]; // Use only existing
          } else {
            _sessionComorbidities = [_patientComorbidities, answer]; // Combine both
          }
        } else {
          _sessionComorbidities = answer.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        break;
      case ConversationStep.currentInfection:
        _infectionStatus = answer;
        break;
      case ConversationStep.testsPerformed:
        _testsPerformed = answer.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        break;
      case ConversationStep.woundDetailsClassification:
        _woundDetailsClassification = answer;
        break;
      case ConversationStep.timesAssessment:
        _timesAssessment = answer;
        break;
      case ConversationStep.currentTreatment:
        _currentTreatment = answer;
        break;
      case ConversationStep.treatmentDates:
        _treatmentDates = answer.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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
      
      // Ask AI to analyze the user's response (silent mode - only for corrections)
      final analysisResult = await _openAIService.analyzeUserResponseWithValidation(
        userResponse: lastUserMessage,
        conversationContext: context,
        currentQuestion: currentQuestion,
        stepType: _currentStep.toString(),
      );
      
      // Only add AI message if there's a correction needed (message is not empty)
      final aiMessage = analysisResult['message'] as String;
      if (aiMessage.isNotEmpty) {
        final botMessage = AIMessage(
          content: aiMessage,
          isBot: true,
          timestamp: DateTime.now(),
        );
        
        setState(() {
          _messages.add(botMessage);
        });
        
        _scrollToBottom();
      }
      
      setState(() {
        _isLoading = false;
      });
      
      // Return whether we should proceed to next step
      return analysisResult['proceed'] as bool;
      
    } catch (e) {
      // Fallback: proceed silently if AI analysis fails
      setState(() {
        _isLoading = false;
      });
      
      // Default to proceeding if AI analysis fails (silent mode)
      return true;
    }
  }

  String _buildConversationContext() {
    // Build detailed wound information from session data
    String woundMeasurements = 'No wound measurements available';
    if (widget.session.wounds.isNotEmpty) {
      final wound = widget.session.wounds.first;
      woundMeasurements = 'Length: ${wound.length}cm, Width: ${wound.width}cm, Depth: ${wound.depth}cm, Stage: ${wound.stage}, Location: ${wound.location}';
    }
    
    return '''
Patient: ${widget.patient.fullNames} ${widget.patient.surname}
Session Date: ${widget.session.date.toString().split(' ')[0]}
Session Number: ${widget.session.sessionNumber}
Patient Weight: ${widget.session.weight}kg
VAS Pain Score: ${widget.session.vasScore}/10

WOUND MEASUREMENTS (Already Captured - DO NOT ASK AGAIN):
$woundMeasurements

PATIENT HISTORY (Already Available - DO NOT ASK AGAIN):
- Medical Aid: ${widget.patient.medicalAidSchemeName} (${widget.patient.medicalAidNumber})
- Wound History: ${widget.patient.woundHistory ?? 'Not specified'}
- How Wound Occurred: ${widget.patient.woundOccurrence ?? 'Not specified'}
- Wound Start Date: ${widget.patient.woundStartDate?.toString().split(' ')[0] ?? 'Not specified'}
- Medical Conditions: ${widget.patient.medicalConditions.entries.where((e) => e.value).map((e) => e.key).join(', ')}

Collected Information:
- Practitioner: $_practitionerName
- Practice Number: $_practitionerPracticeNumber
- Contact Details: $_practitionerContactDetails
- Wound History & Type: $_woundTypeAndHistory
- Wound Occurrence: $_woundOccurrenceDescription
- Session Comorbidities: ${_sessionComorbidities.join(', ')}
- Infection Status: $_infectionStatus
- Tests: ${_testsPerformed.join(', ')}
- Wound Details: $_woundDetailsClassification
- TIMES Assessment: $_timesAssessment
- Treatment: $_currentTreatment
- Treatment Dates: ${_treatmentDates.join(', ')}
- Notes: $_additionalNotes
''';
  }
  
  String _getCurrentQuestionContext() {
    switch (_currentStep) {
      case ConversationStep.practitionerName:
        return 'Asking for practitioner name for report authorization';
      case ConversationStep.practitionerDetails:
        return 'Collecting practitioner practice number and contact details for report';
      case ConversationStep.woundHistoryAndType:
        return 'Collecting wound history and type for primary ICD-10 code determination';
      case ConversationStep.woundOccurrence:
        return 'Determining how wound occurred for external cause codes (V01-Y98)';
      case ConversationStep.comorbidities:
        return 'Identifying comorbidities for secondary codes and PMB eligibility';
      case ConversationStep.currentInfection:
        return 'Assessing current infection status and symptoms';
      case ConversationStep.testsPerformed:
        return 'Collecting objective test data and results';
      case ConversationStep.woundDetailsClassification:
        return 'Gathering specific wound classification and measurement details';
      case ConversationStep.timesAssessment:
        return 'Gathering structured TIMES wound assessment';
      case ConversationStep.currentTreatment:
        return 'Documenting current treatment protocols and interventions';
      case ConversationStep.treatmentDates:
        return 'Collecting treatment scheduling information';
      case ConversationStep.additionalNotes:
        return 'Collecting any additional clinical observations';
      default:
        return 'General clinical conversation';
    }
  }

  void _advanceToNextStep() {
    switch (_currentStep) {
      case ConversationStep.practitionerName:
        _currentStep = ConversationStep.practitionerDetails;
        break;
      case ConversationStep.practitionerDetails:
        _currentStep = ConversationStep.woundHistoryAndType;
        break;
      case ConversationStep.woundHistoryAndType:
        _currentStep = ConversationStep.woundOccurrence;
        break;
      case ConversationStep.woundOccurrence:
        _currentStep = ConversationStep.comorbidities;
        break;
      case ConversationStep.comorbidities:
        _currentStep = ConversationStep.currentInfection;
        break;
      case ConversationStep.currentInfection:
        _currentStep = ConversationStep.testsPerformed;
        break;
      case ConversationStep.testsPerformed:
        _currentStep = ConversationStep.woundDetailsClassification;
        break;
      case ConversationStep.woundDetailsClassification:
        _currentStep = ConversationStep.timesAssessment;
        break;
      case ConversationStep.timesAssessment:
        _currentStep = ConversationStep.currentTreatment;
        break;
      case ConversationStep.currentTreatment:
        _currentStep = ConversationStep.treatmentDates;
        break;
      case ConversationStep.treatmentDates:
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
        patientName: '${widget.patient.fullNames} ${widget.patient.surname}',
        medicalAid: widget.patient.medicalAidSchemeName.isEmpty ? 'Not specified' : widget.patient.medicalAidSchemeName,
        membershipNumber: widget.patient.medicalAidNumber.isEmpty ? 'Not specified' : widget.patient.medicalAidNumber,
        referringDoctor: widget.patient.referringDoctorName ?? 'Not specified',
        woundHistory: widget.patient.woundHistory,
        woundOccurrence: widget.patient.woundOccurrence,
        patientComorbidities: _extractComorbidities(),
        
        // From session conversation
        practitionerName: _practitionerName,
        practitionerPracticeNumber: _practitionerPracticeNumber.isEmpty ? null : _practitionerPracticeNumber,
        practitionerContactDetails: _practitionerContactDetails.isEmpty ? null : _practitionerContactDetails,
        woundTypeAndHistory: _woundTypeAndHistory.isEmpty ? null : _woundTypeAndHistory,
        woundOccurrenceDescription: _woundOccurrenceDescription.isEmpty ? null : _woundOccurrenceDescription,
        sessionComorbidities: _sessionComorbidities,
        infectionStatus: _infectionStatus.isEmpty ? null : _infectionStatus,
        testsPerformed: _testsPerformed,
        treatmentDates: _treatmentDates,
        additionalNotes: _additionalNotes.isEmpty ? null : _additionalNotes,
        
        // Wound details from session
        woundDetails: WoundDetails(
          type: _woundDetailsClassification.isNotEmpty ? _woundDetailsClassification : 
                (widget.session.wounds.isNotEmpty ? widget.session.wounds.first.type : 'Not specified'),
          size: widget.session.wounds.isNotEmpty ? '${widget.session.wounds.first.length} x ${widget.session.wounds.first.width} x ${widget.session.wounds.first.depth} cm' : 'Not specified',
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

      // Analyze conversation and generate ICD-10 code suggestions
      final conversationText = _messages
          .where((m) => !m.isBot)
          .map((m) => m.content)
          .join(' ');
      
      final allClinicalText = [
        conversationText,
        clinicalData.woundHistory,
        clinicalData.woundOccurrence,
        clinicalData.infectionStatus ?? '',
        clinicalData.woundTypeAndHistory ?? '',
        clinicalData.woundOccurrenceDescription ?? '',
        ...clinicalData.patientComorbidities,
        ...clinicalData.sessionComorbidities,
      ].join(' ');
      
      final suggestedCodes = ICD10Service.autoSuggestFromConversation(allClinicalText);

      // Generate the report using OpenAI with ICD-10 codes
      final report = await _openAIService.generateMotivationReport(
        clinicalData: clinicalData,
        selectedCodes: suggestedCodes,
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

  String _cleanReportContent(String content) {
    // Remove ** formatting from AI generated reports
    String cleaned = content.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
    
    // Remove tick boxes and checkbox patterns
    cleaned = cleaned.replaceAll(RegExp(r'\[\s*[x✓]\s*\]'), '•'); // Replace checked boxes with bullet points
    cleaned = cleaned.replaceAll(RegExp(r'\[\s*\]'), '•'); // Replace empty boxes with bullet points
    cleaned = cleaned.replaceAll(RegExp(r'☐|☑|✓|✗|□|■'), '•'); // Replace various checkbox symbols with bullets
    
    return cleaned;
  }

  Widget _buildPDFExportButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 10,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enhanced PDF export button with consolidated functionality
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _exportEnhancedReport,
              icon: const Icon(Icons.picture_as_pdf, size: 24),
              label: const Text(
                'Export Enhanced PDF Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clinical Data Collection'),
            Text(
              'Answer questions to generate report',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Add silent mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.volume_off,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Silent Mode',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
          
          // PDF Export button (when report is completed)
          if (_currentStep == ConversationStep.completed && _generatedReport != null)
            _buildPDFExportButton(),
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
    // Check if this is the final generated report
    bool isFinalReport = message.isBot && 
                        _currentStep == ConversationStep.completed && 
                        message.content.contains(_generatedReport ?? '');
    
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
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFinalReport && _isEditingReport)
              // Editable text field for the report
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Report:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reportEditController,
                    maxLines: null,
                    minLines: 10,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Edit your report here...',
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveEditedReport,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _cancelEditReport,
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              // Regular text display
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cleanReportContent(message.content),
                    style: TextStyle(
                      color: message.isBot ? AppTheme.textColor : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  if (isFinalReport && !_isEditingReport)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        onPressed: _startEditReport,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Report'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        ),
                      ),
                    ),
                ],
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

  void _exportEnhancedReport() async {
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
              Text('Generating Enhanced PDF report with photos and analytics...'),
            ],
          ),
          duration: Duration(seconds: 5),
        ),
      );

      // Generate enhanced PDF with photos and analytics
      final practitionerInfo = _practitionerName.isNotEmpty 
        ? '$_practitionerName${_practitionerPracticeNumber.isNotEmpty ? ' ($_practitionerPracticeNumber)' : ''}'
        : 'MedWave Practitioner';
      
      // Get ICD10 codes for PDF
      final conversationText = _messages
          .where((m) => !m.isBot)
          .map((m) => m.content)
          .join(' ');
      
      final allClinicalText = [
        conversationText,
        widget.patient.woundHistory,
        widget.patient.woundOccurrence,
        _infectionStatus,
        _woundTypeAndHistory,
        _woundOccurrenceDescription,
        ...widget.patient.medicalConditions.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key),
        ..._sessionComorbidities,
      ].join(' ');
      
      final suggestedCodes = ICD10Service.autoSuggestFromConversation(allClinicalText);

      final File pdfFile = await PDFGenerationService.generateEnhancedChatReportPDF(
        reportContent: _cleanReportContent(_generatedReport!),
        patient: widget.patient,
        session: widget.session,
        practitionerName: practitionerInfo,
        selectedCodes: suggestedCodes,
      );

      // Automatically open the PDF for viewing
      final opened = await PDFGenerationService.openPDF(pdfFile);
      
      // Show success message with action buttons
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✅ Enhanced PDF generated successfully!'),
              const SizedBox(height: 4),
              Text(
                'Includes: AI Report + Photos + Analytics',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              if (opened)
                Text(
                  'PDF opened for viewing',
                  style: TextStyle(fontSize: 11, color: Colors.green[200]),
                )
              else
                Text(
                  'Saved to: ${pdfFile.path.split('/').last}',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
            ],
          ),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: opened ? 'Share' : 'View',
            onPressed: () => opened 
              ? _sharePDFFile(pdfFile)
              : _showPDFActions(pdfFile),
          ),
        ),
      );

    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to generate enhanced PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
      final practitionerInfo = _practitionerName.isNotEmpty 
        ? '$_practitionerName${_practitionerPracticeNumber.isNotEmpty ? ' (${ _practitionerPracticeNumber})' : ''}'
        : 'MedWave Practitioner';
      
      final File pdfFile = await PDFGenerationService.generateChatReportPDF(
        reportContent: _generatedReport!,
        patient: widget.patient,
        session: widget.session,
        practitionerName: practitionerInfo,
      );

      // Automatically open the PDF for viewing
      final opened = await PDFGenerationService.openPDF(pdfFile);
      
      // Show success message with action buttons
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✅ PDF generated successfully!'),
              const SizedBox(height: 4),
              if (opened)
                Text(
                  'PDF opened for viewing',
                  style: TextStyle(fontSize: 11, color: Colors.green[200]),
                )
              else
                Text(
                  'Saved to: ${pdfFile.path.split('/').last}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: opened ? 'Share' : 'View',
            onPressed: () => opened 
              ? _sharePDFFile(pdfFile)
              : _showPDFActions(pdfFile),
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



  /// Share PDF file using system share sheet
  void _sharePDFFile(File pdfFile) async {
    try {
      final shared = await PDFGenerationService.sharePDF(
        pdfFile,
        subject: 'MedWave Clinical Report - ${widget.patient.fullNames} ${widget.patient.surname}',
      );
      
      if (shared) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF shared successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share PDF. File saved to: ${pdfFile.path.split('/').last}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Show PDF action dialog with view and share options
  void _showPDFActions(File pdfFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your clinical report has been saved successfully.'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final opened = await PDFGenerationService.openPDF(pdfFile);
                      if (!opened) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open PDF. File saved to Downloads folder.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _sharePDFFile(pdfFile);
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'File: ${pdfFile.path.split('/').last}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
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
