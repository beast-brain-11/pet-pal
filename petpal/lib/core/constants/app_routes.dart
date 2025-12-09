// App Route Definitions

class AppRoutes {
  AppRoutes._();

  // Auth Routes
  static const String splash = '/';
  static const String signIn = '/signin';
  static const String signUp = '/signup';
  static const String forgotPassword = '/forgot-password';

  // Onboarding Survey Routes
  static const String surveyWelcome = '/survey/welcome';
  static const String surveyPhoto = '/survey/photo';
  static const String surveyBreed = '/survey/breed';
  static const String surveySize = '/survey/size';
  static const String surveyDietary = '/survey/dietary';
  static const String surveyReview = '/survey/review';
  static const String surveyVaccination = '/survey/vaccination';
  static const String surveyMedical = '/survey/medical';
  static const String surveyVetInsurance = '/survey/vet-insurance';
  static const String surveyDocuments = '/survey/documents';
  static const String surveyComplete = '/survey/complete';

  // Main App Routes
  static const String home = '/home';
  static const String profile = '/profile';

  // Recipe Routes
  static const String recipes = '/recipes';
  static const String recipeDetail = '/recipes/:id';
  static const String recipeGenerator = '/recipes/generate';
  static const String recipeSearch = '/recipes/search';
  static const String cookingMode = '/recipes/:id/cooking';
  static const String mealPlanner = '/meal-planner';

  // Health Routes
  static const String aiHealth = '/ai-health';

  // Other Routes
  static const String location = '/location';
  static const String shop = '/shop';
}
