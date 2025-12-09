// Health Consultation Models
// Data models for AI veterinary consultations

/// Consultation modes available for AI health assistance
enum ConsultationMode {
  video, // Video call with symptom showing
  voice, // Voice call consultation
  text, // Text chat (fastest)
  emergency, // Emergency mode with first aid
}

extension ConsultationModeExtension on ConsultationMode {
  String get title {
    switch (this) {
      case ConsultationMode.video:
        return 'Video Call AI Vet';
      case ConsultationMode.voice:
        return 'Voice Call AI Vet';
      case ConsultationMode.text:
        return 'Text Chat AI Vet';
      case ConsultationMode.emergency:
        return 'Emergency Mode';
    }
  }

  String get description {
    switch (this) {
      case ConsultationMode.video:
        return 'Show symptoms to AI';
      case ConsultationMode.voice:
        return 'Quick consultation';
      case ConsultationMode.text:
        return 'Fastest response';
      case ConsultationMode.emergency:
        return 'Quick dial & first aid guide';
    }
  }

  String get badge {
    switch (this) {
      case ConsultationMode.video:
        return 'Most recommended';
      case ConsultationMode.voice:
        return '';
      case ConsultationMode.text:
        return 'Fastest response';
      case ConsultationMode.emergency:
        return 'URGENT';
    }
  }
}

/// A single message in a consultation conversation
class ConsultationMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String? text;
  final String? audioUrl;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isStreaming;

  ConsultationMessage({
    required this.id,
    required this.role,
    this.text,
    this.audioUrl,
    this.imageUrl,
    required this.timestamp,
    this.isStreaming = false,
  });

  ConsultationMessage copyWith({
    String? id,
    String? role,
    String? text,
    String? audioUrl,
    String? imageUrl,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return ConsultationMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'text': text,
    'audioUrl': audioUrl,
    'imageUrl': imageUrl,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ConsultationMessage.fromJson(Map<String, dynamic> json) {
    return ConsultationMessage(
      id: json['id'] ?? '',
      role: json['role'] ?? 'user',
      text: json['text'],
      audioUrl: json['audioUrl'],
      imageUrl: json['imageUrl'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  /// Create a user message
  factory ConsultationMessage.user({
    required String text,
    String? imageUrl,
    String? audioUrl,
  }) {
    return ConsultationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      text: text,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      timestamp: DateTime.now(),
    );
  }

  /// Create an AI assistant message
  factory ConsultationMessage.assistant({
    required String text,
    bool isStreaming = false,
  }) {
    return ConsultationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      text: text,
      timestamp: DateTime.now(),
      isStreaming: isStreaming,
    );
  }
}

/// A complete consultation session
class ConsultationSession {
  final String id;
  final String dogId;
  final ConsultationMode mode;
  final List<ConsultationMessage> messages;
  final DateTime startedAt;
  final DateTime? endedAt;
  final ConsultationSummary? summary;
  final bool isActive;

  ConsultationSession({
    required this.id,
    required this.dogId,
    required this.mode,
    this.messages = const [],
    required this.startedAt,
    this.endedAt,
    this.summary,
    this.isActive = true,
  });

  ConsultationSession copyWith({
    String? id,
    String? dogId,
    ConsultationMode? mode,
    List<ConsultationMessage>? messages,
    DateTime? startedAt,
    DateTime? endedAt,
    ConsultationSummary? summary,
    bool? isActive,
  }) {
    return ConsultationSession(
      id: id ?? this.id,
      dogId: dogId ?? this.dogId,
      mode: mode ?? this.mode,
      messages: messages ?? this.messages,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      summary: summary ?? this.summary,
      isActive: isActive ?? this.isActive,
    );
  }

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dogId': dogId,
    'mode': mode.name,
    'messages': messages.map((m) => m.toJson()).toList(),
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'summary': summary?.toJson(),
    'isActive': isActive,
  };

  factory ConsultationSession.fromJson(Map<String, dynamic> json) {
    return ConsultationSession(
      id: json['id'] ?? '',
      dogId: json['dogId'] ?? '',
      mode: ConsultationMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => ConsultationMode.text,
      ),
      messages:
          (json['messages'] as List?)
              ?.map((m) => ConsultationMessage.fromJson(m))
              .toList() ??
          [],
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : DateTime.now(),
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
      summary: json['summary'] != null
          ? ConsultationSummary.fromJson(json['summary'])
          : null,
      isActive: json['isActive'] ?? false,
    );
  }
}

/// Summary generated at the end of a consultation
class ConsultationSummary {
  final String summary;
  final List<String> keyFindings;
  final List<String> diagnosisPossibilities;
  final List<String> immediateActions;
  final String followUp;
  final String whenToVet;
  final List<String> warningMonitor;
  final String severityLevel; // LOW, MODERATE, HIGH, CRITICAL

  ConsultationSummary({
    required this.summary,
    this.keyFindings = const [],
    this.diagnosisPossibilities = const [],
    this.immediateActions = const [],
    this.followUp = '',
    this.whenToVet = '',
    this.warningMonitor = const [],
    this.severityLevel = 'LOW',
  });

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'keyFindings': keyFindings,
    'diagnosisPossibilities': diagnosisPossibilities,
    'immediateActions': immediateActions,
    'followUp': followUp,
    'whenToVet': whenToVet,
    'warningMonitor': warningMonitor,
    'severityLevel': severityLevel,
  };

  factory ConsultationSummary.fromJson(Map<String, dynamic> json) {
    return ConsultationSummary(
      summary: json['summary'] ?? '',
      keyFindings: List<String>.from(json['keyFindings'] ?? []),
      diagnosisPossibilities: List<String>.from(
        json['diagnosisPossibilities'] ?? [],
      ),
      immediateActions: List<String>.from(json['immediateActions'] ?? []),
      followUp: json['followUp'] ?? '',
      whenToVet: json['whenToVet'] ?? '',
      warningMonitor: List<String>.from(json['warningMonitor'] ?? []),
      severityLevel: json['severityLevel'] ?? 'LOW',
    );
  }
}

/// Consultation history item for display
class ConsultationHistoryItem {
  final String id;
  final ConsultationMode mode;
  final DateTime date;
  final String preview;
  final String? severityLevel;

  ConsultationHistoryItem({
    required this.id,
    required this.mode,
    required this.date,
    required this.preview,
    this.severityLevel,
  });

  factory ConsultationHistoryItem.fromSession(ConsultationSession session) {
    String preview = 'No messages';
    if (session.messages.isNotEmpty) {
      final lastAiMessage = session.messages.lastWhere(
        (m) => m.role == 'assistant',
        orElse: () => session.messages.last,
      );
      preview = lastAiMessage.text ?? 'No response';
      if (preview.length > 80) {
        preview = '${preview.substring(0, 80)}...';
      }
    }

    return ConsultationHistoryItem(
      id: session.id,
      mode: session.mode,
      date: session.startedAt,
      preview: preview,
      severityLevel: session.summary?.severityLevel,
    );
  }
}
