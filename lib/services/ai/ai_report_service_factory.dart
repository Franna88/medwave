import '../../models/patient.dart';
import 'openai_service.dart';
import 'pain_management_ai_service.dart';
import 'weight_management_ai_service.dart';

/// Factory class for creating the appropriate AI service based on patient type
class AIReportServiceFactory {
  /// Get the appropriate AI service for a patient based on their treatment type
  static dynamic getServiceForPatient(Patient patient) {
    switch (patient.treatmentType) {
      case TreatmentType.wound:
        return OpenAIService();
      case TreatmentType.pain:
        return PainManagementAIService();
      case TreatmentType.weight:
        return WeightManagementAIService();
    }
  }

  /// Get the report type name for display purposes
  static String getReportTypeName(Patient patient) {
    switch (patient.treatmentType) {
      case TreatmentType.wound:
        return 'Wound Care';
      case TreatmentType.pain:
        return 'Pain Management';
      case TreatmentType.weight:
        return 'Weight Management';
    }
  }

  /// Get a description of what the report will include
  static String getReportDescription(Patient patient) {
    switch (patient.treatmentType) {
      case TreatmentType.wound:
        return 'This report will include wound assessment (TIMES), treatment details, and wound-specific ICD-10 codes for medical aid authorization.';
      case TreatmentType.pain:
        return 'This report will include pain assessment (VAS scores), functional impact, pain management interventions, and pain-specific ICD-10 codes for medical aid authorization.';
      case TreatmentType.weight:
        return 'This report will include weight measurements, BMI, metabolic assessment, dietary/exercise plans, and obesity/metabolic ICD-10 codes for medical aid authorization.';
    }
  }

  /// Validate that the service can generate a report for this patient
  static bool canGenerateReport(Patient patient) {
    // All patient types can now generate reports
    return true;
  }

  /// Get validation message if report cannot be generated
  static String? getValidationMessage(Patient patient) {
    // Currently all patient types are supported
    return null;
  }
}

