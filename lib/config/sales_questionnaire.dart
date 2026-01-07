/// Configuration for sales questionnaire when transitioning to Contacted stage
class SalesQuestionnaireConfig {
  /// Default questions for the sales questionnaire - Appointment Setter Questions
  static const List<String> defaultQuestions = [
    'What line of Business are you in?',
    'Do you have a website? Can you share the link.',
    'How many clients do you see a week currently?',
    'Have you experienced a Medwave session before?',
  ];

  /// Lead qualification questions - BANT (Budget, Authority, Need, Timeline)
  static const List<String> qualificationQuestions = [
    'What is your budget range for this solution?',
    'Are you the decision maker, or who else is involved in the decision?',
    'What is your timeline for implementing a solution?',
    'What challenges are you currently facing that prompted this inquiry?',
  ];

  /// Rapport-building checklist items for sales agents
  static const List<String> rapportChecklistItems = [
    'Greeted the lead warmly and introduced myself',
    'Built rapport with small talk / found common ground',
    'Used active listening and repeated key points back',
    'Addressed the lead by name throughout the call',
    'Showed genuine interest in their business/situation',
  ];

  /// Get a copy of the default questions
  static List<String> getDefaultQuestions() {
    return List.from(defaultQuestions);
  }

  /// Get a copy of the qualification questions
  static List<String> getQualificationQuestions() {
    return List.from(qualificationQuestions);
  }

  /// Get all questions combined (default + qualification)
  static List<String> getAllQuestions() {
    return [...defaultQuestions, ...qualificationQuestions];
  }

  /// Get a copy of the rapport checklist items
  static List<String> getRapportChecklistItems() {
    return List.from(rapportChecklistItems);
  }
}
