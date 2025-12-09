// Gemini AI Service for PetPal
// Handles breed detection, recipe generation, and health chat

import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyCJn9MtZX02X_Yu5ni4cdT_44B9qT9KoEc';
  static const String _model = 'gemini-flash-lite-latest';
  static const String _imageModel =
      'gemini-2.5-flash-image'; // Correct model for image generation

  late final GenerativeModel _textModel;
  late final GenerativeModel _visionModel;
  late final GenerativeModel _imageGenModel;

  // Singleton instance
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;

  GeminiService._internal() {
    _textModel = GenerativeModel(
      model: _model,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 2048,
      ),
    );

    _visionModel = GenerativeModel(
      model: _model,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 1024,
      ),
    );

    _imageGenModel = GenerativeModel(
      model: _imageModel,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 1.0,
        // No responseMimeType - allow image responses
      ),
    );
  }

  /// Generate a cover image for a recipe using REST API
  /// Implements retry logic with exponential backoff for transient errors
  Future<Uint8List?> generateRecipeImage({
    required String recipeName,
    required List<String> ingredients,
    Duration timeout = const Duration(seconds: 120),
    int maxRetries = 3,
  }) async {
    final ingredientsList = ingredients.take(5).join(', ');

    final prompt =
        '''
Generate a beautiful, appetizing photo of homemade dog food.
Recipe: $recipeName
Main ingredients: $ingredientsList

The image should be:
- A realistic, professional food photography style
- Dog food served in a nice ceramic bowl
- Bright, natural lighting
- Top-down or 45-degree angle
- Clean, modern background
- Shows the texture and ingredients clearly
- No people, no dogs in frame
- Warm, inviting colors
''';

    // Use REST API - gemini-2.5-flash-image automatically outputs images
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_imageModel:generateContent?key=$_apiKey',
    );

    final requestBody = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      // CRITICAL: responseModalities must be UPPERCASE as per working Java SDK
      'generationConfig': {
        'responseModalities': ['IMAGE', 'TEXT'],
      },
    };

    print('DEBUG: ===== IMAGE GENERATION START =====');
    print('DEBUG: Recipe: $recipeName');
    print('DEBUG: Model: $_imageModel');
    print('DEBUG: Max retries: $maxRetries');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('DEBUG: Attempt $attempt of $maxRetries...');

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            )
            .timeout(
              timeout,
              onTimeout: () {
                print('DEBUG: Request timed out after ${timeout.inSeconds}s');
                throw Exception('Request timed out');
              },
            );

        print('DEBUG: Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // Check for error in response body (some errors come as 200)
          if (data['error'] != null) {
            print('DEBUG: Error in response: ${data['error']}');
            continue;
          }

          // Extract image from response
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;

            if (parts != null) {
              for (final part in parts) {
                if (part['inlineData'] != null) {
                  final inlineData = part['inlineData'];
                  final mimeType = inlineData['mimeType'] as String?;
                  final base64Data = inlineData['data'] as String?;

                  if (base64Data != null &&
                      mimeType?.startsWith('image/') == true) {
                    print('DEBUG: ✅ SUCCESS! Image generated');
                    print('DEBUG: MimeType: $mimeType');
                    print('DEBUG: Data size: ${base64Data.length} chars');
                    print('DEBUG: ===== IMAGE GENERATION END =====');
                    return base64Decode(base64Data);
                  }
                }

                // Check for text response (model might return text instead)
                if (part['text'] != null) {
                  print('DEBUG: Model returned text: ${part['text']}');
                }
              }
            }
          }

          print('DEBUG: No image data in response, checking for errors...');
          print(
            'DEBUG: Response preview: ${response.body.substring(0, response.body.length.clamp(0, 800))}',
          );
        } else if (response.statusCode == 429 || response.statusCode == 503) {
          // Rate limit or service unavailable - retry with backoff
          final waitSeconds = attempt * 5; // 5s, 10s, 15s
          print(
            'DEBUG: Server busy (${response.statusCode}), waiting ${waitSeconds}s before retry...',
          );
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        } else if (response.statusCode == 400) {
          // Bad request - check error details
          print('DEBUG: Bad request (400): ${response.body}');
          // Don't retry bad requests
          break;
        } else {
          print('DEBUG: API error ${response.statusCode}');
          print('DEBUG: Response: ${response.body}');

          // Check if response contains RESOURCE_EXHAUSTED
          if (response.body.contains('RESOURCE_EXHAUSTED')) {
            final waitSeconds =
                attempt * 10; // 10s, 20s, 30s for resource exhaustion
            print(
              'DEBUG: RESOURCE_EXHAUSTED detected, waiting ${waitSeconds}s...',
            );
            await Future.delayed(Duration(seconds: waitSeconds));
            continue;
          }
        }
      } catch (e) {
        print('DEBUG: Exception on attempt $attempt: $e');
        if (attempt < maxRetries) {
          final waitSeconds = attempt * 3;
          print('DEBUG: Waiting ${waitSeconds}s before retry...');
          await Future.delayed(Duration(seconds: waitSeconds));
        }
      }
    }

    print('DEBUG: ❌ Image generation failed after $maxRetries attempts');
    print('DEBUG: ===== IMAGE GENERATION END =====');
    return null;
  }

  /// Generate a vertical 16:9 infographic card for sharing
  Future<Uint8List?> generateInfographic({
    required String recipeName,
    required List<String> ingredients,
    required Map<dynamic, dynamic> nutrition,
    required String story,
  }) async {
    try {
      final ingredientsList = ingredients.take(6).join('\n• ');
      final calories = nutrition['calories'] ?? nutrition[0] ?? 0;
      final protein = nutrition['protein'] ?? nutrition[1] ?? 0;

      final prompt =
          '''
Create a beautiful vertical 9:16 infographic card for a dog food recipe.

Recipe Name: $recipeName
Story: $story

Ingredients:
• $ingredientsList

Nutrition: $calories kcal, ${protein}g protein

Design requirements:
- Vertical 9:16 aspect ratio (like Instagram story)
- Modern, clean design with soft purple (#7C4DFF) accent color
- Recipe name as large header at top
- Beautiful food photo placeholder in center
- Ingredients list with checkmarks
- Nutrition facts in a nice card at bottom
- "Made with PetPal 🐾" watermark at bottom
- Warm, inviting color palette
- Professional typography
- Dog paw prints as decorative elements
''';

      final response = await _imageGenModel.generateContent([
        Content.text(prompt),
      ]);

      for (final candidate in response.candidates) {
        for (final part in candidate.content.parts) {
          if (part is DataPart) {
            return part.bytes;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Detect dog breed from image bytes
  Future<BreedDetectionResult> detectBreed(Uint8List imageBytes) async {
    try {
      final prompt = '''
Analyze this image of a dog and identify its breed. Return your response in the following JSON format only:
{
  "breeds": [
    {"name": "Primary Breed Name", "confidence": 0.85},
    {"name": "Secondary Breed (if mixed)", "confidence": 0.15}
  ],
  "isPurebred": true,
  "estimatedAge": "adult",
  "size": "large",
  "description": "Brief description of the dog's appearance"
}

If you cannot detect a dog in the image, return:
{"error": "No dog detected in image"}
''';

      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ];

      final response = await _visionModel.generateContent(content);
      final text = response.text ?? '{"error": "Failed to analyze image"}';

      return BreedDetectionResult.fromJson(text);
    } catch (e) {
      return BreedDetectionResult(
        breeds: [],
        error: 'Failed to detect breed: $e',
      );
    }
  }

  /// Analyze a pet document (vaccination record, medical record, etc.)
  Future<DocumentAnalysisResult> analyzeDocument(Uint8List imageBytes) async {
    try {
      final prompt = '''
Analyze this pet-related document image and extract key information. 
Return your response in the following JSON format only:
{
  "documentType": "Vaccination Record" | "Medical Record" | "Insurance Document" | "Prescription" | "Lab Report" | "Other",
  "isValid": true,
  "extractedInfo": {
    "Pet Name": "extracted name if visible",
    "Date": "date on document if visible",
    "Veterinarian": "vet name/clinic if visible",
    "Vaccine/Treatment": "vaccine or treatment name if applicable",
    "Notes": "any other important information"
  },
  "summary": "Brief 1-2 sentence summary of the document"
}

If the document is not readable or not pet-related, return:
{"documentType": "Unknown", "isValid": false, "error": "Could not analyze document", "extractedInfo": {}}

Only include fields in extractedInfo that are actually visible in the document.
''';

      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ];

      final response = await _visionModel.generateContent(content);
      final text = response.text ?? '{"error": "Failed to analyze document"}';

      return DocumentAnalysisResult.fromJson(text);
    } catch (e) {
      return DocumentAnalysisResult(error: 'Failed to analyze document: $e');
    }
  }

  /// Generate a personalized recipe based on dog profile
  Future<RecipeResult> generateRecipe({
    required String dogName,
    required String breed,
    required String size,
    required double weightLbs,
    required String activityLevel,
    required List<String> dietaryPreferences,
    required List<String> allergies,
    String? mealType,
  }) async {
    try {
      final allergyNote = allergies.isNotEmpty
          ? 'IMPORTANT: Must avoid these ingredients (allergies): ${allergies.join(", ")}'
          : 'No known allergies';

      final dietNote = dietaryPreferences.isNotEmpty
          ? 'Dietary preferences: ${dietaryPreferences.join(", ")}'
          : 'No specific dietary preferences';

      final prompt =
          '''
Create a homemade dog food recipe for:
- Dog: $dogName
- Breed: $breed
- Size: $size
- Weight: ${weightLbs.toStringAsFixed(1)} lbs
- Activity Level: $activityLevel
${mealType != null ? '- Meal Type: $mealType' : ''}

$allergyNote
$dietNote

Return ONLY valid JSON in this exact format:
{
  "title": "Recipe Name",
  "description": "Brief description of the recipe",
  "prepTime": 15,
  "cookTime": 25,
  "servings": 2,
  "difficulty": "Easy",
  "calories": 350,
  "nutrition": {
    "protein": 28,
    "carbs": 35,
    "fat": 12,
    "fiber": 3
  },
  "ingredients": [
    {"name": "Chicken breast", "amount": "200g", "notes": "boneless, skinless"}
  ],
  "instructions": [
    "Step 1 description",
    "Step 2 description"
  ],
  "tags": ["high-protein", "grain-free"],
  "tips": "Storage and serving tips"
}
''';

      final response = await _textModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{"error": "Failed to generate recipe"}';

      return RecipeResult.fromJson(text);
    } catch (e) {
      return RecipeResult(error: 'Failed to generate recipe: $e');
    }
  }

  /// Generate personalized DOG FOOD recipe based on profile and available ingredients
  Future<EnhancedRecipeResult> generateRecipeWithContext({
    required String dogName,
    required String breed,
    required String size,
    required double weightLbs,
    required String activityLevel,
    required List<String> dietaryPreferences,
    required List<String> allergies,
    String? mealType,
    List<String>? availableIngredients,
    List<String>? healthConditions,
    int? dogAgeMonths,
    String? userFeedback, // For regeneration with user feedback
  }) async {
    try {
      // Calculate daily caloric needs based on dog weight and activity
      final weightKg = weightLbs * 0.453592;
      final baseCalories = 70 * (weightKg.clamp(1, 100) * 0.75); // RER formula
      final activityMultiplier =
          {
            'low': 1.2,
            'moderate': 1.4,
            'active': 1.6,
            'high': 1.8,
            'very active': 2.0,
          }[activityLevel.toLowerCase()] ??
          1.4;
      final dailyCalories = (baseCalories * activityMultiplier).round();
      final mealCalories = (dailyCalories / 2).round(); // Assuming 2 meals/day

      final allergyNote = allergies.isNotEmpty
          ? 'TOXIC/ALLERGIC - NEVER USE: ${allergies.join(", ")}'
          : '';

      final dietNote = dietaryPreferences.isNotEmpty
          ? 'Diet type: ${dietaryPreferences.join(", ")}'
          : '';

      final ingredientNote =
          availableIngredients != null && availableIngredients.isNotEmpty
          ? 'USE ONLY THESE AVAILABLE INGREDIENTS: ${availableIngredients.join(", ")}'
          : '';

      final healthNote = healthConditions != null && healthConditions.isNotEmpty
          ? 'HEALTH CONDITIONS TO CONSIDER: ${healthConditions.join(", ")}'
          : '';

      final ageNote = dogAgeMonths != null
          ? dogAgeMonths < 12
                ? 'PUPPY (${dogAgeMonths} months) - needs higher protein and calcium'
                : dogAgeMonths > 84
                ? 'SENIOR DOG - needs easily digestible, joint-supporting food'
                : 'ADULT DOG'
          : '';

      final prompt =
          '''
You are a VETERINARY NUTRITIONIST. Create a COMPLETE, BALANCED homemade dog food recipe.

⚠️ CRITICAL SAFETY RULES - NEVER include these toxic foods:
- Chocolate, caffeine, alcohol
- Onions, garlic, chives, leeks
- Grapes, raisins, currants
- Xylitol (artificial sweetener)
- Macadamia nuts
- Avocado
- Raw yeast dough
- Cooked bones (can splinter)

DOG PROFILE:
- Name: $dogName
- Breed: $breed (consider breed-specific nutritional needs)
- Size: $size
- Weight: ${weightLbs.toStringAsFixed(1)} lbs (${weightKg.toStringAsFixed(1)} kg)
- Activity Level: $activityLevel
- Daily Caloric Need: ~$dailyCalories kcal
- This meal should provide: ~$mealCalories kcal
$ageNote
${mealType != null ? '- Meal Type: $mealType' : ''}

$allergyNote
$dietNote
$healthNote
$ingredientNote
${userFeedback != null && userFeedback.isNotEmpty ? 'USER FEEDBACK FOR THIS RECIPE: $userFeedback (incorporate this feedback into the recipe)' : ''}

🍽️ RECIPE REQUIREMENTS:
1. Create a COMPLETE, BALANCED meal - NOT just one ingredient
2. If user provides limited ingredients (e.g., only "rice"), ADD other safe, complementary ingredients to make it nutritious
3. Every meal MUST include:
   - PROTEIN source (for dogs: chicken, beef, eggs, fish, turkey, cottage cheese)
   - CARBOHYDRATES (rice, oats, sweet potato)
   - VEGETABLES (carrots, peas, spinach, pumpkin)
4. Give the recipe a CREATIVE, appealing name
5. Provide DETAILED cooking instructions (not just "boil and serve")
6. Calculate proper portions for this specific dog's weight

PORTION GUIDANCE for ${size.toLowerCase()} dogs:
- Toy/Small (<10 lbs): 1/4 to 1/2 cup per meal
- Medium (10-50 lbs): 1/2 to 1.5 cups per meal
- Large (50-100 lbs): 1.5 to 3 cups per meal
- Giant (>100 lbs): 3+ cups per meal

Return ONLY valid JSON:
{
  "name": "Creative Dog Recipe Name",
  "story": "Why this recipe is perfect for $dogName the $breed",
  "category": "${mealType ?? 'Dinner'}",
  "difficulty": "Easy",
  "servings": 1,
  "portionSize": "X cups for ${size.toLowerCase()} dog",
  "timing": {"prepTime": 10, "cookTime": 20},
  "ingredients": [
    {
      "name": "Ingredient",
      "quantity": 100,
      "unit": "g",
      "notes": "preparation notes",
      "safetyNote": "why this is good for dogs"
    }
  ],
  "instructions": [
    {"step": 1, "instruction": "Step", "timeMinutes": 5, "tips": "tip"}
  ],
  "nutrition": {
    "calories": $mealCalories,
    "protein": 25,
    "fat": 15,
    "carbs": 30,
    "fiber": 5
  },
  "tags": ["dog-safe", "homemade"],
  "whySpecial": "Nutritional benefits for $dogName",
  "safetyNotes": "Any important feeding notes for this dog",
  "storageInstructions": "How long it keeps in fridge/freezer"
}
''';

      final response = await _textModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{"error": "Failed to generate recipe"}';

      return EnhancedRecipeResult.fromJson(text);
    } catch (e) {
      return EnhancedRecipeResult(error: 'Failed to generate recipe: $e');
    }
  }

  /// Analyze nutrition of a recipe for health conditions
  Future<NutritionAnalysisResult> analyzeRecipeNutrition({
    required String recipeName,
    required List<Map<String, dynamic>> ingredients,
    required String dogBreed,
    required String dogSize,
    required double dogWeight,
    List<String>? healthConditions,
    List<String>? medications,
  }) async {
    try {
      final healthNote = healthConditions != null && healthConditions.isNotEmpty
          ? 'Health conditions: ${healthConditions.join(", ")}'
          : 'No known health conditions';

      final medNote = medications != null && medications.isNotEmpty
          ? 'Current medications: ${medications.join(", ")}'
          : 'No current medications';

      final prompt =
          '''
Analyze this dog food recipe for nutritional completeness and safety.

RECIPE: $recipeName
INGREDIENTS: ${jsonEncode(ingredients)}

DOG PROFILE:
- Breed: $dogBreed
- Size: $dogSize
- Weight: $dogWeight lbs
$healthNote
$medNote

Return ONLY valid JSON:
{
  "aafco_compliance": {
    "compliant": true,
    "explanation": "Brief AAFCO compliance explanation",
    "missing_nutrients": []
  },
  "overall_health_score": 85,
  "recommendation": "Safe for regular feeding" | "Consult vet first" | "Not recommended",
  "benefits": ["benefit1", "benefit2"],
  "concerns": ["concern1"],
  "suggested_modifications": ["modification1"],
  "confidence_level": 90
}
''';

      final response = await _textModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{"error": "Analysis failed"}';

      return NutritionAnalysisResult.fromJson(text);
    } catch (e) {
      return NutritionAnalysisResult(error: 'Failed to analyze: $e');
    }
  }

  /// Get real-time cooking guidance for a step
  Future<CookingGuidanceResult> getCookingGuidance({
    required String recipeName,
    required int currentStep,
    required String stepInstruction,
    String? userQuestion,
    String? currentIssue,
  }) async {
    try {
      final prompt =
          '''
Provide real-time cooking guidance for preparing dog food.

RECIPE: $recipeName
CURRENT STEP: $currentStep - "$stepInstruction"
${userQuestion != null ? 'USER QUESTION: $userQuestion' : ''}
${currentIssue != null ? 'ISSUE: $currentIssue' : ''}

Return ONLY valid JSON:
{
  "immediate_guidance": "Direct answer or guidance",
  "visual_cues": "What to look for to know this step is done correctly",
  "timing_estimate": "How long this should take",
  "expert_tips": ["tip1", "tip2"],
  "mistakes_to_avoid": ["mistake1"],
  "next_milestone": "What comes next",
  "safety_alert": null
}
''';

      final response = await _textModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{"error": "Guidance failed"}';

      return CookingGuidanceResult.fromJson(text);
    } catch (e) {
      return CookingGuidanceResult(error: 'Failed to get guidance: $e');
    }
  }

  /// Get health advice from AI assistant
  Future<String> getHealthAdvice({
    required String userMessage,
    required String dogName,
    required String breed,
    required String age,
    List<String>? symptoms,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    try {
      final historyContext =
          conversationHistory != null && conversationHistory.isNotEmpty
          ? 'Previous conversation:\n${conversationHistory.map((m) => '${m["isUser"] ? "User" : "AI"}: ${m["text"]}').join("\n")}\n\n'
          : '';

      final symptomsNote = symptoms != null && symptoms.isNotEmpty
          ? 'Current symptoms being discussed: ${symptoms.join(", ")}\n'
          : '';

      final prompt =
          '''
You are a helpful AI pet health assistant for PetPal app. You provide general health information and guidance for dogs. 

IMPORTANT DISCLAIMER: Always remind users that your advice is informational only and not a substitute for professional veterinary care. For emergencies or serious symptoms, always recommend seeing a vet immediately.

Dog Profile:
- Name: $dogName
- Breed: $breed
- Age: $age

$symptomsNote
$historyContext
User's message: $userMessage

Provide a helpful, empathetic response. If discussing symptoms:
1. Acknowledge the concern
2. Provide general information
3. Give actionable home care tips if appropriate
4. Recommend when to see a vet
5. Keep response concise but informative
''';

      final response = await _textModel.generateContent([Content.text(prompt)]);
      return response.text ??
          'I apologize, but I couldn\'t process your request. Please try again.';
    } catch (e) {
      return 'I\'m having trouble connecting right now. Please check your internet connection and try again.';
    }
  }

  /// Stream health advice for real-time responses
  Stream<String> streamHealthAdvice({
    required String userMessage,
    required String dogName,
    required String breed,
    required String age,
  }) async* {
    try {
      final prompt =
          '''
You are a helpful AI pet health assistant. Provide caring, informative advice.

Dog: $dogName ($breed, $age)
User asks: $userMessage

Respond helpfully and remind them to consult a vet for serious concerns.
''';

      final response = _textModel.generateContentStream([Content.text(prompt)]);

      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield 'Sorry, I encountered an error. Please try again.';
    }
  }

  /// Stream health consultation with full context (Mem0, survey data, health history)
  Stream<String> streamHealthConsultation({
    required String userMessage,
    required String dogName,
    required String breed,
    required String age,
    required String consultationType,
    Map<String, dynamic>? healthContext,
    String? memoryContext,
  }) async* {
    try {
      // Build comprehensive system prompt based on consultation mode
      final systemPrompt = _buildHealthSystemPrompt(
        dogName: dogName,
        breed: breed,
        age: age,
        consultationType: consultationType,
        healthContext: healthContext,
        memoryContext: memoryContext,
      );

      final prompt =
          '''
$systemPrompt

USER MESSAGE:
$userMessage

RESPONSE RULES (STRICT):
- Keep response to 2-3 SHORT sentences maximum
- Use simple, conversational language like texting a friend
- NO markdown, NO bullet points, NO headers, NO asterisks
- Be warm and caring but brief
- If serious, say "Please see a vet" at the end
- Sound like a helpful friend, not a medical textbook
''';

      final response = _textModel.generateContentStream([Content.text(prompt)]);

      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      print('DEBUG: Gemini streaming error: $e');
      yield 'Sorry, I encountered an error while processing your request. Please try again.';
    }
  }

  /// Build comprehensive system prompt for health consultations
  String _buildHealthSystemPrompt({
    required String dogName,
    required String breed,
    required String age,
    required String consultationType,
    Map<String, dynamic>? healthContext,
    String? memoryContext,
  }) {
    final buffer = StringBuffer();

    // Mode-specific persona
    switch (consultationType) {
      case 'emergency':
        buffer.writeln('🚨 EMERGENCY MODE - AI VETERINARY ASSISTANT 🚨');
        buffer.writeln(
          'You are an EMERGENCY veterinary AI assistant. Prioritize:',
        );
        buffer.writeln('1. Immediate life-saving instructions');
        buffer.writeln('2. First aid guidance');
        buffer.writeln('3. Clear urgency indicators');
        buffer.writeln('4. Emergency vet contact reminders');
        buffer.writeln('Be direct, clear, and action-oriented.');
        break;
      case 'video':
        buffer.writeln('📹 VIDEO CONSULTATION - AI VETERINARY ASSISTANT');
        buffer.writeln(
          'You are a video consultation AI vet. The user may describe or show symptoms visually.',
        );
        buffer.writeln('Ask clarifying questions about what they\'re seeing.');
        break;
      case 'voice':
        buffer.writeln('📞 VOICE CONSULTATION - AI VETERINARY ASSISTANT');
        buffer.writeln(
          'You are a voice consultation AI vet. Keep responses conversational.',
        );
        break;
      default:
        buffer.writeln('💬 AI VETERINARY ASSISTANT');
        buffer.writeln(
          'You are a helpful AI veterinary assistant for pet health consultations.',
        );
    }

    buffer.writeln('');
    buffer.writeln('--- DOG PROFILE ---');
    buffer.writeln('Name: $dogName');
    buffer.writeln('Breed: $breed');
    buffer.writeln('Age: $age');

    // Add health context from survey/onboarding
    if (healthContext != null && healthContext.isNotEmpty) {
      if (healthContext['weight'] != null) {
        buffer.writeln('Weight: ${healthContext['weight']} lbs');
      }
      if (healthContext['size'] != null) {
        buffer.writeln('Size: ${healthContext['size']}');
      }
      if (healthContext['activityLevel'] != null) {
        buffer.writeln('Activity Level: ${healthContext['activityLevel']}');
      }

      // Medical history
      final allergies = healthContext['allergies'] as List?;
      if (allergies != null && allergies.isNotEmpty) {
        buffer.writeln('⚠️ ALLERGIES: ${allergies.join(', ')}');
      }

      final medications = healthContext['medications'] as List?;
      if (medications != null && medications.isNotEmpty) {
        buffer.writeln('💊 CURRENT MEDICATIONS: ${medications.join(', ')}');
      }

      final conditions = healthContext['medicalConditions'] as List?;
      if (conditions != null && conditions.isNotEmpty) {
        buffer.writeln('🏥 MEDICAL CONDITIONS: ${conditions.join(', ')}');
      }

      final surgeries = healthContext['surgeryHistory'] as List?;
      if (surgeries != null && surgeries.isNotEmpty) {
        buffer.writeln('🔪 SURGERY HISTORY: ${surgeries.join(', ')}');
      }

      // Vet info
      if (healthContext['vetClinicName'] != null) {
        buffer.writeln('🏪 Regular Vet: ${healthContext['vetClinicName']}');
      }
      if (healthContext['emergencyContact'] != null) {
        buffer.writeln(
          '📱 Emergency Contact: ${healthContext['emergencyContact']}',
        );
      }
    }

    // Add Mem0 memory context (past consultations, symptoms, etc.)
    if (memoryContext != null && memoryContext.isNotEmpty) {
      buffer.writeln('');
      buffer.write(memoryContext);
    }

    buffer.writeln('');
    buffer.writeln('--- END OF CONTEXT ---');

    return buffer.toString();
  }

  /// Generate a dynamic, personalized pet fact
  /// Uses multimodal AI with context: breed, time of day, day of week
  Future<PetFactResult> generatePetFact({
    required String dogName,
    required String breed,
    String? photoUrl,
  }) async {
    try {
      final now = DateTime.now();
      final hour = now.hour;
      final dayOfWeek = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ][now.weekday % 7];

      String timeContext = 'daytime';
      if (hour >= 5 && hour < 9)
        timeContext = 'early morning';
      else if (hour >= 9 && hour < 12)
        timeContext = 'morning';
      else if (hour >= 12 && hour < 14)
        timeContext = 'midday';
      else if (hour >= 14 && hour < 17)
        timeContext = 'afternoon';
      else if (hour >= 17 && hour < 20)
        timeContext = 'evening';
      else if (hour >= 20 || hour < 5)
        timeContext = 'night';

      final prompt =
          '''
Generate a fun, interesting dog fact for a pet owner. The fact should be:
1. VERY SHORT: Under 50 characters for the short version
2. Breed-specific when possible (their dog is a $breed named $dogName)
3. Context-aware: It's $timeContext on $dayOfWeek
4. Verified and accurate (only use real facts)
5. Engaging and surprising

Return ONLY valid JSON in this exact format:
{
  "shortFact": "Short fact under 50 chars",
  "fullFact": "The complete detailed version of the fact with interesting context (2-3 sentences)",
  "category": "behavior" | "health" | "history" | "nutrition" | "fun",
  "shareText": "A beautifully formatted version for sharing as an image caption",
  "isBreedSpecific": true
}
''';

      final response = await _textModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      // Parse JSON response
      String jsonStr = text;
      if (text.contains('```json')) {
        jsonStr = text.split('```json')[1].split('```')[0].trim();
      } else if (text.contains('```')) {
        jsonStr = text.split('```')[1].split('```')[0].trim();
      }

      try {
        final data = json.decode(jsonStr);
        return PetFactResult(
          shortFact: data['shortFact'] ?? 'Dogs are amazing!',
          fullFact:
              data['fullFact'] ??
              'Dogs have been our companions for thousands of years.',
          category: data['category'] ?? 'fun',
          shareText: data['shareText'] ?? data['shortFact'],
          isBreedSpecific: data['isBreedSpecific'] ?? false,
        );
      } catch (e) {
        print('GeminiService: Error parsing pet fact: $e');
        return PetFactResult.fallback(breed);
      }
    } catch (e) {
      print('GeminiService: Error generating pet fact: $e');
      return PetFactResult.fallback(breed);
    }
  }

  /// Verify if a new photo is of the same dog as the reference photo
  Future<PhotoVerificationResult> verifyDogPhoto({
    required Uint8List referencePhoto,
    required Uint8List newPhoto,
    required String dogName,
    required String breed,
  }) async {
    try {
      final prompt =
          '''
You are an expert dog identification AI. Compare these two photos to determine if they show the SAME dog.

The registered dog is named "$dogName" and is a "$breed".

Analyze:
1. Fur color and pattern
2. Body size and shape
3. Face structure (especially eyes, nose, ears)
4. Any unique markings

Return ONLY valid JSON in this exact format:
{
  "isSameDog": true,
  "confidence": 0.95,
  "matchingFeatures": ["fur color", "face shape", "size"],
  "differences": [],
  "reason": "Brief explanation"
}

If the new photo doesn't contain a dog, return:
{
  "isSameDog": false,
  "confidence": 0.0,
  "matchingFeatures": [],
  "differences": ["No dog detected"],
  "reason": "No dog found in the new photo"
}
''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', referencePhoto),
          DataPart('image/jpeg', newPhoto),
        ]),
      ];

      final response = await _visionModel.generateContent(content);
      final text = response.text ?? '';

      // Parse JSON response
      String jsonStr = text;
      if (text.contains('```json')) {
        jsonStr = text.split('```json')[1].split('```')[0].trim();
      } else if (text.contains('```')) {
        jsonStr = text.split('```')[1].split('```')[0].trim();
      }

      try {
        final data = json.decode(jsonStr);
        return PhotoVerificationResult(
          isSameDog: data['isSameDog'] ?? false,
          confidence: (data['confidence'] ?? 0.0).toDouble(),
          matchingFeatures: List<String>.from(data['matchingFeatures'] ?? []),
          differences: List<String>.from(data['differences'] ?? []),
          reason: data['reason'] ?? 'Unknown',
        );
      } catch (e) {
        print('GeminiService: Error parsing photo verification: $e');
        return PhotoVerificationResult(
          isSameDog: false,
          confidence: 0.0,
          matchingFeatures: [],
          differences: ['Could not analyze'],
          reason: 'Analysis failed',
        );
      }
    } catch (e) {
      print('GeminiService: Error verifying photo: $e');
      return PhotoVerificationResult(
        isSameDog: false,
        confidence: 0.0,
        matchingFeatures: [],
        differences: ['Error'],
        reason: 'Service error: $e',
      );
    }
  }
}

// Result classes
class BreedDetectionResult {
  final List<BreedMatch> breeds;
  final bool isPurebred;
  final String? estimatedAge;
  final String? size;
  final String? description;
  final String? error;

  BreedDetectionResult({
    this.breeds = const [],
    this.isPurebred = false,
    this.estimatedAge,
    this.size,
    this.description,
    this.error,
  });

  factory BreedDetectionResult.fromJson(String jsonStr) {
    try {
      // Extract JSON from markdown code blocks if present
      String cleanJson = jsonStr;
      if (jsonStr.contains('```json')) {
        cleanJson = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        cleanJson = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> json = jsonDecode(cleanJson);

      if (json.containsKey('error')) {
        return BreedDetectionResult(error: json['error']);
      }

      final breedsList =
          (json['breeds'] as List?)
              ?.map(
                (b) => BreedMatch(
                  name: b['name'] ?? 'Unknown',
                  confidence: (b['confidence'] as num?)?.toDouble() ?? 0.0,
                ),
              )
              .toList() ??
          [];

      return BreedDetectionResult(
        breeds: breedsList,
        isPurebred: json['isPurebred'] ?? false,
        estimatedAge: json['estimatedAge'],
        size: json['size'],
        description: json['description'],
      );
    } catch (e) {
      return BreedDetectionResult(error: 'Failed to parse response: $e');
    }
  }

  bool get hasError => error != null;
  String get primaryBreed => breeds.isNotEmpty ? breeds.first.name : 'Unknown';
}

class BreedMatch {
  final String name;
  final double confidence;

  BreedMatch({required this.name, required this.confidence});

  int get confidencePercent => (confidence * 100).round();
}

class RecipeResult {
  final String? title;
  final String? description;
  final int? prepTime;
  final int? cookTime;
  final int? servings;
  final String? difficulty;
  final int? calories;
  final Map<String, dynamic>? nutrition;
  final List<RecipeIngredient>? ingredients;
  final List<String>? instructions;
  final List<String>? tags;
  final String? tips;
  final String? error;

  RecipeResult({
    this.title,
    this.description,
    this.prepTime,
    this.cookTime,
    this.servings,
    this.difficulty,
    this.calories,
    this.nutrition,
    this.ingredients,
    this.instructions,
    this.tags,
    this.tips,
    this.error,
  });

  factory RecipeResult.fromJson(String jsonStr) {
    try {
      String cleanJson = jsonStr;
      if (jsonStr.contains('```json')) {
        cleanJson = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        cleanJson = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> json = jsonDecode(cleanJson);

      if (json.containsKey('error')) {
        return RecipeResult(error: json['error']);
      }

      final nutritionMap = json['nutrition'] as Map<String, dynamic>?;
      final ingredientsList = (json['ingredients'] as List?)
          ?.map(
            (i) => RecipeIngredient(
              name: i['name'] ?? '',
              amount: i['amount'] ?? '',
              notes: i['notes'],
            ),
          )
          .toList();

      return RecipeResult(
        title: json['title'],
        description: json['description'],
        prepTime: json['prepTime'],
        cookTime: json['cookTime'],
        servings: json['servings'],
        difficulty: json['difficulty'],
        calories: json['calories'],
        nutrition: nutritionMap,
        ingredients: ingredientsList,
        instructions: (json['instructions'] as List?)?.cast<String>(),
        tags: (json['tags'] as List?)?.cast<String>(),
        tips: json['tips'],
      );
    } catch (e) {
      return RecipeResult(error: 'Failed to parse recipe: $e');
    }
  }

  bool get hasError => error != null;
  int get totalTime => (prepTime ?? 0) + (cookTime ?? 0);
}

class RecipeIngredient {
  final String name;
  final String amount;
  final String? notes;

  RecipeIngredient({required this.name, required this.amount, this.notes});
}

/// Result from document analysis
class DocumentAnalysisResult {
  final String documentType;
  final bool isValid;
  final Map<String, String> extractedInfo;
  final String? summary;
  final String? error;

  DocumentAnalysisResult({
    this.documentType = 'Unknown',
    this.isValid = false,
    this.extractedInfo = const {},
    this.summary,
    this.error,
  });

  factory DocumentAnalysisResult.fromJson(String jsonString) {
    try {
      // Clean up JSON string
      String cleaned = jsonString.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      }
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      if (json.containsKey('error')) {
        return DocumentAnalysisResult(error: json['error']);
      }

      final extractedInfo = <String, String>{};
      if (json['extractedInfo'] != null) {
        (json['extractedInfo'] as Map<String, dynamic>).forEach((key, value) {
          extractedInfo[key] = value.toString();
        });
      }

      return DocumentAnalysisResult(
        documentType: json['documentType'] ?? 'Unknown',
        isValid: json['isValid'] ?? false,
        extractedInfo: extractedInfo,
        summary: json['summary'],
      );
    } catch (e) {
      return DocumentAnalysisResult(error: 'Failed to parse analysis: $e');
    }
  }
}

/// Result from photo verification
class PhotoVerificationResult {
  final bool isSameDog;
  final double confidence;
  final List<String> matchingFeatures;
  final List<String> differences;
  final String reason;

  PhotoVerificationResult({
    required this.isSameDog,
    required this.confidence,
    required this.matchingFeatures,
    required this.differences,
    required this.reason,
  });

  bool get isHighConfidence => confidence >= 0.8;
  bool get isLowConfidence => confidence < 0.5;
}

/// Result from pet fact generation
class PetFactResult {
  final String shortFact;
  final String fullFact;
  final String category;
  final String shareText;
  final bool isBreedSpecific;

  PetFactResult({
    required this.shortFact,
    required this.fullFact,
    required this.category,
    required this.shareText,
    required this.isBreedSpecific,
  });

  factory PetFactResult.fallback(String breed) {
    final facts = [
      PetFactResult(
        shortFact: 'Dogs dream just like humans! 💭',
        fullFact:
            'Dogs experience REM sleep and dream just like humans. You might see their paws twitch or hear soft barks while they sleep.',
        category: 'behavior',
        shareText:
            '🐕 Did you know? Dogs dream just like us! #PetPal #DogFacts',
        isBreedSpecific: false,
      ),
      PetFactResult(
        shortFact: 'Dogs can smell emotions! 👃',
        fullFact:
            'Dogs can detect changes in human body chemistry, including the hormones released when we\'re happy, sad, or scared.',
        category: 'health',
        shareText: '🐕 Amazing! Dogs can actually smell your emotions #PetPal',
        isBreedSpecific: false,
      ),
      PetFactResult(
        shortFact: 'Dog noses are unique! 🐾',
        fullFact:
            'A dog\'s nose print is as unique as a human fingerprint. No two dogs have the same nose print pattern!',
        category: 'fun',
        shareText:
            '🐕 Fun Fact: Dog nose prints are like fingerprints! #PetPal',
        isBreedSpecific: false,
      ),
    ];
    return facts[DateTime.now().minute % facts.length];
  }
}

/// Enhanced recipe result with pricing and context (Recipe System v2.0)
class EnhancedRecipeResult {
  final String? name;
  final String? story;
  final String? category;
  final String? difficulty;
  final int? servings;
  final int? prepTime;
  final int? cookTime;
  final List<EnhancedIngredient>? ingredients;
  final List<EnhancedInstruction>? instructions;
  final Map<String, dynamic>? nutrition;
  final double? totalCostINR;
  final List<String>? tags;
  final String? seasonality;
  final String? whySpecial;
  final String? dogReactions;
  final String? error;

  EnhancedRecipeResult({
    this.name,
    this.story,
    this.category,
    this.difficulty,
    this.servings,
    this.prepTime,
    this.cookTime,
    this.ingredients,
    this.instructions,
    this.nutrition,
    this.totalCostINR,
    this.tags,
    this.seasonality,
    this.whySpecial,
    this.dogReactions,
    this.error,
  });

  bool get hasError => error != null;
  int get totalTime => (prepTime ?? 0) + (cookTime ?? 0);

  factory EnhancedRecipeResult.fromJson(String jsonString) {
    try {
      String cleaned = jsonString.trim();
      if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
      if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
      if (cleaned.endsWith('```'))
        cleaned = cleaned.substring(0, cleaned.length - 3);
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      if (json.containsKey('error')) {
        return EnhancedRecipeResult(error: json['error']);
      }

      final ingredientsList = (json['ingredients'] as List?)
          ?.map((i) => EnhancedIngredient.fromJson(i))
          .toList();

      final instructionsList = (json['instructions'] as List?)
          ?.map((i) => EnhancedInstruction.fromJson(i))
          .toList();

      return EnhancedRecipeResult(
        name: json['name'],
        story: json['story'],
        category: json['category'],
        difficulty: json['difficulty'],
        servings: json['servings'],
        prepTime: json['timing']?['prepTime'] ?? json['prepTime'],
        cookTime: json['timing']?['cookTime'] ?? json['cookTime'],
        ingredients: ingredientsList,
        instructions: instructionsList,
        nutrition: json['nutrition'],
        totalCostINR: (json['totalCostINR'] as num?)?.toDouble(),
        tags: (json['tags'] as List?)?.cast<String>(),
        seasonality: json['seasonality'],
        whySpecial: json['whySpecial'],
        dogReactions: json['dogReactions'],
      );
    } catch (e) {
      return EnhancedRecipeResult(error: 'Failed to parse recipe: $e');
    }
  }
}

class EnhancedIngredient {
  final String name;
  final double quantity;
  final String unit;
  final double? estimatedPriceINR;
  final String availability;
  final List<String> substitutes;
  final bool optional;
  final String? notes;

  EnhancedIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.estimatedPriceINR,
    this.availability = 'high',
    this.substitutes = const [],
    this.optional = false,
    this.notes,
  });

  factory EnhancedIngredient.fromJson(Map<String, dynamic> json) {
    return EnhancedIngredient(
      name: json['name'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? '',
      estimatedPriceINR: (json['estimated_price_inr'] as num?)?.toDouble(),
      availability: json['availability'] ?? 'high',
      substitutes: (json['substitutes'] as List?)?.cast<String>() ?? [],
      optional: json['optional'] ?? false,
      notes: json['notes'],
    );
  }
}

class EnhancedInstruction {
  final int step;
  final String instruction;
  final int timeMinutes;
  final String? tips;
  final bool requiresTimer;

  EnhancedInstruction({
    required this.step,
    required this.instruction,
    this.timeMinutes = 5,
    this.tips,
    this.requiresTimer = false,
  });

  factory EnhancedInstruction.fromJson(Map<String, dynamic> json) {
    return EnhancedInstruction(
      step: json['step'] ?? 1,
      instruction: json['instruction'] ?? '',
      timeMinutes: json['timeMinutes'] ?? 5,
      tips: json['tips'],
      requiresTimer: json['requiresTimer'] ?? false,
    );
  }
}

/// Nutrition analysis result
class NutritionAnalysisResult {
  final bool? aafcoCompliant;
  final String? aafcoExplanation;
  final List<String>? missingNutrients;
  final int? overallHealthScore;
  final String? recommendation;
  final List<String>? benefits;
  final List<String>? concerns;
  final List<String>? suggestedModifications;
  final int? confidenceLevel;
  final String? error;

  NutritionAnalysisResult({
    this.aafcoCompliant,
    this.aafcoExplanation,
    this.missingNutrients,
    this.overallHealthScore,
    this.recommendation,
    this.benefits,
    this.concerns,
    this.suggestedModifications,
    this.confidenceLevel,
    this.error,
  });

  bool get hasError => error != null;

  factory NutritionAnalysisResult.fromJson(String jsonString) {
    try {
      String cleaned = jsonString.trim();
      if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
      if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
      if (cleaned.endsWith('```'))
        cleaned = cleaned.substring(0, cleaned.length - 3);
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      if (json.containsKey('error')) {
        return NutritionAnalysisResult(error: json['error']);
      }

      final aafco = json['aafco_compliance'] as Map<String, dynamic>?;

      return NutritionAnalysisResult(
        aafcoCompliant: aafco?['compliant'],
        aafcoExplanation: aafco?['explanation'],
        missingNutrients: (aafco?['missing_nutrients'] as List?)
            ?.cast<String>(),
        overallHealthScore: json['overall_health_score'],
        recommendation: json['recommendation'],
        benefits: (json['benefits'] as List?)?.cast<String>(),
        concerns: (json['concerns'] as List?)?.cast<String>(),
        suggestedModifications: (json['suggested_modifications'] as List?)
            ?.cast<String>(),
        confidenceLevel: json['confidence_level'],
      );
    } catch (e) {
      return NutritionAnalysisResult(error: 'Failed to parse analysis: $e');
    }
  }
}

/// Cooking guidance result
class CookingGuidanceResult {
  final String? immediateGuidance;
  final String? visualCues;
  final String? timingEstimate;
  final List<String>? expertTips;
  final List<String>? mistakesToAvoid;
  final String? nextMilestone;
  final String? safetyAlert;
  final String? error;

  CookingGuidanceResult({
    this.immediateGuidance,
    this.visualCues,
    this.timingEstimate,
    this.expertTips,
    this.mistakesToAvoid,
    this.nextMilestone,
    this.safetyAlert,
    this.error,
  });

  bool get hasError => error != null;

  factory CookingGuidanceResult.fromJson(String jsonString) {
    try {
      String cleaned = jsonString.trim();
      if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
      if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
      if (cleaned.endsWith('```'))
        cleaned = cleaned.substring(0, cleaned.length - 3);
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      if (json.containsKey('error')) {
        return CookingGuidanceResult(error: json['error']);
      }

      return CookingGuidanceResult(
        immediateGuidance: json['immediate_guidance'],
        visualCues: json['visual_cues'],
        timingEstimate: json['timing_estimate'],
        expertTips: (json['expert_tips'] as List?)?.cast<String>(),
        mistakesToAvoid: (json['mistakes_to_avoid'] as List?)?.cast<String>(),
        nextMilestone: json['next_milestone'],
        safetyAlert: json['safety_alert'],
      );
    } catch (e) {
      return CookingGuidanceResult(error: 'Failed to parse guidance: $e');
    }
  }
}
