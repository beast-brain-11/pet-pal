// Survey Breed Page (Survey 2) - Breed confirmation and age selection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/onboarding_provider.dart';

class SurveyBreedPage extends ConsumerStatefulWidget {
  const SurveyBreedPage({super.key});

  @override
  ConsumerState<SurveyBreedPage> createState() => _SurveyBreedPageState();
}

class _SurveyBreedPageState extends ConsumerState<SurveyBreedPage> {
  String _selectedAgeGroup = 'adult';
  final _ageGroups = [
    {'id': 'puppy', 'label': 'Puppy', 'range': '0-1 year'},
    {'id': 'adult', 'label': 'Adult', 'range': '1-7 years'},
    {'id': 'senior', 'label': 'Senior', 'range': '7+ years'},
  ];

  @override
  void initState() {
    super.initState();
    final data = ref.read(onboardingProvider);
    _selectedAgeGroup = data.ageGroup;
  }

  void _continue() {
    final onboarding = ref.read(onboardingProvider);

    // Validate that breed is set
    if (onboarding.breed.isEmpty) {
      _showValidationError('Please enter or confirm your dog\'s breed');
      return;
    }

    ref.read(onboardingProvider.notifier).updateAge(_selectedAgeGroup);
    context.go(AppRoutes.surveySize);
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final onboarding = ref.watch(onboardingProvider);

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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.surveyPhoto),
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
                      '3/11',
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

                Text(
                  "Confirm ${onboarding.name.isEmpty ? 'Your Dog' : onboarding.name}'s Details",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // Detected Breed Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.pets, color: Colors.white, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        onboarding.breed.isEmpty
                            ? 'Unknown Breed'
                            : onboarding.breed,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (onboarding.breedConfidence > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${(onboarding.breedConfidence * 100).toInt()}% confidence',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showBreedSearch(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Change Breed',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Age Group Selection
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Age Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: _ageGroups.map((group) {
                    final isSelected = _selectedAgeGroup == group['id'];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedAgeGroup = group['id']!),
                        child: Container(
                          margin: EdgeInsets.only(
                            right: group['id'] != 'senior' ? 12 : 0,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                            children: [
                              Text(
                                group['label']!,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF4043F2)
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                group['range']!,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(
                                          0xFF4043F2,
                                        ).withValues(alpha: 0.7)
                                      : Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const Spacer(),

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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBreedSearch() {
    // Simple breed input dialog
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Breed'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g., Golden Retriever',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  ref
                      .read(onboardingProvider.notifier)
                      .updateBreed(controller.text, 1.0);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
