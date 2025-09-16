import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/conversation_data.dart';
import '../../models/icd10_code.dart';
import '../../config/api_keys.dart';
import 'icd10_service.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _apiKey = ApiKeys.openaiApiKey;
  
  static const String _systemPrompt = '''
You are an AI chatbot designed to assist wound care practitioners in South Africa with generating clinical motivation reports for medical aid claims. Your goal is to gather SESSION-SPECIFIC information through a conversational interview of 3-5 targeted questions, then use that data combined with existing patient data to compile a detailed report in the exact format of the provided example document. Make sure that you capture the nurses name to put into the Report and you don't want to say Sr. Rene Black, because other nurses might use this AI chat. The report must include relevant ICD-10 codes (primary, secondary, and external cause where applicable) extracted from the South African ICD-10 Master Industry Table (MIT, 2021 version), treatment codes (e.g., 88002 for wound debridement), and check for Prescribed Minimum Benefits (PMB) eligibility using the 2022 PMB ICD-10 Coded List from the Council for Medical Schemes.

IMPORTANT: The following information is already available from patient onboarding and session data and should NOT be asked again:
- Patient demographics (name, medical aid, membership number, referring doctor)
- Basic wound history and how the wound occurred
- Comorbidities and medical conditions (diabetes, hypertension, cardiovascular disease, etc.) - these are captured during patient registration with detailed descriptions
- Wound type and initial details
- Wound measurements (length, width, depth in centimeters) - these are captured during the session
- Wound location and anatomical details
- Wound classification/staging information

NEVER ask about comorbidities or medical conditions if they are listed in the patient's medical history from registration.

Key Guidelines for Session-Specific Questions:

Start by greeting the practitioner: "Hello! I have the patient's basic information from their file. I'll ask 3-5 questions about this specific session to generate the motivation report."
Ask questions one at a time, sequentially, focusing ONLY on current session data:

1. Practitioner name ("What is your name for the report?")
2. Current infection status ("Does the patient have any signs of infection today? If yes, describe symptoms and any test results.")
3. Tests performed in this session ("What tests were performed during this session, such as HbA1c, CRP, ESR, wound swabs, etc.? Please provide results if available.")
4. Current TIMES assessment ("Please provide the current TIMES assessment: Tissue type, Inflammation/Infection signs, Moisture level, Edge condition, and Surrounding skin status.")
5. Current treatment plan ("What treatments are being applied in this session? Include cleansing methods, dressings, medications, and any planned treatments.")

Do not ask all questions at once; make it a natural conversation.
After gathering sufficient session info (aim for after 3-5 questions), confirm: "Based on the session information and patient file, I'll now generate the report. Is there anything else about this session to add?"
Focus only on current session data - do not re-ask information already captured during patient onboarding.

Code Extraction Process:

For ICD-10 codes: Simulate searching the MIT Excel structure (columns: A-Number, B-Chapter_No, C-Chapter_Desc, D-Group_Code, E-Group_Desc, F-ICD10_3_Code, G-ICD10_3_Code_Desc, H-ICD10_Code, I-WHO_Full_Desc, J-Valid_ICD10_ClinicalUse (Y/N), K-Valid_ICD10_Primary (Y/N), etc.). Use keyword matching on column I (WHO_Full_Desc) for the wound cause/description (e.g., search "pressure ulcer stage 2" → L89.02 if valid for clinical use). Select primary code as the main condition (e.g., L89.02 for pressure injury). Add secondary codes for co-morbidities (e.g., E11.9 for diabetes). If external cause applies, search Chapter XX (V01-Y98) for matches (e.g., "fall down stairs" → W10.9). Ensure codes are valid (J=Y, K=Y for primary).
For PMB: Check against the 2022 PMB Coded List (Excel with columns like code, description, PMB status). If the primary/secondary code matches a PMB condition (e.g., E11.621 for diabetic foot ulcer is PMB-eligible under diabetes complications), note it in the report (e.g., mark as PMB condition).
Treatment codes: Use standard SA codes like 88002 (debridement), 88031 (dressing), 88045 (advanced wound care) based on described treatments.
If no exact match, choose the closest valid code and explain in the report (e.g., "Closest match: L89.02 based on description").

Report Generation:

Once info is gathered, output the report in the exact format below, filling in all fields with the collected data. Use dropdown-style descriptions where applicable (e.g., for wound type: "Pressure Injury (Classification system NPUAP)"). Include a human body diagram description if location is provided (e.g., "Left heel marked on diagram"). End with the authorization request and signature.

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
          'model': 'gpt-4o-mini',  // Using the latest model
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
      // Create a basic ICD10Code (would be enhanced with database lookup)
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
        type: ICD10CodeType.primary, // Would be determined by context
        justification: 'Suggested by AI based on wound description',
        confidence: 0.8,
        selectedAt: DateTime.now(),
      ));
    }
    
    return codes;
  }

  /// Determine next conversation step based on current step and AI response
  ConversationStep _determineNextStep(ConversationStep currentStep, String aiResponse) {
    // Simple logic - would be enhanced with AI content analysis
    final stepOrder = ConversationStep.values;
    final currentIndex = stepOrder.indexOf(currentStep);
    
    if (currentIndex < stepOrder.length - 1) {
      return stepOrder[currentIndex + 1];
    }
    
    return ConversationStep.completed;
  }

  /// Generate final motivation report
  Future<String> generateMotivationReport({
    required ExtractedClinicalData clinicalData,
    required List<SelectedICD10Code> selectedCodes,
    required List<String> treatmentCodes,
  }) async {
    try {
      final reportPrompt = '''
Based on the comprehensive clinical information below, generate a complete, readable clinical motivation letter for medical aid claims. 

IMPORTANT FORMATTING REQUIREMENTS:
1. Write in complete sentences and paragraphs, NOT bullet points or lists
2. Do NOT use symbols like dashes (-), slashes (/), or numbers (1,2,3) as formatting
3. Write a comprehensive, flowing narrative report
4. Do NOT include any feedback requests or questions at the end
5. Use professional medical language in paragraph format

PATIENT INFORMATION: ${clinicalData.patientName} (Medical Aid: ${clinicalData.medicalAid}, Membership: ${clinicalData.membershipNumber}, Referring Doctor: ${clinicalData.referringDoctor})

WOUND HISTORY AND BACKGROUND: ${clinicalData.woundHistory ?? 'Not specified'}, Occurrence: ${clinicalData.woundOccurrence ?? 'Not specified'}, Patient Comorbidities: ${clinicalData.patientComorbidities.isNotEmpty ? clinicalData.patientComorbidities.join(', ') : 'None specified'}, Session Comorbidities: ${clinicalData.sessionComorbidities.isNotEmpty ? clinicalData.sessionComorbidities.join(', ') : 'None specified'}

CURRENT SESSION INFORMATION: Practitioner: ${clinicalData.practitionerName}, Practice Number: ${clinicalData.practitionerPracticeNumber ?? 'Not provided'}, Contact: ${clinicalData.practitionerContactDetails ?? 'Not provided'}, Wound Type: ${clinicalData.woundTypeAndHistory ?? 'Not provided'}, Occurrence Description: ${clinicalData.woundOccurrenceDescription ?? 'Not provided'}, Infection Status: ${clinicalData.infectionStatus ?? 'None reported'}, Tests Performed: ${clinicalData.testsPerformed.isNotEmpty ? clinicalData.testsPerformed.join(', ') : 'None performed'}, Treatment Dates: ${clinicalData.treatmentDates.isNotEmpty ? clinicalData.treatmentDates.join(', ') : 'Not scheduled'}, Current Wound Status: ${clinicalData.woundDetails?.type ?? 'Not specified'}, Size: ${clinicalData.woundDetails?.size ?? 'Not measured'}, Location: ${clinicalData.woundDetails?.location ?? 'Not specified'}, TIMES Assessment - Tissue: ${clinicalData.woundDetails?.timesAssessment?.tissue ?? 'Not assessed'}, Inflammation: ${clinicalData.woundDetails?.timesAssessment?.inflammation ?? 'Not assessed'}, Moisture: ${clinicalData.woundDetails?.timesAssessment?.moisture ?? 'Not assessed'}, Treatment Plan: ${clinicalData.treatmentDetails?.plannedTreatments.isNotEmpty == true ? clinicalData.treatmentDetails!.plannedTreatments.join(', ') : 'Standard wound care'}, Additional Notes: ${clinicalData.additionalNotes ?? 'None'}

CODING INFORMATION: 
${selectedCodes.isNotEmpty ? ICD10Service.formatCodesForReport(selectedCodes) : 'ICD-10 codes to be determined based on clinical assessment'}
Treatment Codes: ${treatmentCodes.join(', ')}

Generate a professional clinical motivation letter written in fluent paragraph format. Begin with patient identification, describe the wound history and current condition in narrative form, detail the current session findings and treatments in complete sentences, and PROMINENTLY include the ICD-10 diagnostic codes within the text (especially noting any PMB-eligible codes for guaranteed coverage). Conclude with the authorization request. Do NOT use bullet points, lists, or formatting symbols. Write as a complete, flowing medical report that clearly includes the diagnostic codes for insurance processing.
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
      throw Exception('Error generating motivation report: $e');
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

  /// Analyzes user response and provides intelligent acknowledgment
  Future<String> analyzeUserResponse({
    required String userResponse,
    required String conversationContext,
    required String currentQuestion,
    required String stepType,
  }) async {
    try {
      final prompt = '''
You are a professional wound care AI assistant analyzing a practitioner's response during clinical data collection.

CONTEXT:
$conversationContext

CURRENT STEP: $currentQuestion
USER'S RESPONSE: "$userResponse"

INSTRUCTIONS:
1. Analyze the user's response for clinical relevance and completeness
2. If the response seems inappropriate, incomplete, or nonsensical for the clinical context, politely ask for clarification
3. If the response is good, acknowledge it and explain how it will help the clinical motivation
4. Be professional, concise (1-2 sentences), and supportive
5. If you detect test gibberish/random text, politely request proper clinical information

EXAMPLES:
- Good response: "Thank you! I've recorded that there are no signs of infection, which supports continued outpatient treatment."
- Incomplete response: "I need a bit more detail about the infection status. Are there any signs like redness, swelling, discharge, or elevated temperature?"
- Nonsensical response: "I didn't quite catch that. Could you please provide the current infection status - specifically whether you observe any signs of infection today?"

Provide your response:''';

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': 'You are a professional clinical AI assistant.'},
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 150,
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        throw Exception('Failed to analyze response: ${response.statusCode}');
      }
             
    } catch (e) {
      print('Error analyzing user response: $e');
      return 'Thank you for your response. Let me continue with the next question.';
    }
  }

  /// Analyzes user response with validation and returns both message and proceed decision
  Future<Map<String, dynamic>> analyzeUserResponseWithValidation({
    required String userResponse,
    required String conversationContext,
    required String currentQuestion,
    required String stepType,
  }) async {
    try {
      final prompt = '''
You are a clinical data collection system. Your ONLY job is to collect information silently.

CURRENT QUESTION: $currentQuestion
USER'S RESPONSE: "$userResponse"

CRITICAL INSTRUCTIONS:
1. NEVER provide feedback, acknowledgments, or explanations
2. ONLY respond if there is a genuine problem requiring correction:
   - Response is complete gibberish/random characters
   - Response contains obvious spelling errors that affect meaning
   - Response is completely irrelevant to the clinical question

3. If you must respond, be EXTREMELY brief (max 10 words)
4. For valid responses (even if short), ALWAYS respond with empty message and proceed=true

RESPONSE FORMAT - JSON only:
Valid response: {"message": "", "proceed": true}
Needs spelling fix: {"message": "Please check spelling", "proceed": false}
Gibberish: {"message": "Please provide relevant clinical information", "proceed": false}

Respond only with valid JSON:''';

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': 'You are a silent clinical data collection system. Respond only with valid JSON. Never provide feedback unless correction is needed.'},
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 50, // Reduced for brief corrections only
          'temperature': 0.1, // Very low for deterministic, minimal responses
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content']?.trim() ?? '';
        
        // Parse the JSON response
        try {
          final result = jsonDecode(content);
          return {
            'message': result['message'] ?? 'Thank you for your response.',
            'proceed': result['proceed'] ?? true,
          };
        } catch (e) {
          // If JSON parsing fails, be conservative and proceed silently
          return {
            'message': '', // Silent - no feedback
            'proceed': userResponse.length >= 2, // Proceed if not too short
          };
        }
      }

      return {
        'message': '', // Silent - no feedback
        'proceed': true,
      };
    } catch (e) {
      return {
        'message': '', // Silent - no feedback  
        'proceed': true,
      };
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
    // GPT-4o-mini pricing (as of 2024)
    const inputCostPer1k = 0.00015;  // $0.00015 per 1K tokens
    const outputCostPer1k = 0.0006;  // $0.0006 per 1K tokens
    
    final inputCost = (promptTokens / 1000) * inputCostPer1k;
    final outputCost = (completionTokens / 1000) * outputCostPer1k;
    
    return inputCost + outputCost;
  }

  @override
  String toString() {
    return 'OpenAIUsage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens, cost: \$${estimatedCost.toStringAsFixed(4)})';
  }
}


