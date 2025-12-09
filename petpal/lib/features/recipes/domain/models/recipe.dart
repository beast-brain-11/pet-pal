// Recipe Domain Models
// Comprehensive models for the PetPal Recipe System v2.0

/// Represents a complete recipe with all details
class Recipe {
  final String id;
  final String name;
  final String? story;
  final String? imageUrl;
  final String category; // Breakfast, Lunch, Dinner, Treats, Snack
  final List<RecipeIngredient> ingredients;
  final List<CookingStep> instructions;
  final NutritionInfo nutrition;
  final RecipeTiming timing;
  final int servings;
  final String difficulty; // Easy, Medium, Hard
  final double? estimatedCostINR;
  final List<String> tags;
  final String? seasonality;
  final String? whySpecial;
  final String? dogReaction;
  final bool isAIGenerated;
  final bool isTrending;
  final int? trendingCount;
  final double rating;
  final DateTime createdAt;
  final WebContext? webContext;

  Recipe({
    required this.id,
    required this.name,
    this.story,
    this.imageUrl,
    this.category = 'Dinner',
    this.ingredients = const [],
    this.instructions = const [],
    required this.nutrition,
    required this.timing,
    this.servings = 2,
    this.difficulty = 'Easy',
    this.estimatedCostINR,
    this.tags = const [],
    this.seasonality,
    this.whySpecial,
    this.dogReaction,
    this.isAIGenerated = false,
    this.isTrending = false,
    this.trendingCount,
    this.rating = 0.0,
    DateTime? createdAt,
    this.webContext,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalTimeMinutes => timing.prepTime + timing.cookTime;
  String get totalTimeDisplay => '$totalTimeMinutes min';
  String get costDisplay => estimatedCostINR != null
      ? '₹${estimatedCostINR!.toStringAsFixed(0)}'
      : '';

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? json['title'] ?? 'Unnamed Recipe',
      story: json['story'] ?? json['description'],
      imageUrl: json['imageUrl'] ?? json['image'],
      category: json['category'] ?? 'Dinner',
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      instructions:
          (json['instructions'] as List<dynamic>?)?.map((e) {
            if (e is String) {
              return CookingStep(step: 1, instruction: e, timeMinutes: 5);
            }
            return CookingStep.fromJson(e as Map<String, dynamic>);
          }).toList() ??
          [],
      nutrition: json['nutrition'] != null
          ? NutritionInfo.fromJson(json['nutrition'] as Map<String, dynamic>)
          : NutritionInfo.empty(),
      timing: RecipeTiming(
        prepTime: json['prepTime'] ?? json['timing']?['prepTime'] ?? 15,
        cookTime: json['cookTime'] ?? json['timing']?['cookTime'] ?? 30,
      ),
      servings: json['servings'] ?? 2,
      difficulty: json['difficulty'] ?? 'Easy',
      estimatedCostINR: (json['totalCostINR'] ?? json['estimatedCostINR'])
          ?.toDouble(),
      tags: List<String>.from(json['tags'] ?? []),
      seasonality: json['seasonality'],
      whySpecial: json['whySpecial'],
      dogReaction: json['dogReactions'] ?? json['dogReaction'],
      isAIGenerated: json['isAI'] ?? json['isAIGenerated'] ?? true,
      isTrending: json['isTrending'] ?? false,
      trendingCount: json['trendingCount'],
      rating: (json['rating'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'story': story,
    'imageUrl': imageUrl,
    'category': category,
    'ingredients': ingredients.map((e) => e.toJson()).toList(),
    'instructions': instructions.map((e) => e.toJson()).toList(),
    'nutrition': nutrition.toJson(),
    'timing': timing.toJson(),
    'servings': servings,
    'difficulty': difficulty,
    'estimatedCostINR': estimatedCostINR,
    'tags': tags,
    'seasonality': seasonality,
    'whySpecial': whySpecial,
    'dogReaction': dogReaction,
    'isAIGenerated': isAIGenerated,
    'isTrending': isTrending,
    'trendingCount': trendingCount,
    'rating': rating,
    'createdAt': createdAt.toIso8601String(),
  };

  Recipe copyWith({
    String? id,
    String? name,
    String? story,
    String? imageUrl,
    String? category,
    List<RecipeIngredient>? ingredients,
    List<CookingStep>? instructions,
    NutritionInfo? nutrition,
    RecipeTiming? timing,
    int? servings,
    String? difficulty,
    double? estimatedCostINR,
    List<String>? tags,
    String? seasonality,
    String? whySpecial,
    String? dogReaction,
    bool? isAIGenerated,
    bool? isTrending,
    int? trendingCount,
    double? rating,
    WebContext? webContext,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      story: story ?? this.story,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      nutrition: nutrition ?? this.nutrition,
      timing: timing ?? this.timing,
      servings: servings ?? this.servings,
      difficulty: difficulty ?? this.difficulty,
      estimatedCostINR: estimatedCostINR ?? this.estimatedCostINR,
      tags: tags ?? this.tags,
      seasonality: seasonality ?? this.seasonality,
      whySpecial: whySpecial ?? this.whySpecial,
      dogReaction: dogReaction ?? this.dogReaction,
      isAIGenerated: isAIGenerated ?? this.isAIGenerated,
      isTrending: isTrending ?? this.isTrending,
      trendingCount: trendingCount ?? this.trendingCount,
      rating: rating ?? this.rating,
      createdAt: createdAt,
      webContext: webContext ?? this.webContext,
    );
  }
}

/// Recipe ingredient with availability and substitutes
class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;
  final double? estimatedPriceINR;
  final String availability; // high, medium, low
  final List<String> substitutes;
  final bool isOptional;
  final String? notes;
  final String? safetyWarning;

  RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.estimatedPriceINR,
    this.availability = 'high',
    this.substitutes = const [],
    this.isOptional = false,
    this.notes,
    this.safetyWarning,
  });

  String get displayAmount => '$quantity $unit';

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 1).toDouble(),
      unit: json['unit'] ?? json['amount'] ?? '',
      estimatedPriceINR:
          json['estimated_price_inr']?.toDouble() ??
          json['estimatedPriceINR']?.toDouble(),
      availability: json['availability'] ?? 'high',
      substitutes: List<String>.from(json['substitutes'] ?? []),
      isOptional: json['optional'] ?? json['isOptional'] ?? false,
      notes: json['notes'],
      safetyWarning: json['safetyWarning'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'estimatedPriceINR': estimatedPriceINR,
    'availability': availability,
    'substitutes': substitutes,
    'isOptional': isOptional,
    'notes': notes,
    'safetyWarning': safetyWarning,
  };
}

/// Cooking instruction step with timing and tips
class CookingStep {
  final int step;
  final String instruction;
  final int timeMinutes;
  final String? tips;
  final String? visualCue;
  final bool requiresTimer;

  CookingStep({
    required this.step,
    required this.instruction,
    this.timeMinutes = 5,
    this.tips,
    this.visualCue,
    this.requiresTimer = false,
  });

  factory CookingStep.fromJson(Map<String, dynamic> json) {
    return CookingStep(
      step: json['step'] ?? 1,
      instruction: json['instruction'] ?? '',
      timeMinutes: json['timeMinutes'] ?? 5,
      tips: json['tips'],
      visualCue: json['visualCue'],
      requiresTimer: json['requiresTimer'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'step': step,
    'instruction': instruction,
    'timeMinutes': timeMinutes,
    'tips': tips,
    'visualCue': visualCue,
    'requiresTimer': requiresTimer,
  };
}

/// Comprehensive nutrition information
class NutritionInfo {
  final int calories;
  final int protein;
  final int fat;
  final int carbs;
  final int fiber;
  final Map<String, int>? vitamins;
  final Map<String, int>? minerals;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.fiber = 0,
    this.vitamins,
    this.minerals,
  });

  factory NutritionInfo.empty() =>
      NutritionInfo(calories: 0, protein: 0, fat: 0, carbs: 0);

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: json['calories'] ?? 0,
      protein: json['protein'] ?? 0,
      fat: json['fat'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fiber: json['fiber'] ?? 0,
      vitamins: json['vitamins'] != null
          ? Map<String, int>.from(
              json['vitamins'].map((k, v) => MapEntry(k, v as int)),
            )
          : null,
      minerals: json['minerals'] != null
          ? Map<String, int>.from(
              json['minerals'].map((k, v) => MapEntry(k, v as int)),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'fat': fat,
    'carbs': carbs,
    'fiber': fiber,
    'vitamins': vitamins,
    'minerals': minerals,
  };
}

/// Recipe preparation and cooking times
class RecipeTiming {
  final int prepTime;
  final int cookTime;

  RecipeTiming({required this.prepTime, required this.cookTime});

  int get totalTime => prepTime + cookTime;

  factory RecipeTiming.fromJson(Map<String, dynamic> json) {
    return RecipeTiming(
      prepTime: json['prepTime'] ?? 15,
      cookTime: json['cookTime'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {'prepTime': prepTime, 'cookTime': cookTime};
}

/// Web context for real-time data
class WebContext {
  final Map<String, double>? ingredientPrices;
  final List<String>? seasonalIngredients;
  final List<String>? safetyAlerts;
  final String? nutritionStandards;
  final List<String>? trendingRecipes;
  final DateTime timestamp;

  WebContext({
    this.ingredientPrices,
    this.seasonalIngredients,
    this.safetyAlerts,
    this.nutritionStandards,
    this.trendingRecipes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebContext.fromJson(Map<String, dynamic> json) {
    return WebContext(
      ingredientPrices: json['ingredient_prices'] != null
          ? Map<String, double>.from(
              json['ingredient_prices'].map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ),
            )
          : null,
      seasonalIngredients: json['seasonal_ingredients'] != null
          ? List<String>.from(json['seasonal_ingredients'])
          : null,
      safetyAlerts: json['safety_alerts'] != null
          ? List<String>.from(json['safety_alerts'])
          : null,
      nutritionStandards: json['nutrition_standards'],
      trendingRecipes: json['trending_recipes'] != null
          ? List<String>.from(json['trending_recipes'])
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ingredient_prices': ingredientPrices,
    'seasonal_ingredients': seasonalIngredients,
    'safety_alerts': safetyAlerts,
    'nutrition_standards': nutritionStandards,
    'trending_recipes': trendingRecipes,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Nutrition analysis result from AI
class NutritionAnalysis {
  final bool aafcoCompliant;
  final String? complianceExplanation;
  final List<String> missingNutrients;
  final Map<String, MedicalImpact>? medicalImpacts;
  final List<MedicationInteraction>? medicationInteractions;
  final int overallHealthScore;
  final String recommendation;
  final List<String>? monitoringRequirements;
  final List<String>? suggestedModifications;
  final int confidenceLevel;

  NutritionAnalysis({
    this.aafcoCompliant = false,
    this.complianceExplanation,
    this.missingNutrients = const [],
    this.medicalImpacts,
    this.medicationInteractions,
    this.overallHealthScore = 0,
    this.recommendation = 'Not Analyzed',
    this.monitoringRequirements,
    this.suggestedModifications,
    this.confidenceLevel = 0,
  });

  factory NutritionAnalysis.fromJson(Map<String, dynamic> json) {
    return NutritionAnalysis(
      aafcoCompliant: json['aafco_compliance']?['compliant'] ?? false,
      complianceExplanation: json['aafco_compliance']?['explanation'],
      missingNutrients: List<String>.from(
        json['aafco_compliance']?['missing_nutrients'] ?? [],
      ),
      overallHealthScore: json['overall_health_score'] ?? 0,
      recommendation: json['recommendation'] ?? 'Not Analyzed',
      monitoringRequirements: json['monitoring_requirements'] != null
          ? List<String>.from(json['monitoring_requirements'])
          : null,
      suggestedModifications: json['suggested_modifications'] != null
          ? List<String>.from(json['suggested_modifications'])
          : null,
      confidenceLevel: json['confidence_level'] ?? 0,
    );
  }
}

class MedicalImpact {
  final String benefit;
  final String risk;
  final String? researchReference;
  final String recommendation;

  MedicalImpact({
    required this.benefit,
    required this.risk,
    this.researchReference,
    required this.recommendation,
  });
}

class MedicationInteraction {
  final String medication;
  final String interaction;
  final String severity;
  final String mitigation;

  MedicationInteraction({
    required this.medication,
    required this.interaction,
    required this.severity,
    required this.mitigation,
  });
}

/// Cooking guidance from AI
class CookingGuidance {
  final String immediateGuidance;
  final String? visualCues;
  final String? timingEstimate;
  final List<String> expertTips;
  final List<String> mistakesToAvoid;
  final String? nextMilestone;
  final String? safetyAlert;

  CookingGuidance({
    required this.immediateGuidance,
    this.visualCues,
    this.timingEstimate,
    this.expertTips = const [],
    this.mistakesToAvoid = const [],
    this.nextMilestone,
    this.safetyAlert,
  });

  factory CookingGuidance.fromJson(Map<String, dynamic> json) {
    return CookingGuidance(
      immediateGuidance: json['immediate_guidance'] ?? '',
      visualCues: json['visual_cues'],
      timingEstimate: json['timing_estimate'],
      expertTips: List<String>.from(json['expert_tips'] ?? []),
      mistakesToAvoid: List<String>.from(json['mistakes_to_avoid'] ?? []),
      nextMilestone: json['next_milestone'],
      safetyAlert: json['safety_alert'],
    );
  }
}

/// Meal plan for a week
class MealPlan {
  final String id;
  final Map<String, DailyMeals> dailyMeals;
  final ShoppingList shoppingList;
  final double totalWeeklyBudget;
  final int varietyScore;
  final String? prepSchedule;
  final String? nutritionalSummary;
  final DateTime createdAt;

  MealPlan({
    required this.id,
    required this.dailyMeals,
    required this.shoppingList,
    this.totalWeeklyBudget = 0,
    this.varietyScore = 0,
    this.prepSchedule,
    this.nutritionalSummary,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class DailyMeals {
  final String? breakfast;
  final String? lunch;
  final String? dinner;
  final String? snack;

  DailyMeals({this.breakfast, this.lunch, this.dinner, this.snack});
}

class ShoppingList {
  final List<ShoppingItem> items;
  final double estimatedTotalINR;
  final String? bestShoppingDay;

  ShoppingList({
    this.items = const [],
    this.estimatedTotalINR = 0,
    this.bestShoppingDay,
  });
}

class ShoppingItem {
  final String name;
  final String quantity;
  final double? priceINR;
  final String availability;
  final String category;

  ShoppingItem({
    required this.name,
    required this.quantity,
    this.priceINR,
    this.availability = 'high',
    this.category = 'other',
  });
}
