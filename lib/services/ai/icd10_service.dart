import '../../models/icd10_code.dart';

/// Service for ICD-10 code analysis and suggestions based on South African MIT
class ICD10Service {
  
  /// Common ICD-10 codes for wound care based on SA MIT 2021
  static const List<Map<String, dynamic>> _commonWoundCodes = [
    // Chapter XII - Diseases of skin and subcutaneous tissue (L00-L99)
    {
      'icd10_code': 'L89.612',
      'who_full_description': 'Pressure ulcer of left heel, stage 2',
      'chapter_number': 'XII',
      'chapter_description': 'Diseases of the skin and subcutaneous tissue',
      'group_code': 'L89',
      'group_description': 'Pressure ulcer',
      'valid_for_clinical_use': true,
      'valid_for_primary': true,
      'is_pmb_eligible': false,
      'keywords': ['pressure', 'ulcer', 'heel', 'stage 2', 'bedsore']
    },
    {
      'icd10_code': 'L89.622',
      'who_full_description': 'Pressure ulcer of right heel, stage 2',
      'chapter_number': 'XII',
      'chapter_description': 'Diseases of the skin and subcutaneous tissue',
      'group_code': 'L89',
      'group_description': 'Pressure ulcer',
      'valid_for_clinical_use': true,
      'valid_for_primary': true,
      'is_pmb_eligible': false,
      'keywords': ['pressure', 'ulcer', 'heel', 'stage 2', 'bedsore']
    },
    {
      'icd10_code': 'L97.4',
      'who_full_description': 'Non-pressure chronic ulcer of heel and midfoot',
      'chapter_number': 'XII',
      'chapter_description': 'Diseases of the skin and subcutaneous tissue',
      'group_code': 'L97',
      'group_description': 'Non-pressure chronic ulcer of lower limb',
      'valid_for_clinical_use': true,
      'valid_for_primary': true,
      'is_pmb_eligible': true,
      'pmb_description': 'Chronic wound care under PMB',
      'keywords': ['chronic', 'ulcer', 'heel', 'foot', 'diabetic', 'non-pressure']
    },
    {
      'icd10_code': 'L08.9',
      'who_full_description': 'Local infection of skin and subcutaneous tissue, unspecified',
      'chapter_number': 'XII',
      'chapter_description': 'Diseases of the skin and subcutaneous tissue',
      'group_code': 'L08',
      'group_description': 'Other local infections of skin and subcutaneous tissue',
      'valid_for_clinical_use': true,
      'valid_for_primary': true,
      'is_pmb_eligible': false,
      'keywords': ['infection', 'wound', 'infected', 'cellulitis', 'local']
    },
    
    // Chapter IV - Endocrine, nutritional and metabolic diseases (E00-E90)
    {
      'icd10_code': 'E11.621',
      'who_full_description': 'Type 2 diabetes mellitus with foot ulcer',
      'chapter_number': 'IV',
      'chapter_description': 'Endocrine, nutritional and metabolic diseases',
      'group_code': 'E11',
      'group_description': 'Type 2 diabetes mellitus',
      'valid_for_clinical_use': true,
      'valid_for_primary': true,
      'is_pmb_eligible': true,
      'pmb_description': 'Diabetes complications under PMB',
      'keywords': ['diabetes', 'diabetic', 'foot', 'ulcer', 'type 2', 'mellitus']
    },
    {
      'icd10_code': 'E10.9',
      'who_full_description': 'Type 1 diabetes mellitus without complications',
      'chapter_number': 'IV',
      'chapter_description': 'Endocrine, nutritional and metabolic diseases',
      'group_code': 'E10',
      'group_description': 'Type 1 diabetes mellitus',
      'valid_for_clinical_use': true,
      'valid_for_primary': false,
      'is_pmb_eligible': true,
      'pmb_description': 'Diabetes under PMB',
      'keywords': ['diabetes', 'diabetic', 'type 1', 'mellitus', 'comorbidity']
    },
    {
      'icd10_code': 'E11.9',
      'who_full_description': 'Type 2 diabetes mellitus without complications',
      'chapter_number': 'IV',
      'chapter_description': 'Endocrine, nutritional and metabolic diseases',
      'group_code': 'E11',
      'group_description': 'Type 2 diabetes mellitus',
      'valid_for_clinical_use': true,
      'valid_for_primary': false,
      'is_pmb_eligible': true,
      'pmb_description': 'Diabetes under PMB',
      'keywords': ['diabetes', 'diabetic', 'type 2', 'mellitus', 'comorbidity']
    },
    
    // Chapter XIX - Injury, poisoning and certain other consequences (S00-T98)
    {
      'icd10_code': 'T79.3',
      'who_full_description': 'Post-traumatic wound infection',
      'chapter_number': 'XIX',
      'chapter_description': 'Injury, poisoning and certain other consequences of external causes',
      'group_code': 'T79',
      'group_description': 'Certain early complications of trauma',
      'valid_for_clinical_use': true,
      'valid_for_primary': true,
      'is_pmb_eligible': false,
      'keywords': ['trauma', 'traumatic', 'wound', 'infection', 'post-traumatic']
    },
    {
      'icd10_code': 'T81.4',
      'who_full_description': 'Infection following a procedure',
      'chapter_number': 'XIX',
      'chapter_description': 'Injury, poisoning and certain other consequences of external causes',
      'group_code': 'T81',
      'group_description': 'Complications of procedures',
      'valid_for_clinical_use': true,
      'valid_for_primary': true,
      'is_pmb_eligible': false,
      'keywords': ['surgical', 'surgery', 'post-operative', 'procedure', 'infection']
    },
    
    // Chapter XX - External causes (V01-Y98)
    {
      'icd10_code': 'W10.9',
      'who_full_description': 'Fall on and from stairs and steps, unspecified',
      'chapter_number': 'XX',
      'chapter_description': 'External causes of morbidity and mortality',
      'group_code': 'W10',
      'group_description': 'Fall on and from stairs and steps',
      'valid_for_clinical_use': true,
      'valid_for_primary': false,
      'is_pmb_eligible': false,
      'keywords': ['fall', 'stairs', 'steps', 'trauma', 'accident']
    },
    {
      'icd10_code': 'W26.8',
      'who_full_description': 'Contact with other sharp objects',
      'chapter_number': 'XX',
      'chapter_description': 'External causes of morbidity and mortality',
      'group_code': 'W26',
      'group_description': 'Contact with knife, sword or dagger',
      'valid_for_clinical_use': true,
      'valid_for_primary': false,
      'is_pmb_eligible': false,
      'keywords': ['sharp', 'cut', 'knife', 'blade', 'laceration']
    },
    
    // Additional common conditions
    {
      'icd10_code': 'I10',
      'who_full_description': 'Essential hypertension',
      'chapter_number': 'IX',
      'chapter_description': 'Diseases of the circulatory system',
      'group_code': 'I10',
      'group_description': 'Essential hypertension',
      'valid_for_clinical_use': true,
      'valid_for_primary': false,
      'is_pmb_eligible': true,
      'pmb_description': 'Hypertension under PMB',
      'keywords': ['hypertension', 'high blood pressure', 'bp', 'comorbidity']
    },
    {
      'icd10_code': 'N18.9',
      'who_full_description': 'Chronic kidney disease, unspecified',
      'chapter_number': 'XIV',
      'chapter_description': 'Diseases of the genitourinary system',
      'group_code': 'N18',
      'group_description': 'Chronic kidney disease',
      'valid_for_clinical_use': true,
      'valid_for_primary': false,
      'is_pmb_eligible': true,
      'pmb_description': 'Chronic kidney disease under PMB',
      'keywords': ['kidney', 'renal', 'chronic', 'ckd', 'comorbidity']
    }
  ];

  /// Analyze wound description and suggest appropriate ICD-10 codes
  static List<ICD10SearchResult> suggestCodes(String description) {
    final cleanDescription = description.toLowerCase();
    final results = <ICD10SearchResult>[];
    
    for (final codeData in _commonWoundCodes) {
      final keywords = List<String>.from(codeData['keywords'] ?? []);
      final matchedKeywords = <String>[];
      double confidence = 0.0;
      
      // Check for keyword matches
      for (final keyword in keywords) {
        if (cleanDescription.contains(keyword.toLowerCase())) {
          matchedKeywords.add(keyword);
          confidence += 0.2; // Base score per keyword
        }
      }
      
      // Boost confidence for exact matches
      if (cleanDescription.contains(codeData['who_full_description'].toString().toLowerCase())) {
        confidence += 0.5;
      }
      
      // Only include codes with some relevance
      if (matchedKeywords.isNotEmpty) {
        confidence = confidence > 1.0 ? 1.0 : confidence; // Cap at 1.0
        
        final code = ICD10Code(
          icd10Code: codeData['icd10_code'],
          whoFullDescription: codeData['who_full_description'],
          chapterNumber: codeData['chapter_number'],
          chapterDescription: codeData['chapter_description'],
          groupCode: codeData['group_code'],
          groupDescription: codeData['group_description'],
          validForClinicalUse: codeData['valid_for_clinical_use'],
          validForPrimary: codeData['valid_for_primary'],
          isPmbEligible: codeData['is_pmb_eligible'] ?? false,
          pmbDescription: codeData['pmb_description'],
        );
        
        results.add(ICD10SearchResult(
          code: code,
          confidence: confidence,
          matchedKeywords: matchedKeywords,
          explanation: _generateExplanation(code, matchedKeywords),
        ));
      }
    }
    
    // Sort by confidence (highest first) and return top results
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.take(5).toList(); // Return top 5 suggestions
  }

  /// Generate explanation for why a code was suggested
  static String _generateExplanation(ICD10Code code, List<String> matchedKeywords) {
    final pmbNote = code.isPmbEligible ? ' (PMB eligible - guaranteed coverage)' : '';
    return 'Matched keywords: ${matchedKeywords.join(', ')}$pmbNote';
  }

  /// Get primary code suggestions (valid for primary diagnosis)
  static List<ICD10SearchResult> getPrimarySuggestions(String description) {
    return suggestCodes(description)
        .where((result) => result.code.validForPrimary)
        .toList();
  }

  /// Get secondary code suggestions (comorbidities)
  static List<ICD10SearchResult> getSecondarySuggestions(String description) {
    return suggestCodes(description)
        .where((result) => !result.code.validForPrimary && result.code.validForClinicalUse)
        .toList();
  }

  /// Get external cause suggestions (Chapter XX codes)
  static List<ICD10SearchResult> getExternalCauseSuggestions(String description) {
    return suggestCodes(description)
        .where((result) => ICD10CodeValidator.isExternalCause(result.code))
        .toList();
  }

  /// Format codes for inclusion in AI reports
  static String formatCodesForReport(List<SelectedICD10Code> selectedCodes) {
    if (selectedCodes.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('\n**ICD-10 DIAGNOSTIC CODES:**');
    
    // Group codes by type
    final primaryCodes = selectedCodes.where((c) => c.type == ICD10CodeType.primary).toList();
    final secondaryCodes = selectedCodes.where((c) => c.type == ICD10CodeType.secondary).toList();
    final externalCodes = selectedCodes.where((c) => c.type == ICD10CodeType.externalCause).toList();
    
    if (primaryCodes.isNotEmpty) {
      buffer.writeln('\nPrimary Diagnosis:');
      for (final code in primaryCodes) {
        final pmb = code.code.isPmbEligible ? ' **[PMB - Guaranteed Coverage]**' : '';
        buffer.writeln('• ${code.code.icd10Code}: ${code.code.whoFullDescription}$pmb');
      }
    }
    
    if (secondaryCodes.isNotEmpty) {
      buffer.writeln('\nSecondary Diagnoses (Comorbidities):');
      for (final code in secondaryCodes) {
        final pmb = code.code.isPmbEligible ? ' **[PMB]**' : '';
        buffer.writeln('• ${code.code.icd10Code}: ${code.code.whoFullDescription}$pmb');
      }
    }
    
    if (externalCodes.isNotEmpty) {
      buffer.writeln('\nExternal Cause:');
      for (final code in externalCodes) {
        buffer.writeln('• ${code.code.icd10Code}: ${code.code.whoFullDescription}');
      }
    }
    
    return buffer.toString();
  }

  /// Auto-suggest codes based on conversation content
  static List<SelectedICD10Code> autoSuggestFromConversation(String conversationText) {
    final suggestions = suggestCodes(conversationText);
    final selectedCodes = <SelectedICD10Code>[];
    
    // Auto-select highest confidence primary code
    final primarySuggestion = suggestions
        .where((s) => s.code.validForPrimary)
        .where((s) => s.confidence > 0.4) // Only if reasonable confidence
        .firstOrNull;
    
    if (primarySuggestion != null) {
      selectedCodes.add(SelectedICD10Code(
        code: primarySuggestion.code,
        type: ICD10CodeType.primary,
        justification: primarySuggestion.explanation,
        confidence: primarySuggestion.confidence,
        selectedAt: DateTime.now(),
      ));
    }
    
    // Auto-select relevant secondary codes (comorbidities)
    final secondarySuggestions = suggestions
        .where((s) => !s.code.validForPrimary && s.code.validForClinicalUse)
        .where((s) => s.confidence > 0.3)
        .take(2) // Limit to 2 secondary codes
        .toList();
    
    for (final suggestion in secondarySuggestions) {
      selectedCodes.add(SelectedICD10Code(
        code: suggestion.code,
        type: ICD10CodeType.secondary,
        justification: suggestion.explanation,
        confidence: suggestion.confidence,
        selectedAt: DateTime.now(),
      ));
    }
    
    // Auto-select external cause if trauma-related
    final externalSuggestion = suggestions
        .where((s) => ICD10CodeValidator.isExternalCause(s.code))
        .where((s) => s.confidence > 0.3)
        .firstOrNull;
    
    if (externalSuggestion != null) {
      selectedCodes.add(SelectedICD10Code(
        code: externalSuggestion.code,
        type: ICD10CodeType.externalCause,
        justification: externalSuggestion.explanation,
        confidence: externalSuggestion.confidence,
        selectedAt: DateTime.now(),
      ));
    }
    
    return selectedCodes;
  }
}

/// Extension to get first element or null
extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
