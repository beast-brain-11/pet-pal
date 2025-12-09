// Survey Vaccination Page (PG7) - Vaccination History
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/onboarding_provider.dart';

class SurveyVaccinationPage extends ConsumerStatefulWidget {
  const SurveyVaccinationPage({super.key});

  @override
  ConsumerState<SurveyVaccinationPage> createState() =>
      _SurveyVaccinationPageState();
}

class _SurveyVaccinationPageState extends ConsumerState<SurveyVaccinationPage> {
  final List<_VaccineItem> _vaccines = [
    _VaccineItem(name: 'Rabies', icon: Icons.vaccines),
    _VaccineItem(name: 'Distemper/Parvo (DHPP)', icon: Icons.medication),
    _VaccineItem(name: 'Bordetella', icon: Icons.medical_services),
    _VaccineItem(name: 'Leptospirosis', icon: Icons.healing),
    _VaccineItem(name: 'Lyme Disease', icon: Icons.bug_report),
    _VaccineItem(name: 'Canine Influenza', icon: Icons.air),
  ];

  DateTime? _lastVetVisit;

  @override
  void initState() {
    super.initState();
    final data = ref.read(onboardingProvider);
    _lastVetVisit = data.lastVetVisit;

    // Restore previous vaccination selections
    for (final vax in data.vaccinations) {
      final index = _vaccines.indexWhere((v) => v.name == vax.name);
      if (index >= 0) {
        _vaccines[index].isSelected = vax.isCompleted;
        _vaccines[index].date = vax.date;
      }
    }
  }

  void _continue() {
    final vaccinations = _vaccines
        .where((v) => v.isSelected)
        .map(
          (v) =>
              VaccinationRecord(name: v.name, date: v.date, isCompleted: true),
        )
        .toList();

    ref.read(onboardingProvider.notifier).updateVaccinations(vaccinations);
    ref.read(onboardingProvider.notifier).updateLastVetVisit(_lastVetVisit);
    context.go(AppRoutes.surveyMedical);
  }

  Future<void> _selectDate(_VaccineItem vaccine) async {
    final date = await showDatePicker(
      context: context,
      initialDate: vaccine.date ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => vaccine.date = date);
    }
  }

  Future<void> _selectLastVetVisit() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _lastVetVisit ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _lastVetVisit = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4043F2), Color(0xFF6467F2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.surveyReview),
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
                      '7/11',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      "Let's Update ${onboarding.name.isNotEmpty ? onboarding.name : 'Your Dog'}'s",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      "Health Records",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Content
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vaccination History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select the vaccines your dog has received',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),

                        // Vaccine list
                        ...List.generate(_vaccines.length, (index) {
                          final vaccine = _vaccines[index];
                          return _buildVaccineItem(vaccine);
                        }),

                        const SizedBox(height: 24),

                        // Last Vet Visit
                        const Text(
                          'Last Vet Visit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _selectLastVetVisit,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _lastVetVisit != null
                                      ? DateFormat(
                                          'MMMM d, yyyy',
                                        ).format(_lastVetVisit!)
                                      : 'Select date',
                                  style: TextStyle(
                                    color: _lastVetVisit != null
                                        ? Colors.black
                                        : Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Continue button
                        SizedBox(
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
                              'Save and Continue',
                              style: TextStyle(
                                fontSize: 16,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaccineItem(_VaccineItem vaccine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vaccine.isSelected
            ? const Color(0xFF4043F2).withValues(alpha: 0.1)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: vaccine.isSelected
              ? const Color(0xFF4043F2)
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: () =>
                setState(() => vaccine.isSelected = !vaccine.isSelected),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: vaccine.isSelected
                    ? const Color(0xFF4043F2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: vaccine.isSelected
                      ? const Color(0xFF4043F2)
                      : Colors.grey[300]!,
                ),
              ),
              child: vaccine.isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: 16),

          // Icon and name
          Icon(vaccine.icon, color: const Color(0xFF4043F2), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              vaccine.name,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ),

          // Date picker
          if (vaccine.isSelected)
            GestureDetector(
              onTap: () => _selectDate(vaccine),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  vaccine.date != null
                      ? DateFormat('MM/dd/yy').format(vaccine.date!)
                      : 'Add date',
                  style: TextStyle(
                    color: vaccine.date != null
                        ? Colors.black
                        : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VaccineItem {
  final String name;
  final IconData icon;
  bool isSelected = false;
  DateTime? date;

  _VaccineItem({required this.name, required this.icon});
}
