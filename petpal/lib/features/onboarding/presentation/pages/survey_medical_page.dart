// Survey Medical Page (PG8) - Medical Conditions
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/onboarding_provider.dart';

class SurveyMedicalPage extends ConsumerStatefulWidget {
  const SurveyMedicalPage({super.key});

  @override
  ConsumerState<SurveyMedicalPage> createState() => _SurveyMedicalPageState();
}

class _SurveyMedicalPageState extends ConsumerState<SurveyMedicalPage> {
  final _medicationController = TextEditingController();
  final _surgeryController = TextEditingController();

  final List<String> _conditions = [
    'Hip Dysplasia/Joint Issues',
    'Allergies/Skin Conditions',
    'Heart Disease',
    'Diabetes',
    'Epilepsy/Seizures',
    'Kidney Disease',
    'Thyroid Issues',
    'Cancer History',
    'Digestive Issues',
    'Respiratory Problems',
  ];

  List<String> _selectedConditions = [];
  List<String> _medications = [];
  List<String> _surgeries = [];

  @override
  void initState() {
    super.initState();
    final data = ref.read(onboardingProvider);
    _selectedConditions = List.from(data.medicalConditions);
    _medications = List.from(data.medications);
    _surgeries = List.from(data.surgeryHistory);
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _surgeryController.dispose();
    super.dispose();
  }

  void _addMedication() {
    final text = _medicationController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _medications.add(text);
        _medicationController.clear();
      });
    }
  }

  void _addSurgery() {
    final text = _surgeryController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _surgeries.add(text);
        _surgeryController.clear();
      });
    }
  }

  void _continue() {
    ref
        .read(onboardingProvider.notifier)
        .updateMedicalConditions(_selectedConditions);
    ref.read(onboardingProvider.notifier).updateMedications(_medications);
    ref.read(onboardingProvider.notifier).updateSurgeryHistory(_surgeries);
    context.go(AppRoutes.surveyVetInsurance);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.surveyVaccination),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.grey[700],
                            size: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '8/11',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Medical History',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Any Medical\nConditions?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Conditions
                    const Text(
                      'Select any conditions that apply',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _conditions.map((condition) {
                        final isSelected = _selectedConditions.contains(
                          condition,
                        );
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedConditions.remove(condition);
                              } else {
                                _selectedConditions.add(condition);
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
                                  ? const Color(0xFF4043F2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4043F2)
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              condition,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // Medications
                    const Text(
                      'Current Medications',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _medicationController,
                            decoration: InputDecoration(
                              hintText: 'Add medication',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: (_) => _addMedication(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _addMedication,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4043F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (_medications.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _medications
                            .map(
                              (med) => _buildChip(med, () {
                                setState(() => _medications.remove(med));
                              }),
                            )
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Surgery History
                    const Text(
                      'Surgery History',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _surgeryController,
                            decoration: InputDecoration(
                              hintText: 'Add surgery',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: (_) => _addSurgery(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _addSurgery,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4043F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (_surgeries.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _surgeries
                            .map(
                              (surgery) => _buildChip(surgery, () {
                                setState(() => _surgeries.remove(surgery));
                              }),
                            )
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Bottom button
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4043F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4043F2).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF4043F2),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: Color(0xFF4043F2)),
          ),
        ],
      ),
    );
  }
}
