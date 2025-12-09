// GoRouter Configuration

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_routes.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/signin_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/onboarding/presentation/pages/survey_welcome_page.dart';
import '../../features/onboarding/presentation/pages/survey_photo_page.dart';
import '../../features/onboarding/presentation/pages/survey_breed_page.dart';
import '../../features/onboarding/presentation/pages/survey_size_page.dart';
import '../../features/onboarding/presentation/pages/survey_dietary_page.dart';
import '../../features/onboarding/presentation/pages/survey_review_page.dart';
import '../../features/onboarding/presentation/pages/survey_vaccination_page.dart';
import '../../features/onboarding/presentation/pages/survey_medical_page.dart';
import '../../features/onboarding/presentation/pages/survey_vet_insurance_page.dart';
import '../../features/onboarding/presentation/pages/survey_documents_page.dart';
import '../../features/onboarding/presentation/pages/survey_complete_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/recipes/presentation/pages/recipes_page.dart';
import '../../features/recipes/presentation/pages/recipe_detail_page.dart';
import '../../features/recipes/presentation/pages/recipe_generator_page.dart';
import '../../features/recipes/presentation/pages/cooking_mode_page.dart';
import '../../features/recipes/presentation/pages/meal_planner_page.dart';
import '../../features/health/presentation/pages/ai_health_page.dart';

// Router Provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      // Auth Routes
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: 'signIn',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'signUp',
        builder: (context, state) => const SignUpPage(),
      ),

      // Onboarding Survey Routes
      GoRoute(
        path: AppRoutes.surveyWelcome,
        name: 'surveyWelcome',
        builder: (context, state) => const SurveyWelcomePage(),
      ),
      GoRoute(
        path: AppRoutes.surveyPhoto,
        name: 'surveyPhoto',
        builder: (context, state) => const SurveyPhotoPage(),
      ),
      GoRoute(
        path: AppRoutes.surveyBreed,
        name: 'surveyBreed',
        builder: (context, state) => const SurveyBreedPage(),
      ),
      GoRoute(
        path: AppRoutes.surveySize,
        name: 'surveySize',
        builder: (context, state) => const SurveySizePage(),
      ),
      GoRoute(
        path: AppRoutes.surveyDietary,
        name: 'surveyDietary',
        builder: (context, state) => const SurveyDietaryPage(),
      ),
      GoRoute(
        path: AppRoutes.surveyReview,
        name: 'surveyReview',
        builder: (context, state) => const SurveyReviewPage(),
      ),
      GoRoute(
        path: AppRoutes.surveyVaccination,
        name: 'surveyVaccination',
        builder: (context, state) => const SurveyVaccinationPage(),
      ),
      GoRoute(
        path: AppRoutes.surveyMedical,
        name: 'surveyMedical',
        builder: (context, state) => const SurveyMedicalPage(),
      ),
      GoRoute(
        path: AppRoutes.surveyVetInsurance,
        name: 'surveyVetInsurance',
        builder: (context, state) => const SurveyVetInsurancePage(),
      ),
      GoRoute(
        path: AppRoutes.surveyDocuments,
        name: 'surveyDocuments',
        builder: (context, state) => const SurveyDocumentsPage(),
      ),
      GoRoute(
        path: AppRoutes.surveyComplete,
        name: 'surveyComplete',
        builder: (context, state) => const SurveyCompletePage(),
      ),

      // Main App Routes with Bottom Navigation Shell
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.recipes,
            name: 'recipes',
            builder: (context, state) => const RecipesPage(),
          ),
          GoRoute(
            path: AppRoutes.aiHealth,
            name: 'aiHealth',
            builder: (context, state) => const AIHealthPage(),
          ),
        ],
      ),

      // Recipe Generator - MUST be before /recipes/:id to avoid matching "generate" as id
      GoRoute(
        path: AppRoutes.recipeGenerator,
        name: 'recipeGenerator',
        builder: (context, state) => const RecipeGeneratorPage(),
      ),

      // Meal Planner
      GoRoute(
        path: '/meal-planner',
        name: 'mealPlanner',
        builder: (context, state) => const MealPlannerPage(),
      ),

      // Recipe Detail (outside shell for full screen) - parameterized route AFTER specific routes
      GoRoute(
        path: '/recipes/:id',
        name: 'recipeDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecipeDetailPage(recipeId: id);
        },
      ),

      // Cooking Mode (full screen immersive)
      GoRoute(
        path: '/recipes/:id/cooking',
        name: 'cookingMode',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CookingModePage(recipeId: id);
        },
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
});

// Main Shell with Bottom Navigation
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child, bottomNavigationBar: const MainBottomNav());
  }
}

// Bottom Navigation Bar
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key});

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.home)) return 0;
    if (location.startsWith(AppRoutes.recipes)) return 1;
    if (location.startsWith(AppRoutes.aiHealth)) return 2;
    if (location.startsWith(AppRoutes.location)) return 3;
    if (location.startsWith(AppRoutes.shop)) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.recipes);
        break;
      case 2:
        context.go(AppRoutes.aiHealth);
        break;
      case 3:
        // Location - placeholder for now
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location coming soon!')));
        break;
      case 4:
        // Shop - placeholder for now
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Shop coming soon!')));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _getCurrentIndex(context),
      onTap: (index) => _onTap(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.restaurant_menu_outlined),
          activeIcon: Icon(Icons.restaurant_menu),
          label: 'Recipes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.health_and_safety_outlined),
          activeIcon: Icon(Icons.health_and_safety),
          label: 'Health',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on_outlined),
          activeIcon: Icon(Icons.location_on),
          label: 'Location',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag_outlined),
          activeIcon: Icon(Icons.shopping_bag),
          label: 'Shop',
        ),
      ],
    );
  }
}
