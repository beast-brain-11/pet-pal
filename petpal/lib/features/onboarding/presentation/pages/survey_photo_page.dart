// Survey Photo Page (Survey 1) - Photo upload and name input
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/services/gemini_service.dart';

class SurveyPhotoPage extends ConsumerStatefulWidget {
  const SurveyPhotoPage({super.key});

  @override
  ConsumerState<SurveyPhotoPage> createState() => _SurveyPhotoPageState();
}

class _SurveyPhotoPageState extends ConsumerState<SurveyPhotoPage> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  final _geminiService = GeminiService();

  String? _imagePath;
  bool _isAnalyzing = false;
  bool _scanForBreed = true;
  BreedDetectionResult? _breedResult;

  @override
  void initState() {
    super.initState();
    final data = ref.read(onboardingProvider);
    _nameController.text = data.name;
    _imagePath = data.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
    );
    if (image != null) {
      setState(() {
        _imagePath = image.path;
        _breedResult = null;
      });
      ref.read(onboardingProvider.notifier).updatePhoto(image.path);

      if (_scanForBreed) {
        _analyzeBreed();
      }
    }
  }

  Future<void> _analyzeBreed() async {
    if (_imagePath == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final bytes = await File(_imagePath!).readAsBytes();
      final result = await _geminiService.detectBreed(bytes);

      if (mounted) {
        setState(() {
          _breedResult = result;
          _isAnalyzing = false;
        });

        if (result.primaryBreed.isNotEmpty) {
          ref
              .read(onboardingProvider.notifier)
              .updateBreed(
                result.primaryBreed,
                result.breeds.isNotEmpty ? result.breeds.first.confidence : 0.0,
              );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to analyze: $e')));
      }
    }
  }

  void _continue() {
    final name = _nameController.text.trim();

    // Validate name is not empty
    if (name.isEmpty) {
      _showValidationError('Please enter your dog\'s name');
      return;
    }

    // Validate name length (2-30 characters)
    if (name.length < 2) {
      _showValidationError('Name must be at least 2 characters');
      return;
    }
    if (name.length > 30) {
      _showValidationError('Name must be less than 30 characters');
      return;
    }

    // Validate name contains only letters, spaces, and hyphens
    final validNamePattern = RegExp(r'^[a-zA-Z\s\-]+$');
    if (!validNamePattern.hasMatch(name)) {
      _showValidationError(
        'Name can only contain letters, spaces, and hyphens',
      );
      return;
    }

    ref.read(onboardingProvider.notifier).updateName(name);
    context.go(AppRoutes.surveyBreed);
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
                // Header with back button
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.surveyWelcome),
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
                      '2/11',
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

                // Title
                const Text(
                  "Who's Your Best Friend?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // Photo Circle
                GestureDetector(
                  onTap: () => _showImageOptions(),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      image: _imagePath != null
                          ? DecorationImage(
                              image: FileImage(File(_imagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imagePath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_camera,
                                color: Colors.white.withValues(alpha: 0.8),
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          )
                        : _isAnalyzing
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      'Add Photo',
                      Icons.photo_library,
                      () => _pickImage(ImageSource.gallery),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      'Take Photo',
                      Icons.camera_alt,
                      () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Breed scan checkbox
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _scanForBreed,
                      onChanged: (v) =>
                          setState(() => _scanForBreed = v ?? true),
                      fillColor: WidgetStateProperty.all(
                        Colors.white.withValues(alpha: 0.3),
                      ),
                      checkColor: Colors.white,
                    ),
                    Text(
                      'Scan for Breed Detection',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),

                // Breed result
                if (_breedResult != null &&
                    _breedResult!.primaryBreed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_breedResult!.primaryBreed} (${_breedResult!.breeds.isNotEmpty ? _breedResult!.breeds.first.confidencePercent : 0}%)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Name input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's your dog's name?",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          color: Color(0xFF4043F2),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., Max, Bella, Charlie',
                          hintStyle: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}
