// Consultation Screen - Active AI Health Consultation
// Handles text, voice, video, and emergency consultation modes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petpal/core/constants/app_colors.dart';
import 'package:petpal/core/services/firestore_service.dart';
import 'package:petpal/core/services/gemini_service.dart';
import 'package:petpal/core/services/mem0_service.dart';
import 'package:petpal/features/health/models/health_consultation_models.dart';
import 'package:petpal/features/health/providers/health_consultation_provider.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  final String dogId;
  final String dogName;
  final ConsultationMode mode;

  const ConsultationScreen({
    super.key,
    required this.dogId,
    required this.dogName,
    required this.mode,
  });

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final Mem0Service _mem0Service = Mem0Service();

  bool _isProcessing = false;
  bool _isRecording = false;
  String _streamingText = '';
  Map<String, dynamic> _healthContext = {};

  @override
  void initState() {
    super.initState();
    _loadHealthContext();
  }

  Future<void> _loadHealthContext() async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final context = await firestoreService.getDogHealthContext(widget.dogId);
    setState(() {
      _healthContext = context;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    _messageController.clear();

    // Add user message
    ref
        .read(activeSessionProvider.notifier)
        .addUserMessage(
          text: text.isNotEmpty ? text : 'Sent an image',
          imageUrl: imageUrl,
        );
    _scrollToBottom();

    setState(() {
      _isProcessing = true;
      _streamingText = '';
    });

    try {
      // Get relevant memories from Mem0
      final memoryContext = await _mem0Service.getMemoryContext(
        dogId: widget.dogId,
        currentQuery: text,
      );

      // Stream response from Gemini with full context
      final stream = _geminiService.streamHealthConsultation(
        userMessage: text,
        dogName: _healthContext['name'] ?? widget.dogName,
        breed: _healthContext['breed'] ?? '',
        age: _healthContext['ageGroup'] ?? 'adult',
        consultationType: widget.mode.name,
        healthContext: _healthContext,
        memoryContext: memoryContext,
      );

      await for (final chunk in stream) {
        setState(() {
          _streamingText += chunk;
        });
        _scrollToBottom();
      }

      // Add completed AI message
      ref
          .read(activeSessionProvider.notifier)
          .addAiMessage(text: _streamingText);
    } catch (e) {
      ref
          .read(activeSessionProvider.notifier)
          .addAiMessage(
            text: 'Sorry, I encountered an error. Please try again.',
          );
    }

    setState(() {
      _isProcessing = false;
      _streamingText = '';
    });
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      // For now, just send a note about the image
      _messageController.text = 'I\'m showing you a photo of my dog';
      await _sendMessage(imageUrl: image.path);
    }
  }

  Future<void> _endConsultation() async {
    // Generate summary if there are messages
    final session = ref.read(activeSessionProvider);
    if (session != null && session.messages.length > 2) {
      final summary = ConsultationSummary(
        summary: 'Health consultation completed',
        keyFindings: [],
        severityLevel: 'LOW',
      );
      await ref
          .read(activeSessionProvider.notifier)
          .endSession(summary: summary);
    } else {
      await ref.read(activeSessionProvider.notifier).endSession();
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final messages = session?.messages ?? [];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isProcessing && index == messages.length) {
                  return _buildStreamingMessage();
                }
                return _buildMessageBubble(messages[index]);
              },
            ),
          ),

          // Disclaimer
          _buildDisclaimer(),

          // Input Section
          _buildInputSection(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final modeColors = {
      ConsultationMode.video: const Color(0xFFEC4899),
      ConsultationMode.voice: const Color(0xFF3B82F6),
      ConsultationMode.text: const Color(0xFF06B6D4),
      ConsultationMode.emergency: const Color(0xFFEF4444),
    };

    return AppBar(
      backgroundColor: modeColors[widget.mode] ?? AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: _endConsultation,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.mode.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'For: ${widget.dogName}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.mode == ConsultationMode.emergency)
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              // TODO: Call emergency vet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency vet calling feature coming soon'),
                ),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: () => _showInfoSheet(),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ConsultationMessage message) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.pets, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (message.text != null && message.text!.isNotEmpty)
                    Text(
                      message.text!,
                      style: TextStyle(
                        color: isUser ? Colors.white : AppColors.black,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.greyLight,
              child: const Icon(Icons.person, size: 18, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.pets, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: _streamingText.isEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypingDot(0),
                        const SizedBox(width: 4),
                        _buildTypingDot(1),
                        const SizedBox(width: 4),
                        _buildTypingDot(2),
                      ],
                    )
                  : Text(
                      _streamingText,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.grey.withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: widget.mode == ConsultationMode.emergency
          ? Colors.red.shade50
          : AppColors.healthYellow.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            widget.mode == ConsultationMode.emergency
                ? Icons.warning_amber
                : Icons.info_outline,
            color: widget.mode == ConsultationMode.emergency
                ? Colors.red
                : AppColors.healthYellow.withValues(alpha: 0.8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.mode == ConsultationMode.emergency
                  ? 'For life-threatening emergencies, call your vet immediately!'
                  : 'AI advice is not a substitute for professional veterinary care.',
              style: TextStyle(
                color: widget.mode == ConsultationMode.emergency
                    ? Colors.red
                    : AppColors.grey,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    switch (widget.mode) {
      case ConsultationMode.video:
        return _buildVideoInput();
      case ConsultationMode.voice:
        return _buildVoiceInput();
      case ConsultationMode.text:
        return _buildTextInput();
      case ConsultationMode.emergency:
        return _buildEmergencyInput();
    }
  }

  Widget _buildTextInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image, color: AppColors.primary),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Describe symptoms...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.greyLight.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
              enabled: !_isProcessing,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              color: Colors.white,
              onPressed: _isProcessing ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isRecording)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recording...',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isRecording = !_isRecording;
                  });
                  if (!_isRecording) {
                    // Voice recording complete - for now just use text input
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Voice recording complete. Use the text input below.',
                        ),
                      ),
                    );
                  }
                },
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Stop' : 'Start Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording
                      ? Colors.red
                      : const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Or type your message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.greyLight.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: AppColors.primary),
                onPressed: _isProcessing ? null : () => _sendMessage(),
              ),
            ),
            onSubmitted: (_) => _sendMessage(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.camera_alt,
              color: Color(0xFFEC4899),
              size: 28,
            ),
            onPressed: _pickImage,
          ),
          IconButton(
            icon: const Icon(Icons.photo, color: Color(0xFFEC4899), size: 28),
            onPressed: () async {
              final picker = ImagePicker();
              final image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                _messageController.text = 'I\'m showing you a photo of my dog';
                await _sendMessage(imageUrl: image.path);
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Describe what you see...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.greyLight.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFEC4899),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send),
              color: Colors.white,
              onPressed: _isProcessing ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: const Border(top: BorderSide(color: Colors.red, width: 2)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'What\'s happening right now?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Emergency vet calling feature coming soon',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Emergency Vet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _sendMessage(),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.medical_services),
                  label: const Text('Get First Aid'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInfoSheet() {
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.pets, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              widget.dogName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_healthContext.isNotEmpty) ...[
              _buildInfoRow('Breed', _healthContext['breed'] ?? 'Unknown'),
              _buildInfoRow('Age', _healthContext['ageGroup'] ?? 'Unknown'),
              _buildInfoRow('Weight', '${_healthContext['weight'] ?? 0} lbs'),
              if ((_healthContext['allergies'] as List?)?.isNotEmpty ?? false)
                _buildInfoRow(
                  'Allergies',
                  (_healthContext['allergies'] as List).join(', '),
                ),
              if ((_healthContext['medications'] as List?)?.isNotEmpty ?? false)
                _buildInfoRow(
                  'Medications',
                  (_healthContext['medications'] as List).join(', '),
                ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greyLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI responses are personalized based on this profile and your past consultations.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
