/// Configuration for sales questionnaire when transitioning to Contacted stage
class SalesQuestionnaireConfig {
  /// Default questions for the sales questionnaire
  /// Developers can easily modify this list to add/remove/update questions
  static const List<String> defaultQuestions = [
    'Contact Method',
    'Customer Name',
    // 'Budget Range',
    // 'Timeline/Urgency',
    // 'Decision Maker?',
    // 'Primary Pain Points',
    // 'Current Solution/Provider',
    // 'Key Requirements',
    // 'Next Steps Agreed',
    // 'Follow-up Date',
  ];

  /// Get a copy of the default questions
  static List<String> getDefaultQuestions() {
    return List.from(defaultQuestions);
  }
}
