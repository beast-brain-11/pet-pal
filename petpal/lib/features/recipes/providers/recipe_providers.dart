// Recipe Providers
// Riverpod state management for recipes

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/recipe.dart';
import '../../../core/services/firestore_service.dart';

/// Recipe generation state
enum RecipeGenerationStatus {
  idle,
  gatheringContext,
  searchingPrices,
  checkingAvailability,
  generatingRecipe,
  validating,
  complete,
  error,
}

/// State for the recipe generator
class RecipeGeneratorState {
  final RecipeGenerationStatus status;
  final String? statusMessage;
  final List<Recipe> generatedRecipes;
  final String? error;
  final WebContext? webContext;

  const RecipeGeneratorState({
    this.status = RecipeGenerationStatus.idle,
    this.statusMessage,
    this.generatedRecipes = const [],
    this.error,
    this.webContext,
  });

  bool get isLoading =>
      status != RecipeGenerationStatus.idle &&
      status != RecipeGenerationStatus.complete &&
      status != RecipeGenerationStatus.error;

  RecipeGeneratorState copyWith({
    RecipeGenerationStatus? status,
    String? statusMessage,
    List<Recipe>? generatedRecipes,
    String? error,
    WebContext? webContext,
  }) {
    return RecipeGeneratorState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      generatedRecipes: generatedRecipes ?? this.generatedRecipes,
      error: error,
      webContext: webContext ?? this.webContext,
    );
  }
}

/// Recipe generator notifier
class RecipeGeneratorNotifier extends StateNotifier<RecipeGeneratorState> {
  RecipeGeneratorNotifier() : super(const RecipeGeneratorState());

  void setStatus(RecipeGenerationStatus status, {String? message}) {
    state = state.copyWith(status: status, statusMessage: message);
  }

  void setRecipes(List<Recipe> recipes) {
    state = state.copyWith(
      status: RecipeGenerationStatus.complete,
      generatedRecipes: recipes,
    );
  }

  void setError(String error) {
    state = state.copyWith(status: RecipeGenerationStatus.error, error: error);
  }

  void reset() {
    state = const RecipeGeneratorState();
  }
}

/// State for saved/bookmarked recipes
class SavedRecipesState {
  final List<Recipe> recipes;
  final bool isLoading;

  const SavedRecipesState({this.recipes = const [], this.isLoading = false});

  SavedRecipesState copyWith({List<Recipe>? recipes, bool? isLoading}) {
    return SavedRecipesState(
      recipes: recipes ?? this.recipes,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Saved recipes notifier - now with Firestore persistence
class SavedRecipesNotifier extends StateNotifier<SavedRecipesState> {
  final FirestoreService? _firestoreService;

  SavedRecipesNotifier(this._firestoreService)
    : super(const SavedRecipesState()) {
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    if (_firestoreService == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final recipesData = await _firestoreService!.getSavedRecipesOnce();
      final recipes = recipesData.map((data) => Recipe.fromJson(data)).toList();
      state = state.copyWith(recipes: recipes, isLoading: false);
      print('DEBUG: Loaded ${recipes.length} saved recipes from Firestore');
    } catch (e) {
      print('DEBUG: Error loading recipes: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addRecipe(Recipe recipe) async {
    // Add to local state immediately
    state = state.copyWith(recipes: [...state.recipes, recipe]);

    // Persist to Firestore
    if (_firestoreService != null) {
      try {
        await _firestoreService!.saveRecipe(recipe.toJson());
        print('DEBUG: Recipe saved to Firestore: ${recipe.name}');
      } catch (e) {
        print('DEBUG: Error saving recipe: $e');
      }
    }
  }

  Future<void> removeRecipe(String recipeId) async {
    state = state.copyWith(
      recipes: state.recipes.where((r) => r.id != recipeId).toList(),
    );

    // Remove from Firestore
    if (_firestoreService != null) {
      try {
        await _firestoreService!.deleteRecipe(recipeId);
        print('DEBUG: Recipe deleted from Firestore: $recipeId');
      } catch (e) {
        print('DEBUG: Error deleting recipe: $e');
      }
    }
  }

  bool isRecipeSaved(String recipeId) {
    return state.recipes.any((r) => r.id == recipeId);
  }

  void setRecipes(List<Recipe> recipes) {
    state = state.copyWith(recipes: recipes);
  }

  Future<void> refresh() async {
    await _loadRecipes();
  }
}

/// Currently selected recipe for detail view
class CurrentRecipeNotifier extends StateNotifier<Recipe?> {
  CurrentRecipeNotifier() : super(null);

  void setRecipe(Recipe recipe) {
    state = recipe;
  }

  void clear() {
    state = null;
  }
}

/// Cooking mode state
class CookingModeState {
  final Recipe? recipe;
  final int currentStep;
  final bool isActive;
  final Duration? timerRemaining;
  final bool isPaused;
  final CookingGuidance? currentGuidance;

  const CookingModeState({
    this.recipe,
    this.currentStep = 0,
    this.isActive = false,
    this.timerRemaining,
    this.isPaused = false,
    this.currentGuidance,
  });

  int get totalSteps => recipe?.instructions.length ?? 0;
  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep >= totalSteps - 1;
  double get progress => totalSteps > 0 ? (currentStep + 1) / totalSteps : 0;

  CookingModeState copyWith({
    Recipe? recipe,
    int? currentStep,
    bool? isActive,
    Duration? timerRemaining,
    bool? isPaused,
    CookingGuidance? currentGuidance,
  }) {
    return CookingModeState(
      recipe: recipe ?? this.recipe,
      currentStep: currentStep ?? this.currentStep,
      isActive: isActive ?? this.isActive,
      timerRemaining: timerRemaining ?? this.timerRemaining,
      isPaused: isPaused ?? this.isPaused,
      currentGuidance: currentGuidance ?? this.currentGuidance,
    );
  }
}

/// Cooking mode notifier
class CookingModeNotifier extends StateNotifier<CookingModeState> {
  CookingModeNotifier() : super(const CookingModeState());

  void startCooking(Recipe recipe) {
    state = CookingModeState(recipe: recipe, currentStep: 0, isActive: true);
  }

  void nextStep() {
    if (!state.isLastStep) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (!state.isFirstStep) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step < state.totalSteps) {
      state = state.copyWith(currentStep: step);
    }
  }

  void setGuidance(CookingGuidance guidance) {
    state = state.copyWith(currentGuidance: guidance);
  }

  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  void stopCooking() {
    state = const CookingModeState();
  }
}

/// Recipe filter state
class RecipeFilterState {
  final String? category;
  final String? difficulty;
  final String? budgetRange;
  final int? maxTime;
  final bool aiGeneratedOnly;
  final bool trendingOnly;
  final String? searchQuery;

  const RecipeFilterState({
    this.category,
    this.difficulty,
    this.budgetRange,
    this.maxTime,
    this.aiGeneratedOnly = false,
    this.trendingOnly = false,
    this.searchQuery,
  });

  bool get hasFilters =>
      category != null ||
      difficulty != null ||
      budgetRange != null ||
      maxTime != null ||
      aiGeneratedOnly ||
      trendingOnly ||
      (searchQuery?.isNotEmpty ?? false);

  RecipeFilterState copyWith({
    String? category,
    String? difficulty,
    String? budgetRange,
    int? maxTime,
    bool? aiGeneratedOnly,
    bool? trendingOnly,
    String? searchQuery,
  }) {
    return RecipeFilterState(
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      budgetRange: budgetRange ?? this.budgetRange,
      maxTime: maxTime ?? this.maxTime,
      aiGeneratedOnly: aiGeneratedOnly ?? this.aiGeneratedOnly,
      trendingOnly: trendingOnly ?? this.trendingOnly,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  RecipeFilterState clear() => const RecipeFilterState();
}

/// Recipe filter notifier
class RecipeFilterNotifier extends StateNotifier<RecipeFilterState> {
  RecipeFilterNotifier() : super(const RecipeFilterState());

  void setCategory(String? category) {
    state = state.copyWith(category: category);
  }

  void setDifficulty(String? difficulty) {
    state = state.copyWith(difficulty: difficulty);
  }

  void setBudgetRange(String? range) {
    state = state.copyWith(budgetRange: range);
  }

  void setMaxTime(int? time) {
    state = state.copyWith(maxTime: time);
  }

  void toggleAIOnly() {
    state = state.copyWith(aiGeneratedOnly: !state.aiGeneratedOnly);
  }

  void toggleTrendingOnly() {
    state = state.copyWith(trendingOnly: !state.trendingOnly);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearFilters() {
    state = state.clear();
  }
}

// ============ PROVIDERS ============

/// Recipe generator state provider
final recipeGeneratorProvider =
    StateNotifierProvider<RecipeGeneratorNotifier, RecipeGeneratorState>(
      (ref) => RecipeGeneratorNotifier(),
    );

/// Saved recipes provider - with Firestore persistence
final savedRecipesProvider =
    StateNotifierProvider<SavedRecipesNotifier, SavedRecipesState>((ref) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return SavedRecipesNotifier(firestoreService);
    });

/// Current recipe for detail view
final currentRecipeProvider =
    StateNotifierProvider<CurrentRecipeNotifier, Recipe?>(
      (ref) => CurrentRecipeNotifier(),
    );

/// Cooking mode state provider
final cookingModeProvider =
    StateNotifierProvider<CookingModeNotifier, CookingModeState>(
      (ref) => CookingModeNotifier(),
    );

/// Recipe filter state provider
final recipeFilterProvider =
    StateNotifierProvider<RecipeFilterNotifier, RecipeFilterState>(
      (ref) => RecipeFilterNotifier(),
    );

/// Filtered recipes - combines saved recipes with filters
final filteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final savedState = ref.watch(savedRecipesProvider);
  final filters = ref.watch(recipeFilterProvider);

  var recipes = savedState.recipes;

  if (filters.category != null && filters.category != 'All') {
    recipes = recipes.where((r) => r.category == filters.category).toList();
  }

  if (filters.difficulty != null) {
    recipes = recipes.where((r) => r.difficulty == filters.difficulty).toList();
  }

  if (filters.aiGeneratedOnly) {
    recipes = recipes.where((r) => r.isAIGenerated).toList();
  }

  if (filters.trendingOnly) {
    recipes = recipes.where((r) => r.isTrending).toList();
  }

  if (filters.maxTime != null) {
    recipes = recipes
        .where((r) => r.totalTimeMinutes <= filters.maxTime!)
        .toList();
  }

  if (filters.searchQuery?.isNotEmpty ?? false) {
    final query = filters.searchQuery!.toLowerCase();
    recipes = recipes
        .where(
          (r) =>
              r.name.toLowerCase().contains(query) ||
              r.tags.any((t) => t.toLowerCase().contains(query)),
        )
        .toList();
  }

  return recipes;
});

/// Sample/demo recipes for initial display
final sampleRecipesProvider = Provider<List<Recipe>>((ref) {
  return [
    Recipe(
      id: '1',
      name: 'Chicken & Rice Bowl',
      story:
          'A classic, nutritious meal that dogs love. Perfect for everyday feeding.',
      imageUrl:
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
      category: 'Dinner',
      rating: 4.8,
      timing: RecipeTiming(prepTime: 10, cookTime: 25),
      isAIGenerated: true,
      isTrending: true,
      trendingCount: 156,
      estimatedCostINR: 180,
      difficulty: 'Easy',
      servings: 2,
      tags: ['high-protein', 'grain-included', 'beginner-friendly'],
      nutrition: NutritionInfo(
        calories: 350,
        protein: 28,
        fat: 12,
        carbs: 35,
        fiber: 3,
      ),
      ingredients: [
        RecipeIngredient(
          name: 'Chicken breast',
          quantity: 200,
          unit: 'g',
          estimatedPriceINR: 100,
        ),
        RecipeIngredient(
          name: 'Brown rice',
          quantity: 1,
          unit: 'cup',
          estimatedPriceINR: 30,
        ),
        RecipeIngredient(
          name: 'Carrots',
          quantity: 0.5,
          unit: 'cup',
          estimatedPriceINR: 20,
        ),
        RecipeIngredient(
          name: 'Peas',
          quantity: 0.25,
          unit: 'cup',
          estimatedPriceINR: 15,
        ),
        RecipeIngredient(
          name: 'Chicken broth',
          quantity: 0.5,
          unit: 'cup',
          estimatedPriceINR: 15,
          notes: 'low sodium',
        ),
      ],
      instructions: [
        CookingStep(
          step: 1,
          instruction: 'Cook brown rice according to package instructions.',
          timeMinutes: 20,
        ),
        CookingStep(
          step: 2,
          instruction: 'Dice chicken breast into small, dog-bite sized pieces.',
          timeMinutes: 5,
        ),
        CookingStep(
          step: 3,
          instruction:
              'In a pan, cook chicken until fully done (no pink inside).',
          timeMinutes: 10,
        ),
        CookingStep(
          step: 4,
          instruction: 'Steam carrots and peas until soft.',
          timeMinutes: 8,
        ),
        CookingStep(
          step: 5,
          instruction: 'Mix all ingredients together with chicken broth.',
          timeMinutes: 2,
        ),
        CookingStep(
          step: 6,
          instruction: 'Let cool completely before serving.',
          timeMinutes: 10,
          tips: 'Test temperature on your wrist',
        ),
      ],
    ),
    Recipe(
      id: '2',
      name: 'Beef Stew Supreme',
      story: 'A hearty, protein-rich meal perfect for active dogs.',
      imageUrl:
          'https://images.unsplash.com/photo-1547592180-85f173990554?w=400',
      category: 'Dinner',
      rating: 4.6,
      timing: RecipeTiming(prepTime: 15, cookTime: 45),
      isAIGenerated: false,
      estimatedCostINR: 320,
      difficulty: 'Medium',
      servings: 4,
      tags: ['high-protein', 'slow-cook', 'hearty'],
      nutrition: NutritionInfo(
        calories: 420,
        protein: 35,
        fat: 18,
        carbs: 28,
        fiber: 4,
      ),
      ingredients: [
        RecipeIngredient(
          name: 'Beef chunks',
          quantity: 300,
          unit: 'g',
          estimatedPriceINR: 200,
        ),
        RecipeIngredient(
          name: 'Sweet potato',
          quantity: 1,
          unit: 'medium',
          estimatedPriceINR: 25,
        ),
        RecipeIngredient(
          name: 'Green beans',
          quantity: 0.5,
          unit: 'cup',
          estimatedPriceINR: 20,
        ),
        RecipeIngredient(
          name: 'Beef broth',
          quantity: 1,
          unit: 'cup',
          estimatedPriceINR: 30,
          notes: 'low sodium',
        ),
      ],
      instructions: [
        CookingStep(
          step: 1,
          instruction: 'Cut beef into small cubes.',
          timeMinutes: 10,
        ),
        CookingStep(
          step: 2,
          instruction: 'Brown beef in a pot over medium heat.',
          timeMinutes: 8,
        ),
        CookingStep(
          step: 3,
          instruction: 'Add diced sweet potato and green beans.',
          timeMinutes: 5,
        ),
        CookingStep(
          step: 4,
          instruction: 'Pour in broth and simmer for 30-40 minutes.',
          timeMinutes: 35,
          requiresTimer: true,
        ),
        CookingStep(
          step: 5,
          instruction: 'Let cool before serving.',
          timeMinutes: 15,
        ),
      ],
    ),
    Recipe(
      id: '3',
      name: 'Peanut Butter Treats',
      story:
          'Irresistible homemade treats that are both healthy and delicious!',
      imageUrl:
          'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400',
      category: 'Treats',
      rating: 4.9,
      timing: RecipeTiming(prepTime: 10, cookTime: 15),
      isAIGenerated: true,
      isTrending: true,
      trendingCount: 243,
      estimatedCostINR: 120,
      difficulty: 'Easy',
      servings: 12,
      tags: ['treats', 'no-cook', 'quick'],
      nutrition: NutritionInfo(
        calories: 85,
        protein: 4,
        fat: 6,
        carbs: 5,
        fiber: 1,
      ),
      ingredients: [
        RecipeIngredient(
          name: 'Peanut butter',
          quantity: 1,
          unit: 'cup',
          estimatedPriceINR: 80,
          notes: 'unsweetened, xylitol-free',
        ),
        RecipeIngredient(
          name: 'Oat flour',
          quantity: 1.5,
          unit: 'cups',
          estimatedPriceINR: 25,
        ),
        RecipeIngredient(
          name: 'Honey',
          quantity: 2,
          unit: 'tbsp',
          estimatedPriceINR: 15,
          isOptional: true,
        ),
      ],
      instructions: [
        CookingStep(
          step: 1,
          instruction: 'Mix peanut butter and oat flour in a bowl.',
          timeMinutes: 3,
        ),
        CookingStep(
          step: 2,
          instruction: 'Add honey if using and mix well.',
          timeMinutes: 2,
        ),
        CookingStep(
          step: 3,
          instruction: 'Roll into small balls or use cookie cutters.',
          timeMinutes: 5,
        ),
        CookingStep(
          step: 4,
          instruction: 'Bake at 350°F (175°C) for 12-15 minutes.',
          timeMinutes: 15,
          requiresTimer: true,
        ),
        CookingStep(
          step: 5,
          instruction: 'Cool completely before serving.',
          timeMinutes: 10,
        ),
      ],
    ),
    Recipe(
      id: '4',
      name: 'Morning Oatmeal Delight',
      story: 'A warm, comforting breakfast to start your pup\'s day right.',
      imageUrl:
          'https://images.unsplash.com/photo-1517673400267-0251440c45dc?w=400',
      category: 'Breakfast',
      rating: 4.5,
      timing: RecipeTiming(prepTime: 5, cookTime: 10),
      isAIGenerated: false,
      estimatedCostINR: 80,
      difficulty: 'Easy',
      servings: 1,
      tags: ['breakfast', 'quick', 'fiber-rich'],
      nutrition: NutritionInfo(
        calories: 220,
        protein: 8,
        fat: 5,
        carbs: 38,
        fiber: 6,
      ),
      ingredients: [
        RecipeIngredient(
          name: 'Rolled oats',
          quantity: 0.5,
          unit: 'cup',
          estimatedPriceINR: 15,
        ),
        RecipeIngredient(
          name: 'Water',
          quantity: 1,
          unit: 'cup',
          estimatedPriceINR: 0,
        ),
        RecipeIngredient(
          name: 'Banana',
          quantity: 0.5,
          unit: 'medium',
          estimatedPriceINR: 10,
        ),
        RecipeIngredient(
          name: 'Blueberries',
          quantity: 2,
          unit: 'tbsp',
          estimatedPriceINR: 40,
          isOptional: true,
        ),
        RecipeIngredient(
          name: 'Plain yogurt',
          quantity: 2,
          unit: 'tbsp',
          estimatedPriceINR: 15,
        ),
      ],
      instructions: [
        CookingStep(
          step: 1,
          instruction: 'Cook oats in water until soft.',
          timeMinutes: 8,
        ),
        CookingStep(
          step: 2,
          instruction: 'Mash banana and mix into oatmeal.',
          timeMinutes: 2,
        ),
        CookingStep(
          step: 3,
          instruction: 'Top with blueberries and yogurt.',
          timeMinutes: 1,
        ),
        CookingStep(
          step: 4,
          instruction: 'Let cool to room temperature before serving.',
          timeMinutes: 5,
        ),
      ],
    ),
  ];
});
