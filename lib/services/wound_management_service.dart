import '../models/patient.dart';

/// Service for managing wound-related operations and routing decisions
class WoundManagementService {
  
  /// Determines if a patient has multiple wounds based on their current or baseline wounds
  static bool hasMultipleWounds(Patient patient) {
    // Check current wounds first
    if (patient.currentWounds.isNotEmpty) {
      return patient.currentWounds.length > 1;
    }
    
    // Fallback to baseline wounds
    if (patient.baselineWounds.isNotEmpty) {
      return patient.baselineWounds.length > 1;
    }
    
    // If no wounds data, assume single wound (default behavior)
    return false;
  }
  
  /// Gets the wound count for a patient
  static int getWoundCount(Patient patient) {
    if (patient.currentWounds.isNotEmpty) {
      return patient.currentWounds.length;
    }
    
    if (patient.baselineWounds.isNotEmpty) {
      return patient.baselineWounds.length;
    }
    
    return 1; // Default to single wound
  }
  
  /// Determines the appropriate session logging route based on wound count
  static String getSessionLoggingRoute(String patientId, Patient patient) {
    if (hasMultipleWounds(patient)) {
      return '/patients/$patientId/multi-wound-session';
    } else {
      return '/patients/$patientId/session';
    }
  }
  
  /// Gets a summary of wounds for display purposes
  static String getWoundSummary(Patient patient) {
    final woundCount = getWoundCount(patient);
    
    if (woundCount == 1) {
      final wound = patient.currentWounds.isNotEmpty 
          ? patient.currentWounds.first 
          : patient.baselineWounds.first;
      return '${wound.type} - ${wound.location}';
    } else {
      return '$woundCount wounds';
    }
  }
  
  /// Gets wound locations for quick reference
  static List<String> getWoundLocations(Patient patient) {
    final wounds = patient.currentWounds.isNotEmpty 
        ? patient.currentWounds 
        : patient.baselineWounds;
        
    return wounds.map((w) => w.location).toList();
  }
  
  /// Calculates overall healing progress across all wounds
  static double calculateOverallHealingProgress(Patient patient, List<Session> sessions) {
    if (sessions.length < 2) return 0.0;
    
    final firstSession = sessions.first;
    final lastSession = sessions.last;
    
    if (firstSession.wounds.isEmpty || lastSession.wounds.isEmpty) {
      return 0.0;
    }
    
    double totalInitialArea = 0.0;
    double totalCurrentArea = 0.0;
    int matchedWounds = 0;
    
    // Calculate progress for each wound that can be matched between sessions
    for (final initialWound in firstSession.wounds) {
      final currentWound = lastSession.wounds.firstWhere(
        (w) => w.id == initialWound.id,
        orElse: () => initialWound, // Fallback to same wound if not found
      );
      
      totalInitialArea += initialWound.area;
      totalCurrentArea += currentWound.area;
      matchedWounds++;
    }
    
    if (totalInitialArea == 0 || matchedWounds == 0) return 0.0;
    
    // Calculate percentage reduction in total wound area
    final reduction = (totalInitialArea - totalCurrentArea) / totalInitialArea;
    return (reduction * 100).clamp(0.0, 100.0);
  }
  
  /// Gets the most problematic wound (largest area or highest stage)
  static Wound? getMostProblematicWound(Patient patient) {
    final wounds = patient.currentWounds.isNotEmpty 
        ? patient.currentWounds 
        : patient.baselineWounds;
        
    if (wounds.isEmpty) return null;
    
    // Sort by area (descending) and stage severity
    final sortedWounds = List<Wound>.from(wounds);
    sortedWounds.sort((a, b) {
      // First by stage (higher stages are more problematic)
      final stageComparison = b.stage.index.compareTo(a.stage.index);
      if (stageComparison != 0) return stageComparison;
      
      // Then by area (larger wounds are more problematic)
      return b.area.compareTo(a.area);
    });
    
    return sortedWounds.first;
  }
  
  /// Validates that all wounds in a session are properly assessed
  static bool validateSessionWounds(List<Wound> wounds) {
    if (wounds.isEmpty) return false;
    
    for (final wound in wounds) {
      // Check that all required fields are present and valid
      if (wound.location.isEmpty ||
          wound.length <= 0 ||
          wound.width <= 0 ||
          wound.depth <= 0 ||
          wound.description.isEmpty) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Generates wound naming suggestions based on location
  static List<String> generateWoundNameSuggestions() {
    return [
      'Left ankle',
      'Right ankle',
      'Left heel',
      'Right heel',
      'Left foot',
      'Right foot',
      'Lower back',
      'Upper back',
      'Left shoulder',
      'Right shoulder',
      'Left elbow',
      'Right elbow',
      'Left knee',
      'Right knee',
      'Abdomen',
      'Chest',
      'Left arm',
      'Right arm',
      'Left leg',
      'Right leg',
    ];
  }
  
  /// Gets wound type suggestions
  static List<String> getWoundTypeSuggestions() {
    return [
      'Pressure Ulcer',
      'Diabetic Foot Ulcer',
      'Venous Leg Ulcer',
      'Arterial Ulcer',
      'Surgical Wound',
      'Traumatic Wound',
      'Burns',
      'Other',
    ];
  }
}
