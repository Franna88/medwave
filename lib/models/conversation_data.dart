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
  practitionerDetails,
  // Wound-specific steps
  woundHistoryAndType,
  woundOccurrence, 
  comorbidities,
  currentInfection,
  testsPerformed,
  woundDetailsClassification,
  timesAssessment,
  currentTreatment,
  treatmentDates,
  additionalNotes,
  // Weight management specific steps
  weightHistoryAndGoals,
  metabolicAssessment,
  dietaryAndExerciseAssessment,
  weightTreatmentPlan,
  // Pain management specific steps
  painHistoryAndType,
  painLocationAndIntensity,
  painMedicationAndTreatments,
  functionalImpactAssessment,
  painTreatmentPlan,
  completed,
}

extension ConversationStepExtension on ConversationStep {
  String get displayName {
    switch (this) {
      case ConversationStep.greeting:
        return 'Greeting';
      case ConversationStep.practitionerName:
        return 'Practitioner Name';
      case ConversationStep.practitionerDetails:
        return 'Practitioner Details';
      // Wound-specific steps
      case ConversationStep.woundHistoryAndType:
        return 'Wound History & Type';
      case ConversationStep.woundOccurrence:
        return 'How Wound Occurred';
      case ConversationStep.comorbidities:
        return 'Comorbidities';
      case ConversationStep.currentInfection:
        return 'Current Infection Status';
      case ConversationStep.testsPerformed:
        return 'Tests Performed';
      case ConversationStep.woundDetailsClassification:
        return 'Wound Details & Classification';
      case ConversationStep.timesAssessment:
        return 'TIMES Assessment';
      case ConversationStep.currentTreatment:
        return 'Current Treatment';
      case ConversationStep.treatmentDates:
        return 'Treatment Dates';
      case ConversationStep.additionalNotes:
        return 'Additional Information';
      // Weight management steps
      case ConversationStep.weightHistoryAndGoals:
        return 'Weight History & Goals';
      case ConversationStep.metabolicAssessment:
        return 'Metabolic Assessment';
      case ConversationStep.dietaryAndExerciseAssessment:
        return 'Dietary & Exercise Assessment';
      case ConversationStep.weightTreatmentPlan:
        return 'Weight Treatment Plan';
      // Pain management steps
      case ConversationStep.painHistoryAndType:
        return 'Pain History & Type';
      case ConversationStep.painLocationAndIntensity:
        return 'Pain Location & Intensity';
      case ConversationStep.painMedicationAndTreatments:
        return 'Pain Medication & Treatments';
      case ConversationStep.functionalImpactAssessment:
        return 'Functional Impact Assessment';
      case ConversationStep.painTreatmentPlan:
        return 'Pain Treatment Plan';
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
  final String? practitionerPracticeNumber;
  final String? practitionerContactDetails;
  final String? woundTypeAndHistory;
  final String? woundOccurrenceDescription;
  final List<String> sessionComorbidities;
  final String? infectionStatus;
  final List<String> testsPerformed;
  final WoundDetails? woundDetails;
  final TreatmentDetails? treatmentDetails;
  final List<String> treatmentDates;
  final String? additionalNotes;
  
  // Historical information (from patient file)
  final String? woundHistory;
  final String? woundOccurrence;
  final List<String> patientComorbidities;

  // Appointment information (from calendar)
  final List<DateTime>? upcomingAppointmentDates;
  final String appointmentSummary;

  // Pain-specific fields
  final int? currentVasScore;
  final List<String>? painLocations;
  final String? painType;
  final String? painMedicationPlan;

  // Weight-specific fields
  final double? currentWeight;
  final double? targetWeight;
  final double? weightChange;
  final String? dietaryPlan;
  final String? exercisePlan;

  const ExtractedClinicalData({
    required this.patientName,
    required this.medicalAid,
    required this.membershipNumber,
    required this.referringDoctor,
    required this.practitionerName,
    this.practitionerPracticeNumber,
    this.practitionerContactDetails,
    this.woundTypeAndHistory,
    this.woundOccurrenceDescription,
    this.sessionComorbidities = const [],
    this.infectionStatus,
    this.testsPerformed = const [],
    this.woundDetails,
    this.treatmentDetails,
    this.treatmentDates = const [],
    this.additionalNotes,
    this.woundHistory,
    this.woundOccurrence,
    this.patientComorbidities = const [],
    // Appointment fields
    this.upcomingAppointmentDates,
    this.appointmentSummary = 'No upcoming appointments scheduled',
    // Pain fields
    this.currentVasScore,
    this.painLocations,
    this.painType,
    this.painMedicationPlan,
    // Weight fields
    this.currentWeight,
    this.targetWeight,
    this.weightChange,
    this.dietaryPlan,
    this.exercisePlan,
  });

  Map<String, dynamic> toMap() {
    return {
      'patientName': patientName,
      'medicalAid': medicalAid,
      'membershipNumber': membershipNumber,
      'referringDoctor': referringDoctor,
      'practitionerName': practitionerName,
      'practitionerPracticeNumber': practitionerPracticeNumber,
      'practitionerContactDetails': practitionerContactDetails,
      'woundTypeAndHistory': woundTypeAndHistory,
      'woundOccurrenceDescription': woundOccurrenceDescription,
      'sessionComorbidities': sessionComorbidities,
      'infectionStatus': infectionStatus,
      'testsPerformed': testsPerformed,
      'woundDetails': woundDetails?.toMap(),
      'treatmentDetails': treatmentDetails?.toMap(),
      'treatmentDates': treatmentDates,
      'additionalNotes': additionalNotes,
      'woundHistory': woundHistory,
      'woundOccurrence': woundOccurrence,
      'patientComorbidities': patientComorbidities,
      'upcomingAppointmentDates': upcomingAppointmentDates?.map((d) => d.toIso8601String()).toList(),
      'appointmentSummary': appointmentSummary,
      'currentVasScore': currentVasScore,
      'painLocations': painLocations,
      'painType': painType,
      'painMedicationPlan': painMedicationPlan,
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'weightChange': weightChange,
      'dietaryPlan': dietaryPlan,
      'exercisePlan': exercisePlan,
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
