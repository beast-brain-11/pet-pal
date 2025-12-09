// Survey Documents Page (PG10) - Upload Important Documents
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/services/gemini_service.dart';

class SurveyDocumentsPage extends ConsumerStatefulWidget {
  const SurveyDocumentsPage({super.key});

  @override
  ConsumerState<SurveyDocumentsPage> createState() =>
      _SurveyDocumentsPageState();
}

class _SurveyDocumentsPageState extends ConsumerState<SurveyDocumentsPage> {
  final _picker = ImagePicker();
  final List<_DocumentItem> _documents = [];
  String? _selectedCategory;

  final _categories = [
    'Adoption Papers',
    'Vaccination',
    'Medical Reports',
    'Lab Tests',
    'X-rays/Scans',
    'Insurance',
    'Microchip',
    'Other',
  ];

  Future<void> _pickDocument() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
    );
    if (image != null) {
      final doc = _DocumentItem(
        path: image.path,
        fileName: image.name,
        category: _selectedCategory,
      );
      setState(() {
        _documents.add(doc);
      });
      ref.read(onboardingProvider.notifier).addDocument(image.path);

      // Run AI analysis in background
      _analyzeDocumentInBackground(doc);
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
    );
    if (image != null) {
      final doc = _DocumentItem(
        path: image.path,
        fileName: image.name,
        category: _selectedCategory,
      );
      setState(() {
        _documents.add(doc);
      });
      ref.read(onboardingProvider.notifier).addDocument(image.path);

      // Run AI analysis in background
      _analyzeDocumentInBackground(doc);
    }
  }

  Future<void> _analyzeDocumentInBackground(_DocumentItem doc) async {
    try {
      final file = File(doc.path);
      final bytes = await file.readAsBytes();

      // Analyze with Gemini
      final result = await GeminiService().analyzeDocument(bytes);

      if (mounted) {
        setState(() {
          doc.analysisResult = result;
          // Subtly log success or handle logic if needed
        });
        print(
          'Background Analysis Complete for ${doc.fileName}: ${result.summary}',
        );
      }
    } catch (e) {
      print('Background Analysis Failed: $e');
    }
  }

  void _removeDocument(int index) {
    final path = _documents[index].path;
    setState(() {
      _documents.removeAt(index);
    });
    ref.read(onboardingProvider.notifier).removeDocument(path);
  }

  void _continue() {
    context.go(AppRoutes.surveyComplete);
  }

  String _getFileSize(String path) {
    try {
      final file = File(path);
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return '';
    }
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
            colors: [Color(0xFFE6E7FF), Color(0xFFB9BBFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.surveyVetInsurance),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFF1A1A2E),
                          size: 24,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Health Records',
                        style: TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Headline
                      Text(
                        "Upload ${onboarding.name.isEmpty ? 'Important' : '${onboarding.name}\'s'} Documents",
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Keep all records in one place (Optional).',
                        style: TextStyle(
                          color: Color(0xFF5A5A78),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Main Upload Area
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Dashed upload area
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 40,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF4043F2,
                                  ).withValues(alpha: 0.5),
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4043F2,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                    child: const Icon(
                                      Icons.cloud_upload,
                                      color: Color(0xFF4043F2),
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Tap to upload or take a photo',
                                    style: TextStyle(
                                      color: Color(0xFF1A1A2E),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Supports PDF, JPG, PNG. Files are securely backed up.',
                                    style: TextStyle(
                                      color: Color(0xFF5A5A78),
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  // Buttons row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _pickDocument,
                                          icon: const Icon(
                                            Icons.photo_library,
                                            size: 20,
                                          ),
                                          label: const Text(
                                            'Choose from Library',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: const Color(
                                              0xFF1A1A2E,
                                            ),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _takePhoto,
                                          icon: const Icon(
                                            Icons.photo_camera,
                                            size: 20,
                                          ),
                                          label: const Text('Take Photo'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: const Color(
                                              0xFF1A1A2E,
                                            ),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Document Categories
                      const Text(
                        'Document Categories',
                        style: TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategory = isSelected ? null : cat;
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
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Uploaded Files List
                      if (_documents.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        const Text(
                          'Uploaded Documents',
                          style: TextStyle(
                            color: Color(0xFF1A1A2E),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_documents.length, (index) {
                          final doc = _documents[index];
                          final isImage =
                              doc.path.toLowerCase().endsWith('.jpg') ||
                              doc.path.toLowerCase().endsWith('.jpeg') ||
                              doc.path.toLowerCase().endsWith('.png');
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Icon/Thumbnail
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4043F2,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: isImage
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.file(
                                            File(doc.path),
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.description,
                                          color: Color(0xFF4043F2),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                // File info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.fileName.length > 25
                                            ? '${doc.fileName.substring(0, 25)}...'
                                            : doc.fileName,
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A2E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getFileSize(doc.path),
                                        style: const TextStyle(
                                          color: Color(0xFF5A5A78),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Delete button
                                IconButton(
                                  onPressed: () => _removeDocument(index),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF5A5A78),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 100), // Space for footer
                    ],
                  ),
                ),
              ),

              // Sticky Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                child: Column(
                  children: [
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
                          elevation: 2,
                        ),
                        child: Text(
                          _documents.isEmpty
                              ? 'Skip for Now'
                              : 'Save & Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (_documents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _continue,
                        child: const Text(
                          'Skip for Now',
                          style: TextStyle(
                            color: Color(0xFF4043F2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentItem {
  final String path;
  final String fileName;
  final String? category;
  DocumentAnalysisResult? analysisResult;

  _DocumentItem({required this.path, required this.fileName, this.category});
}
