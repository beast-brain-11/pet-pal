// Health Consultation Providers
// Riverpod state management for AI health consultations

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_consultation_models.dart';
import '../../../core/services/mem0_service.dart';
import '../../../core/services/firestore_service.dart';

/// Current consultation mode selection
final selectedModeProvider = StateProvider<ConsultationMode?>((ref) => null);

/// Whether a consultation is currently active
final isConsultationActiveProvider = StateProvider<bool>((ref) => false);

/// Whether audio is currently being recorded
final isRecordingProvider = StateProvider<bool>((ref) => false);

/// Active consultation session
final activeSessionProvider =
    StateNotifierProvider<ActiveSessionNotifier, ConsultationSession?>((ref) {
      return ActiveSessionNotifier(ref);
    });

/// Consultation history for the current dog
final consultationHistoryProvider =
    FutureProvider.family<List<ConsultationHistoryItem>, String>((
      ref,
      dogId,
    ) async {
      final firestoreService = ref.watch(firestoreServiceProvider);
      try {
        final consultations = await firestoreService.getConsultationHistory(
          dogId,
        );
        return consultations
            .map(
              (c) => ConsultationHistoryItem.fromSession(
                ConsultationSession.fromJson(c),
              ),
            )
            .toList();
      } catch (e) {
        print('Error loading consultation history: $e');
        return [];
      }
    });

/// Manages the active consultation session
class ActiveSessionNotifier extends StateNotifier<ConsultationSession?> {
  final Ref ref;
  final Mem0Service _mem0 = Mem0Service();

  ActiveSessionNotifier(this.ref) : super(null);

  /// Start a new consultation session
  void startSession({required String dogId, required ConsultationMode mode}) {
    state = ConsultationSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dogId: dogId,
      mode: mode,
      messages: [
        // Initial AI greeting
        ConsultationMessage.assistant(text: _getGreetingMessage(mode)),
      ],
      startedAt: DateTime.now(),
      isActive: true,
    );

    ref.read(isConsultationActiveProvider.notifier).state = true;
    ref.read(selectedModeProvider.notifier).state = mode;
  }

  /// Add a user message to the session
  void addUserMessage({
    required String text,
    String? imageUrl,
    String? audioUrl,
  }) {
    if (state == null) return;

    state = state!.copyWith(
      messages: [
        ...state!.messages,
        ConsultationMessage.user(
          text: text,
          imageUrl: imageUrl,
          audioUrl: audioUrl,
        ),
      ],
    );
  }

  /// Add an AI response message (can be streaming)
  void addAiMessage({required String text, bool isStreaming = false}) {
    if (state == null) return;

    state = state!.copyWith(
      messages: [
        ...state!.messages,
        ConsultationMessage.assistant(text: text, isStreaming: isStreaming),
      ],
    );
  }

  /// Update the last AI message (for streaming)
  void updateLastAiMessage(String newText) {
    if (state == null || state!.messages.isEmpty) return;

    final messages = List<ConsultationMessage>.from(state!.messages);
    final lastIndex = messages.length - 1;

    if (messages[lastIndex].role == 'assistant') {
      messages[lastIndex] = messages[lastIndex].copyWith(
        text: newText,
        isStreaming: false,
      );
      state = state!.copyWith(messages: messages);
    }
  }

  /// End the consultation and save to Firebase/Mem0
  Future<void> endSession({ConsultationSummary? summary}) async {
    if (state == null) return;

    final endedSession = state!.copyWith(
      endedAt: DateTime.now(),
      isActive: false,
      summary: summary,
    );

    // Save to Firebase
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.saveConsultation(endedSession.toJson());
      print('DEBUG: Consultation saved to Firebase');
    } catch (e) {
      print('Error saving consultation to Firebase: $e');
    }

    // Save to Mem0 for memory persistence
    try {
      final messages = state!.messages
          .map((m) => {'role': m.role, 'content': m.text ?? ''})
          .toList();

      if (messages.length > 1) {
        await _mem0.addMemory(
          dogId: state!.dogId,
          messages: messages
              .map((m) => m.map((k, v) => MapEntry(k, v.toString())))
              .toList(),
          metadata: {
            'consultation_type': state!.mode.name,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        print('DEBUG: Consultation saved to Mem0');
      }
    } catch (e) {
      print('Error saving to Mem0: $e');
    }

    state = null;
    ref.read(isConsultationActiveProvider.notifier).state = false;
    ref.read(selectedModeProvider.notifier).state = null;
  }

  String _getGreetingMessage(ConsultationMode mode) {
    switch (mode) {
      case ConsultationMode.video:
        return "Hello! I'm your AI Vet Assistant 🐕\n\n"
            "I can see what you show me! Please point your camera at your pet "
            "so I can help assess their condition. You can also describe what's happening.";
      case ConsultationMode.voice:
        return "Hello! I'm your AI Vet Assistant 🐕\n\n"
            "I'm here to help with your pet's health. "
            "Tap the microphone and tell me what's going on with your furry friend.";
      case ConsultationMode.text:
        return "Hello! I'm your AI Vet Assistant powered by Gemini 🐕\n\n"
            "How can I help you with your furry friend today? "
            "Tell me about any symptoms or concerns you've noticed.";
      case ConsultationMode.emergency:
        return "⚠️ EMERGENCY MODE ACTIVATED\n\n"
            "I'm here to help immediately. "
            "Please describe what's happening as quickly as possible. "
            "If your pet is in immediate danger, call your emergency vet NOW.";
    }
  }
}

/// Provider to get relevant memory context for a query
final memoryContextProvider =
    FutureProvider.family<String, ({String dogId, String query})>((
      ref,
      params,
    ) async {
      final mem0 = Mem0Service();
      return await mem0.getMemoryContext(
        dogId: params.dogId,
        currentQuery: params.query,
      );
    });
