// Survey Dietary Page (Survey 5) - Dietary preferences and allergies
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/onboarding_provider.dart';

class SurveyDietaryPage extends ConsumerStatefulWidget {
  const SurveyDietaryPage({super.key});

  @override
  ConsumerState<SurveyDietaryPage> createState() => _SurveyDietaryPageState();
}

class _SurveyDietaryPageState extends ConsumerState<SurveyDietaryPage> {
  String? _selectedDietType;
  List<String> _selectedPreferences = [];
  List<String> _selectedAllergies = [];

  // Diet types for pet food
  final _dietTypes = [
    {
      'name': 'Non-Vegetarian',
      'icon': Icons.restaurant,
      'desc': 'Includes meat & fish',
    },
    {'name': 'Vegetarian', 'icon': Icons.eco, 'desc': 'Plant-based only'},
    {'name': 'Eggetarian', 'icon': Icons.egg_alt, 'desc': 'Veg + Eggs'},
    {'name': 'Mixed', 'icon': Icons.dinner_dining, 'desc': 'All food types'},
  ];

  final _preferences = [
    'Grain-Free',
    'High-Protein',
    'Low-Fat',
    'Raw Food',
    'Organic',
    'Home-Cooked',
    'Limited Ingredient',
    'Senior Formula',
  ];

  final _allergies = [
    'Chicken',
    'Beef',
    'Dairy',
    'Wheat',
    'Soy',
    'Eggs',
    'Fish',
    'Corn',
    'Pork',
    'Lamb',
  ];

  @override
  void initState() {
    super.initState();
    final data = ref.read(onboardingProvider);
    _selectedPreferences = List.from(data.dietaryPreferences);
    _selectedAllergies = List.from(data.allergies);
    // Extract diet type from preferences if already set
    for (var diet in _dietTypes) {
      if (_selectedPreferences.contains(diet['name'])) {
        _selectedDietType = diet['name'] as String;
        _selectedPreferences.remove(diet['name']);
        break;
      }
    }
  }

  void _continue() {
    // Add diet type to preferences if selected
    final prefs = List<String>.from(_selectedPreferences);
    if (_selectedDietType != null) {
      prefs.insert(0, _selectedDietType!);
    }
    ref.read(onboardingProvider.notifier).updateDietaryPreferences(prefs);
    ref.read(onboardingProvider.notifier).updateAllergies(_selectedAllergies);
    context.go(AppRoutes.surveyReview);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: screenHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4043F2), Color(0xFF6467F2)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.surveySize),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '5/11',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),

                const SizedBox(height: 24),

                const Center(
                  child: Text(
                    "Dietary Preferences",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    "This helps us recommend the best recipes",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // Diet Type Section
                const Text(
                  'Diet Type',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the primary diet type for your pet',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),

                // Diet Type Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: _dietTypes.length,
                  itemBuilder: (context, index) {
                    final diet = _dietTypes[index];
                    final isSelected = _selectedDietType == diet['name'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDietType = diet['name'] as String;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              diet['icon'] as IconData,
                              color: isSelected
                                  ? const Color(0xFF4043F2)
                                  : Colors.white,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              diet['name'] as String,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF4043F2)
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              diet['desc'] as String,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(
                                        0xFF4043F2,
                                      ).withValues(alpha: 0.7)
                                    : Colors.white.withValues(alpha: 0.7),
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Additional Preferences
                const Text(
                  'Additional Preferences',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select any that apply (optional)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _preferences.map((pref) {
                    final isSelected = _selectedPreferences.contains(pref);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPreferences.remove(pref);
                          } else {
                            _selectedPreferences.add(pref);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: isSelected ? 1.0 : 0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          pref,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF4043F2)
                                : Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // Allergies
                const Text(
                  'Allergies & Sensitivities',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select any foods your dog should avoid',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _allergies.map((allergy) {
                    final isSelected = _selectedAllergies.contains(allergy);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedAllergies.remove(allergy);
                          } else {
                            _selectedAllergies.add(allergy);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.red.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.red
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(
                                Icons.warning_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              allergy,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 40),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4043F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Skip option
                Center(
                  child: TextButton(
                    onPressed: _continue,
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
