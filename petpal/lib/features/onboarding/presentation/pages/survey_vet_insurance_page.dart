// Survey Vet & Insurance Page (PG9) - Vet details and insurance info
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/onboarding_provider.dart';

class SurveyVetInsurancePage extends ConsumerStatefulWidget {
  const SurveyVetInsurancePage({super.key});

  @override
  ConsumerState<SurveyVetInsurancePage> createState() =>
      _SurveyVetInsurancePageState();
}

class _SurveyVetInsurancePageState
    extends ConsumerState<SurveyVetInsurancePage> {
  final _vetNameController = TextEditingController();
  final _vetPhoneController = TextEditingController();
  final _insuranceProviderController = TextEditingController();
  final _policyNumberController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final data = ref.read(onboardingProvider);
    _vetNameController.text = data.vetClinicName ?? '';
    _vetPhoneController.text = data.vetPhone ?? '';
    _insuranceProviderController.text = data.insuranceProvider ?? '';
    _policyNumberController.text = data.policyNumber ?? '';
    // Parse existing emergency contact if available
    final emergency = data.emergencyContact ?? '';
    if (emergency.contains(' - ')) {
      final parts = emergency.split(' - ');
      _emergencyNameController.text = parts[0];
      _emergencyPhoneController.text = parts.length > 1 ? parts[1] : '';
    } else {
      _emergencyNameController.text = emergency;
    }
  }

  @override
  void dispose() {
    _vetNameController.dispose();
    _vetPhoneController.dispose();
    _insuranceProviderController.dispose();
    _policyNumberController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _continue() {
    // Validate phone numbers if provided
    final vetPhone = _vetPhoneController.text.trim();
    if (vetPhone.isNotEmpty && !_isValidPhone(vetPhone)) {
      _showValidationError('Please enter a valid vet phone number');
      return;
    }

    final emergencyPhone = _emergencyPhoneController.text.trim();
    if (emergencyPhone.isNotEmpty && !_isValidPhone(emergencyPhone)) {
      _showValidationError('Please enter a valid emergency phone number');
      return;
    }

    ref
        .read(onboardingProvider.notifier)
        .updateVetInfo(
          clinicName: _vetNameController.text.trim(),
          phone: vetPhone,
        );
    ref
        .read(onboardingProvider.notifier)
        .updateInsurance(
          provider: _insuranceProviderController.text.trim(),
          policyNumber: _policyNumberController.text.trim(),
        );

    // Combine emergency name and phone
    final emergencyName = _emergencyNameController.text.trim();
    if (emergencyName.isNotEmpty || emergencyPhone.isNotEmpty) {
      final combined = emergencyPhone.isNotEmpty
          ? '$emergencyName - $emergencyPhone'
          : emergencyName;
      ref.read(onboardingProvider.notifier).updateEmergencyContact(combined);
    }
    context.go(AppRoutes.surveyDocuments);
  }

  bool _isValidPhone(String phone) {
    // Allow digits, spaces, dashes, parentheses, and plus sign
    // Must have at least 7 digits
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      return false;
    }
    final validPattern = RegExp(r'^[\d\s\-\(\)\+]+$');
    return validPattern.hasMatch(phone);
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
                        onTap: () => context.go(AppRoutes.surveyMedical),
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
                        '9/11',
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
                    'Health Records',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Vet & Insurance Details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    // Vet section
                    _buildSectionCard(
                      icon: Icons.local_hospital,
                      title: 'Primary Vet',
                      children: [
                        _buildTextField(
                          controller: _vetNameController,
                          label: 'Clinic Name',
                          hint: 'Enter vet clinic name',
                          icon: Icons.business,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _vetPhoneController,
                          label: 'Phone Number',
                          hint: '(555) 123-4567',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Insurance section
                    _buildSectionCard(
                      icon: Icons.security,
                      title: 'Pet Insurance',
                      children: [
                        _buildTextField(
                          controller: _insuranceProviderController,
                          label: 'Insurance Provider',
                          hint: 'e.g., Nationwide, Trupanion',
                          icon: Icons.verified_user,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _policyNumberController,
                          label: 'Policy Number',
                          hint: 'Enter policy number',
                          icon: Icons.confirmation_number,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Emergency contact
                    _buildSectionCard(
                      icon: Icons.emergency,
                      title: 'Emergency Contact',
                      children: [
                        _buildTextField(
                          controller: _emergencyNameController,
                          label: 'Contact Name',
                          hint: 'Enter contact name',
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emergencyPhoneController,
                          label: 'Phone Number',
                          hint: '(555) 123-4567',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),

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

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4043F2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF4043F2), size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
