// Health API Service - Calls PetPal backend on HuggingFace Spaces
// For text, voice, and video health consultations via WebSocket

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class HealthApiService {
  static const String _baseUrl = 'https://priaansh-petpal-ai-backend.hf.space';
  static const String _wsBaseUrl = 'wss://priaansh-petpal-ai-backend.hf.space';

  WebSocketChannel? _channel;

  /// Health check
  Future<bool> isBackendHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ok';
      }
      return false;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  /// Connect to consultation WebSocket
  Future<bool> connectConsultation({
    required Function(String text) onResponse,
    required Function(String error) onError,
  }) async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsBaseUrl/ws/consultation'),
      );

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            if (data['type'] == 'response') {
              onResponse(data['text'] ?? '');
            } else if (data['type'] == 'error') {
              onError(data['message'] ?? 'Unknown error');
            } else if (data['type'] == 'connected') {
              print('WebSocket connected: ${data['message']}');
            }
          } catch (e) {
            print('Parse error: $e');
          }
        },
        onError: (error) {
          onError('Connection error: $error');
        },
        onDone: () {
          print('WebSocket closed');
        },
      );

      return true;
    } catch (e) {
      print('WebSocket connect error: $e');
      return false;
    }
  }

  /// Send message via WebSocket
  void sendMessage({
    required String message,
    required String dogId,
    required String consultationId,
    required String dogName,
    String dogBreed = '',
    String dogAge = 'adult',
    String dogWeight = '',
    String mode = 'text',
  }) {
    if (_channel == null) return;

    _channel!.sink.add(
      jsonEncode({
        'mode': mode,
        'message': message,
        'dog_id': dogId,
        'consultation_id': consultationId,
        'dog_name': dogName,
        'breed': dogBreed,
        'age': dogAge,
        'weight': dogWeight,
      }),
    );
  }

  /// Disconnect WebSocket
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  /// Text consultation via HTTP (fallback)
  Future<String> textConsultation({
    required String message,
    required String dogName,
    String dogBreed = '',
    String dogAge = 'adult',
    Map<String, dynamic>? healthContext,
    String? memoryContext,
    String consultationType = 'text',
  }) async {
    // Use WebSocket endpoint with HTTP fallback approach
    try {
      // For now, we'll use a simple approach: connect, send, wait for response, close
      final completer = Completer<String>();

      final connected = await connectConsultation(
        onResponse: (text) {
          if (!completer.isCompleted) {
            completer.complete(text);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.complete(
              'Sorry, I had trouble responding. Please try again.',
            );
          }
        },
      );

      if (!connected) {
        return 'Connection error. Please try again.';
      }

      // Send message
      sendMessage(
        message: message,
        dogId: 'default',
        consultationId: DateTime.now().millisecondsSinceEpoch.toString(),
        dogName: dogName,
        dogBreed: dogBreed,
        dogAge: dogAge,
        mode: consultationType,
      );

      // Wait for response with timeout
      final response = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => 'Request timed out. Please try again.',
      );

      disconnect();
      return response;
    } catch (e) {
      print('Consultation error: $e');
      disconnect();
      return 'Error: Please try again.';
    }
  }
}
