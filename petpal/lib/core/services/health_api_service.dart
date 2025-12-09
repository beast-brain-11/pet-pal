// Health API Service - Calls PetPal backend on HuggingFace Spaces
// For text, voice, and video health consultations

import 'dart:convert';
import 'package:http/http.dart' as http;

class HealthApiService {
  static const String _baseUrl = 'https://priaansh-petpal-ai-backend.hf.space';

  /// Text consultation via backend
  Future<String> textConsultation({
    required String message,
    required String dogName,
    String dogBreed = '',
    String dogAge = 'adult',
    Map<String, dynamic>? healthContext,
    String? memoryContext,
    String consultationType = 'text',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/health/text'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'dog_name': dogName,
              'dog_breed': dogBreed,
              'dog_age': dogAge,
              'health_context': healthContext ?? {},
              'memory_context': memoryContext ?? '',
              'consultation_type': consultationType,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'No response received';
      } else {
        return 'Sorry, I couldn\'t process that. Please try again.';
      }
    } catch (e) {
      print('Health API error: $e');
      return 'Connection error. Please check your internet and try again.';
    }
  }

  /// Health check
  Future<bool> isBackendHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy' &&
            data['api_key_configured'] == true;
      }
      return false;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  /// Get WebSocket URL for voice mode
  String getVoiceWebSocketUrl(String sessionId) {
    return 'wss://priaansh-petpal-ai-backend.hf.space/ws/voice/$sessionId';
  }

  /// Get WebSocket URL for video mode
  String getVideoWebSocketUrl(String sessionId) {
    return 'wss://priaansh-petpal-ai-backend.hf.space/ws/video/$sessionId';
  }
}
