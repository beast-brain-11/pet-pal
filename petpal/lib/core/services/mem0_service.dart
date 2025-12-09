// Mem0 Memory Service for PetPal
// Provides persistent AI memory layer for health consultations

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mem0 Memory Service - Manages AI memory for health consultations
/// Uses dog_id as user_id for per-dog memory namespace
class Mem0Service {
  static const String _baseUrl = 'https://api.mem0.ai/v1';
  static const String _apiKey = 'm0-7oUiXeMJ8qiHWSGfdwwgSnJO1YM0TgmjdMT2PSds';

  // Singleton instance
  static final Mem0Service _instance = Mem0Service._internal();
  factory Mem0Service() => _instance;
  Mem0Service._internal();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Token $_apiKey',
  };

  /// Add a memory from a consultation
  /// Stores symptoms, conditions, medications, and AI responses
  Future<bool> addMemory({
    required String dogId,
    required List<Map<String, String>> messages,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/memories/'),
        headers: _headers,
        body: jsonEncode({
          'messages': messages,
          'user_id': dogId, // Using dogId as user_id for per-dog namespace
          'metadata': metadata ?? {},
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('DEBUG Mem0: Memory added successfully for dog $dogId');
        return true;
      } else {
        print(
          'DEBUG Mem0: Failed to add memory - ${response.statusCode}: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('DEBUG Mem0: Error adding memory: $e');
      return false;
    }
  }

  /// Search for relevant memories based on query
  /// Returns top matches for context injection into Gemini prompts
  Future<List<MemoryItem>> searchMemories({
    required String dogId,
    required String query,
    int limit = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/memories/search/'),
        headers: _headers,
        body: jsonEncode({'query': query, 'user_id': dogId, 'limit': limit}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final memories = (data['results'] as List? ?? [])
            .map((m) => MemoryItem.fromJson(m))
            .toList();
        print('DEBUG Mem0: Found ${memories.length} relevant memories');
        return memories;
      } else {
        print(
          'DEBUG Mem0: Search failed - ${response.statusCode}: ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('DEBUG Mem0: Error searching memories: $e');
      return [];
    }
  }

  /// Get all memories for a dog
  Future<List<MemoryItem>> getAllMemories({required String dogId}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/memories/?user_id=$dogId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final memories = (data['results'] as List? ?? [])
            .map((m) => MemoryItem.fromJson(m))
            .toList();
        print('DEBUG Mem0: Retrieved ${memories.length} total memories');
        return memories;
      } else {
        print('DEBUG Mem0: Get memories failed - ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('DEBUG Mem0: Error getting memories: $e');
      return [];
    }
  }

  /// Store a consultation summary as a memory
  Future<bool> storeConsultationSummary({
    required String dogId,
    required String summary,
    required String consultationType,
    required List<String> symptoms,
    required List<String> recommendations,
  }) async {
    return addMemory(
      dogId: dogId,
      messages: [
        {'role': 'user', 'content': 'Health consultation summary: $summary'},
        {
          'role': 'assistant',
          'content':
              '''
Consultation Type: $consultationType
Symptoms Discussed: ${symptoms.join(', ')}
Recommendations: ${recommendations.join(', ')}
''',
        },
      ],
      metadata: {
        'type': 'consultation_summary',
        'consultation_type': consultationType,
        'symptoms': symptoms,
        'recommendations': recommendations,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get formatted memory context for Gemini prompt
  Future<String> getMemoryContext({
    required String dogId,
    required String currentQuery,
  }) async {
    final memories = await searchMemories(
      dogId: dogId,
      query: currentQuery,
      limit: 5,
    );

    if (memories.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('\n--- RELEVANT PAST HEALTH HISTORY ---');
    for (final memory in memories) {
      buffer.writeln('• ${memory.memory}');
    }
    buffer.writeln('--- END OF HISTORY ---\n');

    return buffer.toString();
  }
}

/// Represents a memory item from Mem0
class MemoryItem {
  final String id;
  final String memory;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final double? score;

  MemoryItem({
    required this.id,
    required this.memory,
    this.metadata = const {},
    this.createdAt,
    this.score,
  });

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] ?? '',
      memory: json['memory'] ?? '',
      metadata: json['metadata'] ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}
