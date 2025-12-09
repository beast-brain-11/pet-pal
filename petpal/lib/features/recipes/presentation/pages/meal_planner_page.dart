// Meal Planner Page - Weekly meal planning with shopping list
// PetPal Recipe System v2.0

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/recipe.dart';
import '../../providers/recipe_providers.dart';

// Meal plan state for a week
class MealPlanState {
  final Map<String, Map<String, Recipe?>>
  weekPlan; // day -> {breakfast, lunch, dinner, snack}
  final DateTime weekStartDate;

  MealPlanState({
    Map<String, Map<String, Recipe?>>? weekPlan,
    DateTime? weekStartDate,
  }) : weekPlan = weekPlan ?? _initializeWeek(),
       weekStartDate = weekStartDate ?? _getMonday(DateTime.now());

  static DateTime _getMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static Map<String, Map<String, Recipe?>> _initializeWeek() {
    return {
      'Monday': {
        'Breakfast': null,
        'Lunch': null,
        'Dinner': null,
        'Snack': null,
      },
      'Tuesday': {
        'Breakfast': null,
        'Lunch': null,
        'Dinner': null,
        'Snack': null,
      },
      'Wednesday': {
        'Breakfast': null,
        'Lunch': null,
        'Dinner': null,
        'Snack': null,
      },
      'Thursday': {
        'Breakfast': null,
        'Lunch': null,
        'Dinner': null,
        'Snack': null,
      },
      'Friday': {
        'Breakfast': null,
        'Lunch': null,
        'Dinner': null,
        'Snack': null,
      },
      'Saturday': {
        'Breakfast': null,
        'Lunch': null,
        'Dinner': null,
        'Snack': null,
      },
      'Sunday': {
        'Breakfast': null,
        'Lunch': null,
        'Dinner': null,
        'Snack': null,
      },
    };
  }

  MealPlanState copyWith({
    Map<String, Map<String, Recipe?>>? weekPlan,
    DateTime? weekStartDate,
  }) {
    return MealPlanState(
      weekPlan: weekPlan ?? this.weekPlan,
      weekStartDate: weekStartDate ?? this.weekStartDate,
    );
  }

  List<RecipeIngredient> get shoppingList {
    final allIngredients = <RecipeIngredient>[];
    for (var day in weekPlan.values) {
      for (var recipe in day.values) {
        if (recipe != null) {
          allIngredients.addAll(recipe.ingredients);
        }
      }
    }
    // Combine duplicate ingredients
    final combined = <String, RecipeIngredient>{};
    for (var ing in allIngredients) {
      if (combined.containsKey(ing.name)) {
        final existing = combined[ing.name]!;
        combined[ing.name] = RecipeIngredient(
          name: ing.name,
          quantity: existing.quantity + ing.quantity,
          unit: ing.unit,
          estimatedPriceINR:
              (existing.estimatedPriceINR ?? 0) + (ing.estimatedPriceINR ?? 0),
        );
      } else {
        combined[ing.name] = ing;
      }
    }
    return combined.values.toList();
  }

  double get totalCost {
    double total = 0;
    for (var day in weekPlan.values) {
      for (var recipe in day.values) {
        if (recipe != null) {
          total += recipe.estimatedCostINR ?? 0;
        }
      }
    }
    return total;
  }

  int get recipesPlanned {
    int count = 0;
    for (var day in weekPlan.values) {
      for (var recipe in day.values) {
        if (recipe != null) count++;
      }
    }
    return count;
  }
}

class MealPlanNotifier extends StateNotifier<MealPlanState> {
  MealPlanNotifier() : super(MealPlanState());

  void addRecipe(String day, String mealType, Recipe recipe) {
    final newPlan = Map<String, Map<String, Recipe?>>.from(state.weekPlan);
    newPlan[day] = Map<String, Recipe?>.from(newPlan[day] ?? {});
    newPlan[day]![mealType] = recipe;
    state = state.copyWith(weekPlan: newPlan);
  }

  void removeRecipe(String day, String mealType) {
    final newPlan = Map<String, Map<String, Recipe?>>.from(state.weekPlan);
    newPlan[day] = Map<String, Recipe?>.from(newPlan[day] ?? {});
    newPlan[day]![mealType] = null;
    state = state.copyWith(weekPlan: newPlan);
  }

  void clearWeek() {
    state = MealPlanState();
  }
}

final mealPlanProvider = StateNotifierProvider<MealPlanNotifier, MealPlanState>(
  (ref) => MealPlanNotifier(),
);

class MealPlannerPage extends ConsumerStatefulWidget {
  const MealPlannerPage({super.key});

  @override
  ConsumerState<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends ConsumerState<MealPlannerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mealPlan = ref.watch(mealPlanProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Meal Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(mealPlanProvider.notifier).clearWeek();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Week plan cleared')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today), text: 'Weekly Plan'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Shopping List'),
          ],
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWeeklyPlanTab(mealPlan),
          _buildShoppingListTab(mealPlan),
        ],
      ),
    );
  }

  Widget _buildWeeklyPlanTab(MealPlanState mealPlan) {
    return Column(
      children: [
        // Week summary
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                '🍽️',
                '${mealPlan.recipesPlanned}',
                'Meals Planned',
              ),
              _buildSummaryItem(
                '💰',
                '₹${mealPlan.totalCost.toStringAsFixed(0)}',
                'Est. Weekly Cost',
              ),
              _buildSummaryItem(
                '🛒',
                '${mealPlan.shoppingList.length}',
                'Items to Buy',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Days
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _days.length,
            itemBuilder: (context, index) {
              final day = _days[index];
              final dayPlan = mealPlan.weekPlan[day] ?? {};
              return _buildDayCard(day, dayPlan);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.grey)),
      ],
    );
  }

  Widget _buildDayCard(String day, Map<String, Recipe?> dayPlan) {
    final isToday = _isToday(day);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isToday
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.greyLight.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isToday ? AppColors.primary : AppColors.black,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Meals
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: _mealTypes.map((mealType) {
                final recipe = dayPlan[mealType];
                return _buildMealSlot(day, mealType, recipe);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealSlot(String day, String mealType, Recipe? recipe) {
    final mealEmoji = {
      'Breakfast': '🌅',
      'Lunch': '☀️',
      'Dinner': '🌙',
      'Snack': '🍪',
    };

    return GestureDetector(
      onTap: () => _showRecipeSelector(day, mealType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: recipe != null
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.greyLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: recipe != null
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(
              mealEmoji[mealType] ?? '🍽️',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealType,
                    style: TextStyle(fontSize: 12, color: AppColors.grey),
                  ),
                  Text(
                    recipe?.name ?? 'Tap to add recipe',
                    style: TextStyle(
                      fontWeight: recipe != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: recipe != null ? AppColors.black : AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (recipe != null) ...[
              if (recipe.estimatedCostINR != null)
                Text(
                  '₹${recipe.estimatedCostINR!.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppColors.healthGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ref
                      .read(mealPlanProvider.notifier)
                      .removeRecipe(day, mealType);
                },
                child: Icon(Icons.close, size: 18, color: AppColors.grey),
              ),
            ] else
              Icon(Icons.add_circle_outline, color: AppColors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showRecipeSelector(String day, String mealType) {
    final sampleRecipes = ref.read(sampleRecipesProvider);
    final savedRecipes = ref.read(savedRecipesProvider).recipes;
    final allRecipes = [...sampleRecipes, ...savedRecipes];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select $mealType for $day',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: allRecipes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🍳', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          const Text('No recipes yet'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push('/recipes/generate');
                            },
                            child: const Text('Generate a Recipe'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: allRecipes.length,
                      itemBuilder: (context, index) {
                        final recipe = allRecipes[index];
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.greyLight,
                              borderRadius: BorderRadius.circular(8),
                              image: recipe.imageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(recipe.imageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: recipe.imageUrl == null
                                ? const Icon(Icons.restaurant)
                                : null,
                          ),
                          title: Text(recipe.name),
                          subtitle: Text(
                            '${recipe.totalTimeDisplay} • ${recipe.costDisplay}',
                          ),
                          trailing: recipe.isAIGenerated
                              ? const Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.primary,
                                  size: 18,
                                )
                              : null,
                          onTap: () {
                            ref
                                .read(mealPlanProvider.notifier)
                                .addRecipe(day, mealType, recipe);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShoppingListTab(MealPlanState mealPlan) {
    final shoppingList = mealPlan.shoppingList;
    final totalCost = shoppingList.fold<double>(
      0,
      (sum, item) => sum + (item.estimatedPriceINR ?? 0),
    );

    if (shoppingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'No items yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add recipes to your meal plan',
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Total cost header
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.healthGreen.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated Total',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${totalCost.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.healthGreen,
                ),
              ),
            ],
          ),
        ),
        // Shopping list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shoppingList.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = shoppingList[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_box_outline_blank,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                title: Text(item.name),
                subtitle: Text('${item.quantity} ${item.unit}'),
                trailing: item.estimatedPriceINR != null
                    ? Text(
                        '₹${item.estimatedPriceINR!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.healthGreen,
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isToday(String day) {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final today = DateTime.now().weekday - 1;
    return weekdays[today] == day;
  }
}
