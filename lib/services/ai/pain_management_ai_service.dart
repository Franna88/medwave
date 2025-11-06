import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/conversation_data.dart';
import '../../models/icd10_code.dart';
import '../../config/api_keys.dart';
import 'icd10_service.dart';

class PainManagementAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _apiKey = ApiKeys.openaiApiKey;
  
  static const String _systemPrompt = '''
You are an AI chatbot designed to assist pain management practitioners in South Africa with generating clinical motivation reports for medical aid claims. Your goal is to gather SESSION-SPECIFIC information through a conversational interview of 3-5 targeted questions, then use that data combined with existing patient data to compile a detailed report. Make sure that you capture the practitioner's name to put into the Report. The report must include relevant ICD-10 codes for pain conditions (M79.x for pain in limb, G89.x for pain disorders, R52.x for pain) extracted from the South African ICD-10 Master Industry Table (MIT, 2021 version), treatment codes for pain management interventions, and check for Prescribed Minimum Benefits (PMB) eligibility using the 2022 PMB ICD-10 Coded List from the Council for Medical Schemes.

IMPORTANT: The following information is already available from patient onboarding and session data and should NOT be asked again:
- Patient demographics (name, medical aid, membership number, referring doctor)
- Baseline pain history, locations, and duration
- Comorbidities and medical conditions (diabetes, hypertension, cardiovascular disease, etc.) - these are captured during patient registration with detailed descriptions
- Pain type (neuropathic, nociceptive, mixed)
- Baseline VAS score and pain intensity
- Medications affecting pain management

NEVER ask about comorbidities or medical conditions if they are listed in the patient's medical history from registration.
NEVER ask about next appointment dates - these are automatically pulled from the calendar system.

Key Guidelines for Session-Specific Questions:

Start by greeting the practitioner: "Hello! I have the patient's basic information from their file. I'll ask 3-5 questions about this specific session to generate the motivation report."
Ask questions one at a time, sequentially, focusing ONLY on current session data:

1. Practitioner name ("What is your name for the report?")
2. Current pain assessment ("What is the patient's current VAS pain score (0-10) and how has their pain changed since the last session?")
3. Current pain locations and characteristics ("Please describe the current pain locations and any changes in pain characteristics - burning, shooting, aching, etc.")
4. Functional impact ("How is the pain currently affecting the patient's daily activities and quality of life?")
5. Current treatment plan and interventions ("What pain management treatments are being applied in this session? Include medications, physical therapy, nerve blocks, or other interventions.")

Do not ask all questions at once; make it a natural conversation.
After gathering sufficient session info (aim for after 3-5 questions), confirm: "Based on the session information and patient file, I'll now generate the report. Is there anything else about this session to add?"
Focus only on current session data - do not re-ask information already captured during patient onboarding.

Code Extraction Process:

For ICD-10 codes: Use the MIT Excel structure to identify pain-related codes. Common pain codes include M79.6 (pain in limb), M79.3 (panniculitis), G89.2 (chronic pain), R52.1 (chronic intractable pain), M54.x (dorsalgia/back pain), M25.5 (joint pain). Select primary code as the main pain condition. Add secondary codes for underlying causes (e.g., E11.4x for diabetic neuropathy, M16.x for osteoarthritis). Ensure codes are valid for clinical use.
For PMB: Check if the pain condition qualifies under PMB. Chronic pain conditions related to PMB diagnoses (like diabetic neuropathy, cancer pain, post-surgical pain) should be noted.
Treatment codes: Use standard SA codes for pain management interventions based on described treatments (e.g., nerve blocks, physical therapy, medication management).
If no exact match, choose the closest valid code and explain in the report.

Report Generation:

Once info is gathered, output the report in a professional format, filling in all fields with the collected data. Use complete sentences and paragraphs (NOT bullet points). Include pain assessment scales, functional impact measures, and treatment interventions. End with the authorization request and signature.

Keep responses professional, empathetic, and compliant with SA healthcare standards. Do not provide medical advice. If unsure about a code, note "Recommended code; confirm with MIT."
''';

  /// Generate AI response for conversation
  Future<OpenAIResponse> generateResponse({
    required List<AIMessage> conversationHistory,
    required String userMessage,
    required ConversationStep currentStep,
  }) async {
    try {
      // Build conversation history for OpenAI
      final messages = [
        {
          'role': 'system',
          'content': _systemPrompt,
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
          'max_tokens': 1000,
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
          suggestedCodes: _extractICD10Codes(content),
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

  /// Extract ICD-10 codes mentioned in AI response
  List<SelectedICD10Code> _extractICD10Codes(String content) {
    final codes = <SelectedICD10Code>[];
    final regex = RegExp(r'([A-Z]\d{2}\.?\d*)', caseSensitive: false);
    final matches = regex.allMatches(content);
    
    for (final match in matches) {
      final codeStr = match.group(1)!;
      final icd10Code = ICD10Code(
        icd10Code: codeStr,
        whoFullDescription: 'Code mentioned in AI response',
        chapterNumber: 'TBD',
        chapterDescription: 'To be determined from database lookup',
        groupCode: 'TBD',
        groupDescription: 'To be determined from database lookup',
        validForClinicalUse: true,
        validForPrimary: true,
      );
      
      codes.add(SelectedICD10Code(
        code: icd10Code,
        type: ICD10CodeType.primary,
        justification: 'Suggested by AI based on pain assessment',
        confidence: 0.8,
        selectedAt: DateTime.now(),
      ));
    }
    
    return codes;
  }

  /// Determine next conversation step based on current step and AI response
  ConversationStep _determineNextStep(ConversationStep currentStep, String aiResponse) {
    final stepOrder = ConversationStep.values;
    final currentIndex = stepOrder.indexOf(currentStep);
    
    if (currentIndex < stepOrder.length - 1) {
      return stepOrder[currentIndex + 1];
    }
    
    return ConversationStep.completed;
  }

  /// Generate final pain management motivation report
  Future<String> generateMotivationReport({
    required ExtractedClinicalData clinicalData,
    required List<SelectedICD10Code> selectedCodes,
    required List<String> treatmentCodes,
  }) async {
    try {
      final reportPrompt = '''
Based on the comprehensive clinical information below, generate a complete, readable pain management clinical motivation letter for medical aid claims. 

IMPORTANT FORMATTING REQUIREMENTS:
1. Write in complete sentences and paragraphs, NOT bullet points or lists
2. Do NOT use symbols like dashes (-), slashes (/), or numbers (1,2,3) as formatting
3. Write a comprehensive, flowing narrative report
4. Do NOT include any feedback requests or questions at the end
5. Use professional medical language in paragraph format

PATIENT INFORMATION: ${clinicalData.patientName} (Medical Aid: ${clinicalData.medicalAid}, Membership: ${clinicalData.membershipNumber}, Referring Doctor: ${clinicalData.referringDoctor})

PAIN HISTORY AND BASELINE: Pain Locations: ${clinicalData.painLocations?.join(', ') ?? 'Multiple sites'}, Pain Type: ${clinicalData.painType ?? 'Mixed pain'}, Baseline VAS Score: ${clinicalData.currentVasScore ?? 'Not recorded'}, Patient Comorbidities: ${clinicalData.patientComorbidities.isNotEmpty ? clinicalData.patientComorbidities.join(', ') : 'None specified'}

CURRENT SESSION INFORMATION: Practitioner: ${clinicalData.practitionerName}, Practice Number: ${clinicalData.practitionerPracticeNumber ?? 'Not provided'}, Contact: ${clinicalData.practitionerContactDetails ?? 'Not provided'}, Current VAS Score: ${clinicalData.currentVasScore ?? 'Not assessed'}, Pain Medication Plan: ${clinicalData.painMedicationPlan ?? 'Standard pain management protocol'}, Functional Impact: ${clinicalData.additionalNotes ?? 'Impact on daily activities assessed'}, Tests Performed: ${clinicalData.testsPerformed.isNotEmpty ? clinicalData.testsPerformed.join(', ') : 'None performed'}

NEXT APPOINTMENTS: ${clinicalData.appointmentSummary}

CODING INFORMATION: 
${selectedCodes.isNotEmpty ? ICD10Service.formatCodesForReport(selectedCodes) : 'ICD-10 codes to be determined based on clinical assessment (recommend M79.6 for limb pain, G89.2 for chronic pain, or R52 for unspecified pain)'}
Treatment Codes: ${treatmentCodes.join(', ')}

Generate a professional pain management clinical motivation letter written in fluent paragraph format. Begin with patient identification and pain history, describe the current pain assessment and functional impact in narrative form, detail the current session findings and treatment plan in complete sentences, and PROMINENTLY include the ICD-10 diagnostic codes within the text (especially noting any PMB-eligible codes for guaranteed coverage).

CRITICAL APPOINTMENT SECTION: After discussing the treatment plan and before the final authorization request, you MUST include a clearly labeled section that starts with "FOLLOW-UP APPOINTMENTS:" on its own line, then list each appointment on a separate line below it using the EXACT information from "NEXT APPOINTMENTS" above. Format each appointment on its own line with a dash prefix (e.g., "- Friday, November 14, 2025 at 9:00 AM"). Include ALL appointment dates and times listed - do not summarize or abbreviate. If no appointments are scheduled, state "No upcoming appointments have been scheduled at this time." Do NOT make up or infer appointment dates - only use what is provided.

Conclude with the authorization request. Do NOT use bullet points, lists, or formatting symbols. Write as a complete, flowing medical report that clearly includes the diagnostic codes and appointment information for insurance processing.
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
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': reportPrompt},
          ],
          'max_tokens': 2000,
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating pain management motivation report: $e');
    }
  }

  /// Check OpenAI API health
  Future<bool> checkApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// OpenAI API response model
class OpenAIResponse {
  final String content;
  final bool isSuccess;
  final String? errorMessage;
  final ConversationStep? nextStep;
  final List<SelectedICD10Code>? suggestedCodes;
  final OpenAIUsage? usage;

  const OpenAIResponse({
    required this.content,
    required this.isSuccess,
    this.errorMessage,
    this.nextStep,
    this.suggestedCodes,
    this.usage,
  });

  @override
  String toString() {
    return 'OpenAIResponse(isSuccess: $isSuccess, content: ${content.substring(0, content.length.clamp(0, 100))}...)';
  }
}

/// OpenAI usage statistics
class OpenAIUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const OpenAIUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory OpenAIUsage.fromMap(Map<String, dynamic> map) {
    return OpenAIUsage(
      promptTokens: map['prompt_tokens'] ?? 0,
      completionTokens: map['completion_tokens'] ?? 0,
      totalTokens: map['total_tokens'] ?? 0,
    );
  }

  double get estimatedCost {
    const inputCostPer1k = 0.00015;
    const outputCostPer1k = 0.0006;
    
    final inputCost = (promptTokens / 1000) * inputCostPer1k;
    final outputCost = (completionTokens / 1000) * outputCostPer1k;
    
    return inputCost + outputCost;
  }

  @override
  String toString() {
    return 'OpenAIUsage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens, cost: \$${estimatedCost.toStringAsFixed(4)})';
  }
}

