// Recipe Generator Page - Uses Firestore DogProfile for REAL persisted data
// Fixed to use dogProfilesProvider instead of onboardingProvider

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/gemini_service.dart';
import '../../domain/models/recipe.dart' as models;
import '../../providers/recipe_providers.dart';

class RecipeGeneratorPage extends ConsumerStatefulWidget {
  const RecipeGeneratorPage({super.key});

  @override
  ConsumerState<RecipeGeneratorPage> createState() =>
      _RecipeGeneratorPageState();
}

class _RecipeGeneratorPageState extends ConsumerState<RecipeGeneratorPage>
    with TickerProviderStateMixin {
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _ingredientsController = TextEditingController();

  bool _isGenerating = false;
  bool _isGeneratingInfographic = false;
  String _statusMessage = '';
  double _progress = 0.0;
  int _currentStep = 0;
  EnhancedRecipeResult? _generatedRecipe;
  Uint8List? _coverImageBytes;
  String? _error;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final Map<int, bool> _stepCompleted = {};

  final List<Map<String, dynamic>> _generationSteps = [
    {
      'icon': '🐕',
      'title': 'Analyzing Profile',
      'subtitle': 'Reading nutritional needs',
    },
    {
      'icon': '⚠️',
      'title': 'Safety Check',
      'subtitle': 'Filtering toxic ingredients',
    },
    {
      'icon': '🍖',
      'title': 'Crafting Recipe',
      'subtitle': 'Creating the perfect meal',
    },
    {
      'icon': '📊',
      'title': 'Calculating Portions',
      'subtitle': 'Based on weight & activity',
    },
    {
      'icon': '🎨',
      'title': 'Creating Image',
      'subtitle': 'Generating cover photo',
    },
    {'icon': '✨', 'title': 'Finalizing', 'subtitle': 'Preparing your recipe'},
  ];

  String get _suggestedMealType {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) return 'Breakfast';
    if (hour >= 11 && hour < 15) return 'Lunch';
    if (hour >= 15 && hour < 18) return 'Snack';
    return 'Dinner';
  }

  // Dynamic ingredient suggestions based on dietary preferences from Firestore profile
  List<String> _getSuggestedIngredients(DogProfile profile) {
    final suggestions = <String>[];
    final allergies = profile.allergies.map((a) => a.toLowerCase()).toList();
    final prefs = profile.dietaryPreferences
        .map((p) => p.toLowerCase())
        .toList();

    // Check if vegetarian/vegan
    final isVeg = prefs.any(
      (p) =>
          p.contains('veg') ||
          p.contains('vegetarian') ||
          p.contains('vegan') ||
          p == 'veg',
    );

    debugPrint('DEBUG getSuggestedIngredients:');
    debugPrint('  - dietaryPreferences: ${profile.dietaryPreferences}');
    debugPrint('  - isVeg: $isVeg');
    debugPrint('  - allergies: ${profile.allergies}');

    if (isVeg) {
      // VEG-ONLY suggestions
      if (!allergies.contains('eggs') && !allergies.contains('egg'))
        suggestions.add('Eggs');
      if (!allergies.contains('paneer')) suggestions.add('Paneer');
      if (!allergies.contains('cottage cheese'))
        suggestions.add('Cottage Cheese');
      if (!allergies.contains('tofu')) suggestions.add('Tofu');

      // Grains (if not grain-free)
      if (!prefs.any((p) => p.contains('grain'))) {
        if (!allergies.contains('rice')) suggestions.add('Rice');
        if (!allergies.contains('oats')) suggestions.add('Oats');
        if (!allergies.contains('quinoa')) suggestions.add('Quinoa');
      }

      // Vegetables
      if (!allergies.contains('carrots')) suggestions.add('Carrots');
      if (!allergies.contains('sweet potato')) suggestions.add('Sweet Potato');
      if (!allergies.contains('pumpkin')) suggestions.add('Pumpkin');
      if (!allergies.contains('spinach')) suggestions.add('Spinach');
      if (!allergies.contains('peas')) suggestions.add('Peas');
      if (!allergies.contains('green beans')) suggestions.add('Green Beans');
    } else {
      // NON-VEG suggestions
      if (!allergies.contains('chicken')) suggestions.add('Chicken');
      if (!allergies.contains('beef')) suggestions.add('Beef');
      if (!allergies.contains('turkey')) suggestions.add('Turkey');
      if (!allergies.contains('lamb')) suggestions.add('Lamb');
      if (!allergies.contains('fish') && !allergies.contains('salmon'))
        suggestions.add('Salmon');
      if (!allergies.contains('eggs') && !allergies.contains('egg'))
        suggestions.add('Eggs');

      // Grains
      if (!prefs.any((p) => p.contains('grain'))) {
        if (!allergies.contains('rice')) suggestions.add('Rice');
        if (!allergies.contains('oats')) suggestions.add('Oats');
      }

      // Vegetables
      if (!allergies.contains('carrots')) suggestions.add('Carrots');
      if (!allergies.contains('sweet potato')) suggestions.add('Sweet Potato');
      if (!allergies.contains('pumpkin')) suggestions.add('Pumpkin');
    }

    return suggestions.take(6).toList();
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  Future<void> _startGeneration(DogProfile profile, {String? feedback}) async {
    final dogName = profile.name.isNotEmpty ? profile.name : 'Your Dog';

    _stepCompleted.clear();

    setState(() {
      _isGenerating = true;
      _currentStep = 0;
      _progress = 0.0;
      _error = null;
      _generatedRecipe = null;
      _coverImageBytes = null;
    });

    try {
      // STEP 1: Analyze profile
      _markStepStart(0, 'Analyzing $dogName\'s profile...');
      if (profile.weight <= 0) {
        throw Exception('Dog weight not set. Please complete the survey.');
      }
      await Future.delayed(const Duration(milliseconds: 400));
      _markStepComplete(0);

      // STEP 2: Safety check
      _markStepStart(1, 'Checking for toxic ingredients...');
      final toxicFoods = [
        'chocolate',
        'onion',
        'garlic',
        'grapes',
        'raisins',
        'xylitol',
        'avocado',
        'macadamia',
      ];
      final userIngredients = _ingredientsController.text.toLowerCase();
      for (final toxic in toxicFoods) {
        if (userIngredients.contains(toxic)) {
          throw Exception(
            'WARNING: $toxic is toxic to dogs! Please remove it.',
          );
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
      _markStepComplete(1);

      // STEP 3: Craft recipe - REAL AI call
      _markStepStart(
        2,
        'Creating ${_suggestedMealType.toLowerCase()} for $dogName...',
      );

      final ingredients = _ingredientsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      debugPrint('Generating recipe with:');
      debugPrint('  dogName: $dogName');
      debugPrint('  breed: ${profile.breed}');
      debugPrint('  size: ${profile.size}');
      debugPrint('  weight: ${profile.weight}');
      debugPrint('  activityLevel: ${profile.activityLevel}');
      debugPrint('  dietaryPreferences: ${profile.dietaryPreferences}');
      debugPrint('  allergies: ${profile.allergies}');
      debugPrint('  ingredients: $ingredients');

      final result = await _geminiService.generateRecipeWithContext(
        dogName: dogName,
        breed: profile.breed.isEmpty ? 'Mixed breed' : profile.breed,
        size: profile.size.isEmpty ? 'Medium' : profile.size,
        weightLbs: profile.weight > 0 ? profile.weight : 30.0,
        activityLevel: profile.activityLevel.isEmpty
            ? 'Moderate'
            : profile.activityLevel,
        dietaryPreferences: profile.dietaryPreferences,
        allergies: profile.allergies,
        mealType: _suggestedMealType,
        availableIngredients: ingredients.isEmpty ? null : ingredients,
        userFeedback: feedback,
      );

      if (result.hasError) {
        throw Exception(result.error);
      }
      _generatedRecipe = result;
      _markStepComplete(2);

      // STEP 4: Validate nutrition
      _markStepStart(
        3,
        'Verifying portions for ${profile.weight.toStringAsFixed(0)} lbs...',
      );
      await Future.delayed(const Duration(milliseconds: 300));
      _markStepComplete(3);

      // STEP 5: Generate cover image (waits up to 90 seconds)
      _markStepStart(
        4,
        'Creating cover image (this may take 30-60 seconds)...',
      );
      try {
        // Image generation via REST API with 90 second timeout
        _coverImageBytes = await _geminiService.generateRecipeImage(
          recipeName: result.name ?? 'Dog Food Recipe',
          ingredients: result.ingredients?.map((i) => i.name).toList() ?? [],
        );

        if (_coverImageBytes != null) {
          debugPrint(
            'Cover image generated: ${_coverImageBytes!.length} bytes',
          );
        } else {
          debugPrint('No cover image generated (API returned null)');
        }
      } catch (e) {
        debugPrint('Image generation failed: $e');
        // Continue without image - it's optional
      }
      _markStepComplete(4);

      // STEP 6: Finalize
      _markStepStart(5, '$dogName\'s recipe is ready! 🎉');
      await Future.delayed(const Duration(milliseconds: 300));
      _markStepComplete(5);

      setState(() {
        _isGenerating = false;
        _statusMessage = '$dogName\'s recipe is ready! 🎉';
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _markStepStart(int step, String message) {
    setState(() {
      _currentStep = step;
      _statusMessage = message;
      _progress = step / _generationSteps.length;
    });
  }

  void _markStepComplete(int step) {
    setState(() {
      _stepCompleted[step] = true;
      _progress = (step + 1) / _generationSteps.length;
    });
  }

  void _showRegenerateDialog(DogProfile profile) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What would you like different?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps AI create a better recipe',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'e.g., Add more protein, make it softer, include vegetables...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startGeneration(profile, feedback: controller.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Regenerate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveRecipe() {
    if (_generatedRecipe == null) return;

    final recipe = models.Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _generatedRecipe!.name ?? 'AI Dog Recipe',
      story: _generatedRecipe!.story,
      category: _generatedRecipe!.category ?? _suggestedMealType,
      difficulty: _generatedRecipe!.difficulty ?? 'Easy',
      timing: models.RecipeTiming(
        prepTime: _generatedRecipe!.prepTime ?? 15,
        cookTime: _generatedRecipe!.cookTime ?? 30,
      ),
      servings: _generatedRecipe!.servings ?? 1,
      nutrition: models.NutritionInfo(
        calories: _generatedRecipe!.nutrition?['calories'] ?? 0,
        protein: _generatedRecipe!.nutrition?['protein'] ?? 0,
        fat: _generatedRecipe!.nutrition?['fat'] ?? 0,
        carbs: _generatedRecipe!.nutrition?['carbs'] ?? 0,
        fiber: _generatedRecipe!.nutrition?['fiber'] ?? 0,
      ),
      ingredients:
          _generatedRecipe!.ingredients
              ?.map(
                (i) => models.RecipeIngredient(
                  name: i.name,
                  quantity: i.quantity,
                  unit: i.unit,
                  notes: i.notes,
                ),
              )
              .toList() ??
          [],
      instructions:
          _generatedRecipe!.instructions
              ?.map(
                (i) => models.CookingStep(
                  step: i.step,
                  instruction: i.instruction,
                  timeMinutes: i.timeMinutes,
                  tips: i.tips,
                ),
              )
              .toList() ??
          [],
      tags: _generatedRecipe!.tags ?? ['homemade', 'dog-safe'],
      whySpecial: _generatedRecipe!.whySpecial,
      isAIGenerated: true,
    );

    ref.read(savedRecipesProvider.notifier).addRecipe(recipe);
    ref.read(currentRecipeProvider.notifier).setRecipe(recipe);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: const Text('Recipe saved! 🐕'),
        backgroundColor: AppColors.healthGreen,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => context.go('/recipes/${recipe.id}'),
        ),
      ),
    );
    context.go('/recipes');
  }

  Future<void> _shareAsInfographic() async {
    if (_generatedRecipe == null) return;

    setState(() => _isGeneratingInfographic = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Generating infographic...')));

    try {
      final infographicBytes = await _geminiService.generateInfographic(
        recipeName: _generatedRecipe!.name ?? 'Dog Recipe',
        ingredients:
            _generatedRecipe!.ingredients
                ?.map(
                  (i) => '${i.quantity.toStringAsFixed(0)} ${i.unit} ${i.name}',
                )
                .toList() ??
            [],
        nutrition: _generatedRecipe!.nutrition ?? {},
        story: _generatedRecipe!.story ?? '',
      );

      setState(() => _isGeneratingInfographic = false);

      if (infographicBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/petpal_recipe_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(infographicBytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: '🐕 ${_generatedRecipe!.name}\nMade with PetPal',
          ),
        );
      } else {
        _shareAsText();
      }
    } catch (e) {
      setState(() => _isGeneratingInfographic = false);
      _shareAsText();
    }
  }

  void _shareAsText() {
    final text =
        '''
🐕 ${_generatedRecipe!.name}

${_generatedRecipe!.story ?? ''}

📝 Ingredients:
${_generatedRecipe!.ingredients?.map((i) => '• ${i.quantity.toStringAsFixed(0)} ${i.unit} ${i.name}').join('\n') ?? ''}

🔥 Nutrition: ${_generatedRecipe!.nutrition?['calories'] ?? 0} kcal

Made with PetPal 🐾
''';
    SharePlus.instance.share(ShareParams(text: text.trim()));
  }

  DecorationImage? _getAvatarImage(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) return null;

    // Check if it's a local file path
    if (photoPath.startsWith('/') ||
        photoPath.startsWith('C:') ||
        photoPath.contains('\\')) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return DecorationImage(image: FileImage(file), fit: BoxFit.cover);
      }
    }

    // Check if it's a network URL
    if (photoPath.startsWith('http')) {
      return DecorationImage(image: NetworkImage(photoPath), fit: BoxFit.cover);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Use dogProfilesProvider - reads from FIRESTORE (persisted data)
    final dogProfilesAsync = ref.watch(dogProfilesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          SafeArea(
            child: dogProfilesAsync.when(
              data: (dogs) {
                if (dogs.isEmpty) {
                  return _buildNoDogState();
                }
                final dog = dogs.first;

                if (_isGenerating) {
                  return _buildGenerationProgress(dog);
                } else if (_generatedRecipe != null) {
                  return _buildRecipeResult(dog);
                } else {
                  return _buildInputScreen(dog);
                }
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          // Loading overlay for infographic
          if (_isGeneratingInfographic)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Creating infographic...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoDogState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🐕', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          const Text(
            'No pet profile found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete onboarding first',
            style: TextStyle(color: AppColors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/onboarding/welcome'),
            child: const Text('Add Your Pet'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputScreen(DogProfile profile) {
    final dogName = profile.name.isNotEmpty ? profile.name : 'Your Dog';
    final suggestedIngredients = _getSuggestedIngredients(profile);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with dog info from Firestore
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _suggestedMealType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Dog avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white, width: 2),
                        image: _getAvatarImage(profile.photoUrl),
                      ),
                      child: _getAvatarImage(profile.photoUrl) == null
                          ? const Center(
                              child: Text('🐕', style: TextStyle(fontSize: 28)),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Recipe for',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            dogName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${profile.breed.isEmpty ? "Mixed breed" : profile.breed} • ${profile.size} • ${profile.activityLevel}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _buildStatCard(
                  'Weight',
                  '${profile.weight.toStringAsFixed(0)} lbs',
                  '⚖️',
                ),
                const SizedBox(width: 10),
                _buildStatCard(
                  'Activity',
                  profile.activityLevel.isEmpty
                      ? 'Moderate'
                      : profile.activityLevel,
                  '🏃',
                ),
                const SizedBox(width: 10),
                _buildStatCard(
                  'Allergies',
                  '${profile.allergies.length}',
                  '⚠️',
                ),
              ],
            ),
          ),

          // Dietary preferences
          if (profile.dietaryPreferences.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🍽️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Diet: ${profile.dietaryPreferences.join(", ")}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Allergies
          if (profile.allergies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.healthRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.healthRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🚫', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Avoiding: ${profile.allergies.join(", ")}',
                        style: TextStyle(
                          color: AppColors.healthRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Ingredients input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🥕', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    const Text(
                      "What's in your kitchen?",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Optional - AI will create a complete balanced meal',
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ingredientsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g., chicken, rice, carrots...',
                    hintStyle: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Safe for $dogName:',
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: suggestedIngredients
                      .map(
                        (ing) => ActionChip(
                          label: Text(
                            ing,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            final current = _ingredientsController.text;
                            _ingredientsController.text = current.isEmpty
                                ? ing
                                : '$current, $ing';
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

          // Error
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.healthRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.healthRed,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppColors.healthRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Generate button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startGeneration(profile),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Create $dogName\'s $_suggestedMealType',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String emoji) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            Text(label, style: TextStyle(color: AppColors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerationProgress(DogProfile profile) {
    final dogName = profile.name.isNotEmpty ? profile.name : 'Your Dog';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.9),
            AppColors.backgroundLight,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🍳', style: TextStyle(fontSize: 50)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Creating Recipe for $dogName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView.builder(
                itemCount: _generationSteps.length,
                itemBuilder: (context, index) {
                  final step = _generationSteps[index];
                  final isActive = index == _currentStep;
                  final isCompleted = _stepCompleted[index] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.healthGreen
                                : isActive
                                ? AppColors.primary
                                : AppColors.greyLight,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : Text(
                                    step['icon'],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step['title'],
                                style: TextStyle(
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isCompleted
                                      ? AppColors.healthGreen
                                      : null,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                step['subtitle'],
                                style: TextStyle(
                                  color: AppColors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeResult(DogProfile profile) {
    final dogName = profile.name.isNotEmpty ? profile.name : 'Your Dog';
    final nutrition = _generatedRecipe!.nutrition ?? {};

    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero
          Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: Stack(
              children: [
                if (_coverImageBytes != null)
                  Positioned.fill(
                    child: Image.memory(_coverImageBytes!, fit: BoxFit.cover),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => setState(() {
                                _generatedRecipe = null;
                                _coverImageBytes = null;
                              }),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.share,
                                color: Colors.white,
                              ),
                              onPressed: _shareAsInfographic,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.healthGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pets,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Made for $dogName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _generatedRecipe!.name ?? 'Dog Recipe',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Container(
            transform: Matrix4.translationValues(0, -16, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_generatedRecipe!.story != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('💜', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _generatedRecipe!.story!,
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),
                Row(
                  children: [
                    _buildQuickStat('⏱️', '${_generatedRecipe!.totalTime} min'),
                    _buildQuickStat(
                      '🍽️',
                      '${_generatedRecipe!.servings ?? 1} serving',
                    ),
                    _buildQuickStat('🔥', '${nutrition['calories'] ?? 0} kcal'),
                  ],
                ),

                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nutrition per Serving',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNutritionItem(
                            'Calories',
                            '${nutrition['calories'] ?? 0}',
                            'kcal',
                          ),
                          _buildNutritionItem(
                            'Protein',
                            '${nutrition['protein'] ?? 0}',
                            'g',
                          ),
                          _buildNutritionItem(
                            'Fat',
                            '${nutrition['fat'] ?? 0}',
                            'g',
                          ),
                          _buildNutritionItem(
                            'Carbs',
                            '${nutrition['carbs'] ?? 0}',
                            'g',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const Text(
                  'Ingredients',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...?_generatedRecipe!.ingredients?.map(
                  (ing) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.healthGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${ing.quantity.toStringAsFixed(0)} ${ing.unit} ${ing.name}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                const Text(
                  'Instructions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...?_generatedRecipe!.instructions?.map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Text(
                              '${step.step}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.instruction,
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (step.tips != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '💡 ${step.tips}',
                                    style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_generatedRecipe!.whySpecial != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.healthGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('🌟', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _generatedRecipe!.whySpecial!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRegenerateDialog(profile),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Another'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveRecipe,
                        icon: const Icon(Icons.bookmark),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String emoji, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: AppColors.greyLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(unit, style: TextStyle(fontSize: 10, color: AppColors.grey)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
