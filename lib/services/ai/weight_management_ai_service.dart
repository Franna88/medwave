import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/conversation_data.dart';
import '../../models/icd10_code.dart';
import '../../config/api_keys.dart';
import 'icd10_service.dart';

class WeightManagementAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _apiKey = ApiKeys.openaiApiKey;
  
  static const String _systemPrompt = '''
You are an AI chatbot designed to assist weight management practitioners in South Africa with generating clinical motivation reports for medical aid claims. Your goal is to gather SESSION-SPECIFIC information through a conversational interview of 3-5 targeted questions, then use that data combined with existing patient data to compile a detailed report. Make sure that you capture the practitioner's name to put into the Report. The report must include relevant ICD-10 codes for obesity and metabolic conditions (E66.x for obesity, E11.x for diabetes, E78.x for lipid disorders, E03.x for thyroid disorders) extracted from the South African ICD-10 Master Industry Table (MIT, 2021 version), treatment codes for weight management interventions, and check for Prescribed Minimum Benefits (PMB) eligibility using the 2022 PMB ICD-10 Coded List from the Council for Medical Schemes.

IMPORTANT: The following information is already available from patient onboarding and session data and should NOT be asked again:
- Patient demographics (name, medical aid, membership number, referring doctor)
- Baseline weight, height, and BMI
- Comorbidities and medical conditions (diabetes, hypertension, cardiovascular disease, thyroid conditions, PCOS, metabolic syndrome, etc.) - these are captured during patient registration with detailed descriptions
- Baseline dietary habits and exercise routine
- Medications affecting weight
- Previous weight loss attempts and psychological factors

NEVER ask about comorbidities or medical conditions if they are listed in the patient's medical history from registration.
NEVER ask about next appointment dates - these are automatically pulled from the calendar system.

Key Guidelines for Session-Specific Questions:

Start by greeting the practitioner: "Hello! I have the patient's basic information from their file. I'll ask 3-5 questions about this specific session to generate the motivation report."
Ask questions one at a time, sequentially, focusing ONLY on current session data:

1. Practitioner name ("What is your name for the report?")
2. Current weight measurement ("What is the patient's current weight in kg and how has it changed since the last session?")
3. Current metabolic assessment ("Have there been any changes in metabolic parameters? Please provide any recent lab results - HbA1c, lipid profile, thyroid function tests, etc.")
4. Current dietary and exercise plan ("What is the current dietary and exercise plan being implemented? Have there been any modifications or challenges?")
5. Treatment interventions and medications ("What weight management treatments or medications are being used in this session? Include any dietary supplements, meal replacements, or pharmacological interventions.")

Do not ask all questions at once; make it a natural conversation.
After gathering sufficient session info (aim for after 3-5 questions), confirm: "Based on the session information and patient file, I'll now generate the report. Is there anything else about this session to add?"
Focus only on current session data - do not re-ask information already captured during patient onboarding.

Code Extraction Process:

For ICD-10 codes: Use the MIT Excel structure to identify weight and metabolic codes. Common codes include E66.0 (obesity due to excess calories), E66.1 (drug-induced obesity), E66.8 (other obesity), E66.9 (obesity unspecified), E11.x (type 2 diabetes), E78.x (disorders of lipoprotein metabolism), E03.x (hypothyroidism), E28.2 (polycystic ovarian syndrome). Select primary code as the main weight condition. Add secondary codes for underlying metabolic causes. Ensure codes are valid for clinical use.
For PMB: Check if the metabolic condition qualifies under PMB. Diabetes (E11.x), severe obesity with complications, and metabolic syndrome may qualify for PMB benefits.
Treatment codes: Use standard SA codes for weight management interventions based on described treatments (e.g., dietary counseling, exercise programs, pharmacological interventions).
If no exact match, choose the closest valid code and explain in the report.

Report Generation:

Once info is gathered, output the report in a professional format, filling in all fields with the collected data. Use complete sentences and paragraphs (NOT bullet points). Include weight measurements, BMI calculations, metabolic parameters, dietary and exercise assessments, and treatment interventions. End with the authorization request and signature.

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
        justification: 'Suggested by AI based on weight assessment',
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

  /// Generate final weight management motivation report
  Future<String> generateMotivationReport({
    required ExtractedClinicalData clinicalData,
    required List<SelectedICD10Code> selectedCodes,
    required List<String> treatmentCodes,
  }) async {
    try {
      final reportPrompt = '''
Based on the comprehensive clinical information below, generate a complete, readable weight management clinical motivation letter for medical aid claims. 

IMPORTANT FORMATTING REQUIREMENTS:
1. Write in complete sentences and paragraphs, NOT bullet points or lists
2. Do NOT use symbols like dashes (-), slashes (/), or numbers (1,2,3) as formatting
3. Write a comprehensive, flowing narrative report
4. Do NOT include any feedback requests or questions at the end
5. Use professional medical language in paragraph format

PATIENT INFORMATION: ${clinicalData.patientName} (Medical Aid: ${clinicalData.medicalAid}, Membership: ${clinicalData.membershipNumber}, Referring Doctor: ${clinicalData.referringDoctor})

WEIGHT HISTORY AND BASELINE: Baseline Weight: ${clinicalData.currentWeight ?? 'Not recorded'} kg, Target Weight: ${clinicalData.targetWeight ?? 'Not specified'} kg, Weight Change: ${clinicalData.weightChange != null ? '${clinicalData.weightChange!.toStringAsFixed(1)} kg' : 'Not calculated'}, Patient Comorbidities: ${clinicalData.patientComorbidities.isNotEmpty ? clinicalData.patientComorbidities.join(', ') : 'None specified'}, Session Comorbidities: ${clinicalData.sessionComorbidities.isNotEmpty ? clinicalData.sessionComorbidities.join(', ') : 'None specified'}

CURRENT SESSION INFORMATION: Practitioner: ${clinicalData.practitionerName}, Practice Number: ${clinicalData.practitionerPracticeNumber ?? 'Not provided'}, Contact: ${clinicalData.practitionerContactDetails ?? 'Not provided'}, Current Weight: ${clinicalData.currentWeight ?? 'Not measured'} kg, Dietary Plan: ${clinicalData.dietaryPlan ?? 'Individualized nutritional plan'}, Exercise Plan: ${clinicalData.exercisePlan ?? 'Structured exercise program'}, Tests Performed: ${clinicalData.testsPerformed.isNotEmpty ? clinicalData.testsPerformed.join(', ') : 'None performed'}, Additional Notes: ${clinicalData.additionalNotes ?? 'Progress and challenges discussed'}

NEXT APPOINTMENTS: ${clinicalData.appointmentSummary}

CODING INFORMATION: 
${selectedCodes.isNotEmpty ? ICD10Service.formatCodesForReport(selectedCodes) : 'ICD-10 codes to be determined based on clinical assessment (recommend E66.0 for obesity, E11.9 for type 2 diabetes if applicable, E78.5 for hyperlipidemia if applicable)'}
Treatment Codes: ${treatmentCodes.join(', ')}

Generate a professional weight management clinical motivation letter written in fluent paragraph format. Begin with patient identification and weight history, describe the current metabolic status and weight measurements in narrative form, detail the current session findings including dietary and exercise adherence in complete sentences, and PROMINENTLY include the ICD-10 diagnostic codes within the text (especially noting any PMB-eligible codes for guaranteed coverage). 

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
      throw Exception('Error generating weight management motivation report: $e');
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

