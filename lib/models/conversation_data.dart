// Conversation data models for AI report generation

/// Represents a message in the AI conversation
class AIMessage {
  final String content;
  final bool isBot;
  final DateTime timestamp;

  const AIMessage({
    required this.content,
    required this.isBot,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'isBot': isBot,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory AIMessage.fromMap(Map<String, dynamic> map) {
    return AIMessage(
      content: map['content'] ?? '',
      isBot: map['isBot'] ?? false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }
}

/// Conversation steps for AI report generation
enum ConversationStep {
  greeting,
  practitionerName,
  currentInfection,
  testsPerformed,
  timesAssessment,
  currentTreatment,
  additionalNotes,
  completed,
}

extension ConversationStepExtension on ConversationStep {
  String get displayName {
    switch (this) {
      case ConversationStep.greeting:
        return 'Greeting';
      case ConversationStep.practitionerName:
        return 'Practitioner Information';
      case ConversationStep.currentInfection:
        return 'Current Infection Status';
      case ConversationStep.testsPerformed:
        return 'Tests Performed';
      case ConversationStep.timesAssessment:
        return 'TIMES Assessment';
      case ConversationStep.currentTreatment:
        return 'Current Treatment';
      case ConversationStep.additionalNotes:
        return 'Additional Information';
      case ConversationStep.completed:
        return 'Report Generation';
    }
  }
}

/// Clinical data extracted from the conversation
class ExtractedClinicalData {
  // Basic information (from patient file)
  final String patientName;
  final String medicalAid;
  final String membershipNumber;
  final String referringDoctor;
  
  // Session-specific information (from AI conversation)
  final String practitionerName;
  final String? infectionStatus;
  final List<String> testsPerformed;
  final WoundDetails? woundDetails;
  final TreatmentDetails? treatmentDetails;
  final String? additionalNotes;
  
  // Historical information (from patient file)
  final String? woundHistory;
  final String? woundOccurrence;
  final List<String> comorbidities;

  const ExtractedClinicalData({
    required this.patientName,
    required this.medicalAid,
    required this.membershipNumber,
    required this.referringDoctor,
    required this.practitionerName,
    this.infectionStatus,
    this.testsPerformed = const [],
    this.woundDetails,
    this.treatmentDetails,
    this.additionalNotes,
    this.woundHistory,
    this.woundOccurrence,
    this.comorbidities = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'patientName': patientName,
      'medicalAid': medicalAid,
      'membershipNumber': membershipNumber,
      'referringDoctor': referringDoctor,
      'practitionerName': practitionerName,
      'infectionStatus': infectionStatus,
      'testsPerformed': testsPerformed,
      'woundDetails': woundDetails?.toMap(),
      'treatmentDetails': treatmentDetails?.toMap(),
      'additionalNotes': additionalNotes,
      'woundHistory': woundHistory,
      'woundOccurrence': woundOccurrence,
      'comorbidities': comorbidities,
    };
  }
}

/// Wound assessment details for current session
class WoundDetails {
  final String type;
  final String size;
  final String location;
  final TimesAssessment? timesAssessment;

  const WoundDetails({
    required this.type,
    required this.size,
    required this.location,
    this.timesAssessment,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'size': size,
      'location': location,
      'timesAssessment': timesAssessment?.toMap(),
    };
  }
}

/// TIMES assessment for wound evaluation
class TimesAssessment {
  final String tissue;
  final String inflammation;
  final String moisture;
  final String edges;
  final String surrounding;

  const TimesAssessment({
    required this.tissue,
    required this.inflammation,
    required this.moisture,
    required this.edges,
    required this.surrounding,
  });

  Map<String, dynamic> toMap() {
    return {
      'tissue': tissue,
      'inflammation': inflammation,
      'moisture': moisture,
      'edges': edges,
      'surrounding': surrounding,
    };
  }
}

/// Treatment details for current session
class TreatmentDetails {
  final String cleansing;
  final String skinProtectant;
  final List<String> plannedTreatments;
  final String? additionalTreatments;

  const TreatmentDetails({
    required this.cleansing,
    required this.skinProtectant,
    required this.plannedTreatments,
    this.additionalTreatments,
  });

  Map<String, dynamic> toMap() {
    return {
      'cleansing': cleansing,
      'skinProtectant': skinProtectant,
      'plannedTreatments': plannedTreatments,
      'additionalTreatments': additionalTreatments,
    };
  }
}
