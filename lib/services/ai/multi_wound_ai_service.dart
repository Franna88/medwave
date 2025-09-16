import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/conversation_data.dart';
import '../../models/icd10_code.dart';
import '../../models/patient.dart';
import '../../config/api_keys.dart';
import '../wound_management_service.dart';
import 'icd10_service.dart';
import 'openai_service.dart';

class MultiWoundAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _apiKey = ApiKeys.openaiApiKey;
  
  /// Enhanced system prompt for multi-wound scenarios
  static String _buildMultiWoundSystemPrompt(Patient patient, Session session) {
    final woundCount = session.wounds.length;
    final isMultiWound = woundCount > 1;
    
    if (!isMultiWound) {
      // Return original single-wound prompt
      return _getSingleWoundPrompt();
    }
    
    return '''
You are an AI chatbot designed to assist wound care practitioners in South Africa with generating comprehensive clinical motivation reports for complex multi-wound patients. This patient has $woundCount wounds requiring individual assessment and coordinated treatment planning.

MULTI-WOUND CONTEXT:
Patient has $woundCount distinct wounds:
${_buildWoundSummaryContext(session.wounds)}

Your goal is to gather SESSION-SPECIFIC information through a conversational interview of 4-6 targeted questions, then generate a comprehensive multi-wound clinical motivation report.

IMPORTANT: The following information is already available from patient data:
- Patient demographics and medical aid information
- Individual wound histories, locations, and measurements
- Comorbidities and medical conditions from registration
- Baseline wound classifications and staging
- Previous treatment history

MULTI-WOUND SPECIFIC GUIDELINES:

Start by greeting: "Hello! I can see this patient has $woundCount wounds requiring assessment. I have their basic information and will ask 4-6 questions about this session to generate a comprehensive multi-wound motivation report."

Ask questions sequentially, focusing on session-specific data:

1. Practitioner identification ("What is your name and practice number for the report?")
2. Overall patient status ("How is the patient's overall condition today? Any systemic concerns or changes since last visit?")
3. Individual wound status ("For each wound, please describe the current status - which wounds show improvement, stability, or concern?")
4. Infection assessment ("Are there any signs of infection in any of the wounds? Please specify which wounds and symptoms.")
5. Tests and assessments ("What tests were performed today (HbA1c, CRP, wound swabs, etc.)? Any TIMES assessments for specific wounds?")
6. Treatment coordination ("What is the coordinated treatment plan for all wounds? Any wound-specific treatments or priorities?")

MULTI-WOUND ANALYSIS APPROACH:
- Assess each wound individually while considering systemic factors
- Identify wound healing priorities and treatment sequencing
- Consider wound interactions and overall patient burden
- Evaluate coordinated care requirements and resource allocation
- Determine if wounds require different ICD-10 codes or can be grouped

CODE EXTRACTION FOR MULTIPLE WOUNDS:
- Generate primary ICD-10 code for the most significant wound
- Add secondary codes for additional wounds if clinically distinct
- Consider systemic complications affecting multiple wounds
- Evaluate PMB eligibility for complex multi-wound cases
- Include treatment codes for coordinated wound care (88002, 88031, 88045, etc.)

REPORT STRUCTURE:
Generate a comprehensive report covering:
1. Patient identification and multi-wound overview
2. Individual wound assessments with current status
3. Coordinated treatment rationale and priorities
4. Systemic considerations affecting all wounds
5. Comprehensive ICD-10 coding for insurance coverage
6. Treatment authorization request for continued multi-wound care

Keep responses professional, empathetic, and focused on the complexity of managing multiple wounds simultaneously.
''';
  }

  /// Generate enhanced multi-wound context
  static String _buildWoundSummaryContext(List<Wound> wounds) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < wounds.length; i++) {
      final wound = wounds[i];
      buffer.writeln('Wound ${i + 1}: ${wound.location} (${wound.type}, ${_getStageDescription(wound.stage)}, ${wound.area.toStringAsFixed(1)} cm²)');
    }
    
    return buffer.toString();
  }

  /// Generate AI response with multi-wound intelligence
  Future<OpenAIResponse> generateMultiWoundResponse({
    required Patient patient,
    required Session session,
    required List<AIMessage> conversationHistory,
    required String userMessage,
    required ConversationStep currentStep,
    Session? previousSession,
  }) async {
    try {
      final systemPrompt = _buildMultiWoundSystemPrompt(patient, session);
      final patientContext = _buildEnhancedPatientContext(patient, session, previousSession);
      
      // Build conversation history for OpenAI
      final messages = [
        {
          'role': 'system',
          'content': '$systemPrompt\n\nPATIENT CONTEXT:\n$patientContext',
        },
        // Add conversation history
        ...conversationHistory.map((msg) => {
              'role': msg.isBot ? 'assistant' : 'user',
              'content': msg.content,
            }),
        // Add current user message
        {
          'role': 'user',
          'content': userMessage,
        }
      ];

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
          'max_tokens': 1500, // Increased for multi-wound complexity
          'temperature': 0.7,
          'presence_penalty': 0.1,
          'frequency_penalty': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        return OpenAIResponse(
          content: content,
          isSuccess: true,
          nextStep: _determineNextStep(currentStep, content),
          suggestedCodes: _extractMultiWoundICD10Codes(content, session.wounds),
          usage: OpenAIUsage.fromMap(data['usage']),
        );
      } else {
        final errorData = jsonDecode(response.body);
        return OpenAIResponse(
          content: 'Error: ${errorData['error']['message']}',
          isSuccess: false,
          errorMessage: errorData['error']['message'],
        );
      }
    } catch (e) {
      return OpenAIResponse(
        content: 'Network error occurred. Please try again.',
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Build enhanced patient context for multi-wound scenarios
  String _buildEnhancedPatientContext(Patient patient, Session session, Session? previousSession) {
    final buffer = StringBuffer();
    
    // Patient identification
    buffer.writeln('PATIENT: ${patient.fullNames} ${patient.surname}');
    buffer.writeln('MEDICAL AID: ${patient.medicalAidSchemeName} (${patient.medicalAidNumber})');
    buffer.writeln('REFERRING DOCTOR: ${patient.referringDoctorName ?? 'Not specified'}');
    buffer.writeln('SESSION: #${session.sessionNumber} on ${_formatDate(session.date)}');
    buffer.writeln();
    
    // Multi-wound overview
    buffer.writeln('MULTI-WOUND OVERVIEW:');
    buffer.writeln('Total wounds: ${session.wounds.length}');
    final totalArea = session.wounds.fold<double>(0, (sum, w) => sum + w.area);
    buffer.writeln('Combined wound area: ${totalArea.toStringAsFixed(1)} cm²');
    
    if (previousSession != null && previousSession.wounds.isNotEmpty) {
      final previousArea = previousSession.wounds.fold<double>(0, (sum, w) => sum + w.area);
      final change = ((previousArea - totalArea) / previousArea * 100);
      buffer.writeln('Overall progress: ${change.toStringAsFixed(1)}% ${change > 0 ? 'improvement' : 'increase'} in total area');
    }
    buffer.writeln();
    
    // Individual wound details
    buffer.writeln('INDIVIDUAL WOUND ASSESSMENTS:');
    for (int i = 0; i < session.wounds.length; i++) {
      final wound = session.wounds[i];
      final previousWound = previousSession?.wounds.where((w) => w.id == wound.id).firstOrNull;
      
      buffer.writeln('Wound ${i + 1}: ${wound.location}');
      buffer.writeln('  Type: ${wound.type}');
      buffer.writeln('  Stage: ${_getStageDescription(wound.stage)}');
      buffer.writeln('  Measurements: ${wound.length} × ${wound.width} × ${wound.depth} cm');
      buffer.writeln('  Area: ${wound.area.toStringAsFixed(1)} cm², Volume: ${wound.volume.toStringAsFixed(1)} cm³');
      
      if (previousWound != null) {
        final areaChange = ((previousWound.area - wound.area) / previousWound.area * 100);
        buffer.writeln('  Progress: ${areaChange.toStringAsFixed(1)}% ${areaChange > 0 ? 'improvement' : 'increase'} in area');
      }
      
      if (wound.description.isNotEmpty) {
        buffer.writeln('  Assessment: ${wound.description}');
      }
      buffer.writeln();
    }
    
    // Patient medical history
    buffer.writeln('MEDICAL HISTORY:');
    final conditions = patient.medicalConditions.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
    
    if (conditions.isNotEmpty) {
      buffer.writeln('Comorbidities: ${conditions.join(', ')}');
    }
    
    if (patient.currentMedications?.isNotEmpty == true) {
      buffer.writeln('Current medications: ${patient.currentMedications}');
    }
    
    if (patient.allergies?.isNotEmpty == true) {
      buffer.writeln('Allergies: ${patient.allergies}');
    }
    buffer.writeln();
    
    // Current session data
    buffer.writeln('CURRENT SESSION DATA:');
    buffer.writeln('Weight: ${session.weight} kg');
    buffer.writeln('VAS Pain Score: ${session.vasScore}/10');
    
    if (session.notes.isNotEmpty) {
      buffer.writeln('Session notes: ${session.notes}');
    }
    
    return buffer.toString();
  }

  /// Generate comprehensive multi-wound motivation report
  Future<String> generateMultiWoundMotivationReport({
    required Patient patient,
    required Session session,
    required ExtractedClinicalData clinicalData,
    required List<SelectedICD10Code> selectedCodes,
    required List<String> treatmentCodes,
    Session? previousSession,
  }) async {
    try {
      final woundCount = session.wounds.length;
      final reportPrompt = '''
Based on the comprehensive multi-wound clinical information below, generate a complete, professional clinical motivation letter for medical aid claims for a patient with $woundCount wounds requiring coordinated care.

CRITICAL FORMATTING REQUIREMENTS:
1. Write in complete sentences and flowing paragraphs, NOT bullet points or lists
2. Do NOT use symbols like dashes (-), slashes (/), or numbers (1,2,3) as formatting
3. Create a comprehensive, narrative medical report
4. Prominently include ICD-10 diagnostic codes within the text flow
5. Emphasize the complexity and coordination required for multi-wound care

PATIENT INFORMATION: ${clinicalData.patientName} (Medical Aid: ${clinicalData.medicalAid}, Membership: ${clinicalData.membershipNumber}, Referring Doctor: ${clinicalData.referringDoctor})

MULTI-WOUND OVERVIEW: This patient presents with $woundCount distinct wounds requiring coordinated wound care management. ${_buildReportWoundSummary(session.wounds, previousSession?.wounds)}

WOUND HISTORY AND BACKGROUND: ${clinicalData.woundHistory ?? 'Multiple wounds with varying etiologies'}, Primary Occurrence: ${clinicalData.woundOccurrence ?? 'Complex multi-factorial'}, Patient Comorbidities: ${clinicalData.patientComorbidities.isNotEmpty ? clinicalData.patientComorbidities.join(', ') : 'Multiple systemic conditions affecting healing'}, Session-Specific Findings: ${clinicalData.sessionComorbidities.isNotEmpty ? clinicalData.sessionComorbidities.join(', ') : 'Coordinated assessment completed'}

CURRENT SESSION INFORMATION: Practitioner: ${clinicalData.practitionerName}, Practice Number: ${clinicalData.practitionerPracticeNumber ?? 'Specialized wound care practice'}, Multi-wound Assessment Findings: ${clinicalData.infectionStatus ?? 'Individual wound status varies'}, Coordinated Testing: ${clinicalData.testsPerformed.isNotEmpty ? clinicalData.testsPerformed.join(', ') : 'Comprehensive multi-wound evaluation'}, Treatment Coordination: ${clinicalData.treatmentDates.isNotEmpty ? clinicalData.treatmentDates.join(', ') : 'Ongoing coordinated care required'}

INDIVIDUAL WOUND ASSESSMENTS: ${_buildIndividualWoundContext(session.wounds, previousSession?.wounds)}

TREATMENT COMPLEXITY: Multi-wound patients require significantly more resources, time, and expertise due to the need for individual wound assessment, coordinated treatment planning, increased infection risk management, and complex healing dynamics between multiple sites.

CODING INFORMATION: 
${selectedCodes.isNotEmpty ? ICD10Service.formatCodesForReport(selectedCodes) : 'Multiple ICD-10 codes required for comprehensive multi-wound documentation'}
Treatment Codes: ${treatmentCodes.join(', ')} (Enhanced coordination codes for multi-wound management)

Generate a professional clinical motivation letter emphasizing the complexity of multi-wound care. Begin with patient identification and multi-wound overview, describe the coordinated assessment approach and individual wound status in narrative form, detail the comprehensive treatment plan and resource requirements, prominently include all relevant ICD-10 diagnostic codes (highlighting PMB eligibility where applicable), and conclude with a strong authorization request that emphasizes the medical necessity of continued specialized multi-wound care. Write as a flowing medical narrative that clearly justifies the increased complexity and resource requirements of managing multiple wounds simultaneously.
''';

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a clinical documentation specialist creating comprehensive motivation letters for complex multi-wound patients requiring specialized care.',
            },
            {
              'role': 'user',
              'content': reportPrompt,
            }
          ],
          'max_tokens': 2000, // Increased for comprehensive multi-wound reports
          'temperature': 0.6,
          'presence_penalty': 0.0,
          'frequency_penalty': 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('OpenAI API error: ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('Failed to generate multi-wound report: $e');
    }
  }

  /// Extract ICD-10 codes with multi-wound intelligence
  List<SelectedICD10Code> _extractMultiWoundICD10Codes(String content, List<Wound> wounds) {
    final codes = <SelectedICD10Code>[];
    final regex = RegExp(r'([A-Z]\d{2}\.?\d*)', caseSensitive: false);
    final matches = regex.allMatches(content);
    
    for (final match in matches) {
      final codeStr = match.group(1)!;
      final icd10Code = ICD10Code(
        icd10Code: codeStr,
        whoFullDescription: 'Multi-wound context code',
        chapterNumber: 'TBD',
        chapterDescription: 'Multi-wound assessment',
        groupCode: 'TBD',
        groupDescription: 'Complex wound care',
        validForClinicalUse: true,
        validForPrimary: true,
      );
      
      // Determine code type based on context and wound count
      final codeType = codes.isEmpty 
          ? ICD10CodeType.primary 
          : ICD10CodeType.secondary;
      
      codes.add(SelectedICD10Code(
        code: icd10Code,
        type: codeType,
        justification: 'AI-suggested for multi-wound scenario (${wounds.length} wounds)',
        confidence: 0.85, // Higher confidence for multi-wound analysis
        selectedAt: DateTime.now(),
      ));
    }
    
    return codes;
  }

  /// Build wound summary for report
  String _buildReportWoundSummary(List<Wound> currentWounds, List<Wound>? previousWounds) {
    final buffer = StringBuffer();
    final totalCurrentArea = currentWounds.fold<double>(0, (sum, w) => sum + w.area);
    
    buffer.write('The combined wound burden measures ${totalCurrentArea.toStringAsFixed(1)} cm² across ${currentWounds.length} distinct sites. ');
    
    if (previousWounds != null && previousWounds.isNotEmpty) {
      final totalPreviousArea = previousWounds.fold<double>(0, (sum, w) => sum + w.area);
      final overallChange = ((totalPreviousArea - totalCurrentArea) / totalPreviousArea * 100);
      
      if (overallChange > 5) {
        buffer.write('Overall wound burden has improved by ${overallChange.toStringAsFixed(1)}% since the previous assessment, indicating positive response to coordinated treatment. ');
      } else if (overallChange < -5) {
        buffer.write('Overall wound burden has increased by ${overallChange.abs().toStringAsFixed(1)}%, requiring intensified coordinated care protocols. ');
      } else {
        buffer.write('Overall wound burden remains stable, requiring continued coordinated management. ');
      }
    }
    
    return buffer.toString();
  }

  /// Build individual wound context for report
  String _buildIndividualWoundContext(List<Wound> currentWounds, List<Wound>? previousWounds) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < currentWounds.length; i++) {
      final wound = currentWounds[i];
      final previousWound = previousWounds?.where((w) => w.id == wound.id).firstOrNull;
      
      buffer.write('Wound site ${i + 1} located at ${wound.location} presents as ${wound.type} classified as ${_getStageDescription(wound.stage)} with current measurements of ${wound.length} by ${wound.width} by ${wound.depth} centimeters. ');
      
      if (previousWound != null) {
        final areaChange = ((previousWound.area - wound.area) / previousWound.area * 100);
        if (areaChange > 10) {
          buffer.write('This wound shows significant improvement with ${areaChange.toStringAsFixed(1)}% reduction in surface area. ');
        } else if (areaChange < -10) {
          buffer.write('This wound requires intensified attention with ${areaChange.abs().toStringAsFixed(1)}% increase in surface area. ');
        } else {
          buffer.write('This wound remains stable requiring continued specialized care. ');
        }
      }
      
      if (wound.description.isNotEmpty) {
        buffer.write('Clinical assessment reveals ${wound.description}. ');
      }
    }
    
    return buffer.toString();
  }

  /// Helper methods
  ConversationStep _determineNextStep(ConversationStep currentStep, String aiResponse) {
    final stepOrder = ConversationStep.values;
    final currentIndex = stepOrder.indexOf(currentStep);
    
    if (currentIndex < stepOrder.length - 1) {
      return stepOrder[currentIndex + 1];
    }
    
    return ConversationStep.completed;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _getStageDescription(WoundStage stage) {
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
        return 'Deep Tissue Injury';
    }
  }

  static String _getSingleWoundPrompt() {
    return '''
You are an AI chatbot designed to assist wound care practitioners in South Africa with generating clinical motivation reports for medical aid claims. Your goal is to gather SESSION-SPECIFIC information through a conversational interview of 3-5 targeted questions, then use that data combined with existing patient data to compile a detailed report in the exact format of the provided example document.

IMPORTANT: The following information is already available from patient onboarding and session data and should NOT be asked again:
- Patient demographics (name, medical aid, membership number, referring doctor)
- Basic wound history and how the wound occurred
- Comorbidities and medical conditions (diabetes, hypertension, cardiovascular disease, etc.)
- Wound type and initial details
- Wound measurements (length, width, depth in centimeters)
- Wound location and anatomical details
- Wound classification/staging information

Key Guidelines for Session-Specific Questions:

Start by greeting the practitioner: "Hello! I have the patient's basic information from their file. I'll ask 3-5 questions about this specific session to generate the motivation report."

Ask questions one at a time, sequentially, focusing ONLY on current session data:
1. Practitioner name ("What is your name for the report?")
2. Current infection status ("Does the patient have any signs of infection today?")
3. Tests performed in this session ("What tests were performed during this session?")
4. Current TIMES assessment ("Please provide the current TIMES assessment.")
5. Current treatment plan ("What treatments are being applied in this session?")

After gathering sufficient session info, generate a professional clinical motivation report.
''';
  }
}
