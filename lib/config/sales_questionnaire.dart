/// Configuration for sales questionnaire when transitioning to Contacted stage
class SalesQuestionnaireConfig {
  /// Default questions for the sales questionnaire - Appointment Setter Questions
  static const List<String> defaultQuestions = [
    'What line of Business are you in?',
    'Do you have a website? Can you share the link.',
    'How many clients do you see a week currently?',
    'Have you experienced a Medwave session before?',
  ];

  /// Get a copy of the default questions
  static List<String> getDefaultQuestions() {
    return List.from(defaultQuestions);
  }
}
