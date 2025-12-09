// AI Health Chat Page - WhatsApp-style unified chat UI
// Real-time voice mode with Gemini Live API

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petpal/core/constants/app_colors.dart';
import 'package:petpal/core/services/firestore_service.dart';
import 'package:petpal/core/services/health_api_service.dart';
import 'package:petpal/core/services/mem0_service.dart';
import 'package:petpal/core/services/live_voice_service.dart';
import 'package:petpal/features/health/models/health_consultation_models.dart';
import 'package:petpal/features/health/presentation/pages/voice_call_page.dart';

class AIHealthPage extends ConsumerStatefulWidget {
  const AIHealthPage({super.key});

  @override
  ConsumerState<AIHealthPage> createState() => _AIHealthPageState();
}

class _AIHealthPageState extends ConsumerState<AIHealthPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final HealthApiService _healthApi = HealthApiService();
  final Mem0Service _mem0Service = Mem0Service();

  String? _dogId;
  String _dogName = 'Your Dog';
  String _dogBreed = '';
  Map<String, dynamic> _healthContext = {};

  final List<_ChatMessage> _messages = [];
  bool _isProcessing = false;
  ConsultationMode _currentMode = ConsultationMode.text;
  bool _backendHealthy = false;

  // Voice mode
  final LiveVoiceService _voiceService = LiveVoiceService();
  bool _isVoiceConnected = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _loadDogProfile();
    _checkBackend();
    _addWelcomeMessage();
  }

  Future<void> _checkBackend() async {
    final healthy = await _healthApi.isBackendHealthy();
    if (mounted) {
      setState(() => _backendHealthy = healthy);
    }
  }

  void _addWelcomeMessage() {
    _messages.add(
      _ChatMessage(
        text:
            "Hi! 👋 I'm your AI Vet Assistant. How can I help with your furry friend today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _loadDogProfile() async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final dogId = await firestoreService.getCurrentDogId();
    if (dogId != null) {
      final dog = await firestoreService.getDogProfile(dogId);
      final context = await firestoreService.getDogHealthContext(dogId);
      if (dog != null && mounted) {
        setState(() {
          _dogId = dogId;
          _dogName = dog.name;
          _dogBreed = dog.breed;
          _healthContext = context;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
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
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text.isNotEmpty ? text : '📷 Sent a photo',
          isUser: true,
          timestamp: DateTime.now(),
          imageUrl: imageUrl,
        ),
      );
      _isProcessing = true;
    });
    _scrollToBottom();

    try {
      // Get memory context from Mem0
      String memoryContext = '';
      if (_dogId != null) {
        try {
          memoryContext = await _mem0Service.getMemoryContext(
            dogId: _dogId!,
            currentQuery: text,
          );
        } catch (e) {
          // Memory context is optional
        }
      }

      // Call backend API
      final response = await _healthApi.textConsultation(
        message: text,
        dogName: _dogName,
        dogBreed: _dogBreed,
        dogAge: _healthContext['ageGroup'] ?? 'adult',
        healthContext: _healthContext,
        memoryContext: memoryContext,
        consultationType: _currentMode.name,
      );

      // Add AI response
      setState(() {
        _messages.add(
          _ChatMessage(
            text: _cleanResponse(response),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isProcessing = false;
      });

      // Store to Mem0 for future context
      if (_dogId != null) {
        try {
          await _mem0Service.addMemory(
            dogId: _dogId!,
            messages: [
              {'role': 'user', 'content': text},
              {'role': 'assistant', 'content': response},
            ],
          );
        } catch (e) {
          // Memory storage is optional
        }
      }
    } catch (e) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Sorry, I had trouble responding. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isProcessing = false;
      });
    }
    _scrollToBottom();
  }

  String _cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'\*'), '')
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .trim();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      _messageController.text = "Can you look at this and help me?";
      await _sendMessage(imageUrl: image.path);
    }
  }

  Future<void> _startVoiceMode() async {
    // Navigate to full-screen voice call page (Gemini Live style)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VoiceCallPage(dogId: _dogId ?? 'default', dogName: _dogName),
      ),
    );

    // Add transcripts from voice call to chat history
    if (result != null && result is List<TranscriptMessage>) {
      for (final msg in result) {
        _messages.add(
          _ChatMessage(
            text: msg.text,
            isUser: msg.isUser,
            timestamp: msg.timestamp,
          ),
        );
      }
      setState(() {});
      _scrollToBottom();
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _voiceService.stopRecording();
    } else {
      await _voiceService.startRecording();
    }
  }

  Future<void> _stopVoiceMode() async {
    await _voiceService.disconnect();
    setState(() {
      _isVoiceConnected = false;
      _isRecording = false;
      _currentMode = ConsultationMode.text;
    });
  }

  void _startVideoMode() {
    setState(() => _currentMode = ConsultationMode.video);
    _messages.add(
      _ChatMessage(
        text:
            '📹 Video Mode Active\n\n'
            'Tap the camera icon to take a photo of your pet, '
            'then describe what concerns you.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    setState(() {});
    _scrollToBottom();
  }

  void _startEmergencyMode() {
    setState(() => _currentMode = ConsultationMode.emergency);
    _messages.add(
      _ChatMessage(
        text:
            '🚨 EMERGENCY MODE ACTIVE\n\n'
            'If your pet is in immediate danger:\n'
            '• Call your emergency vet NOW\n'
            '• Keep pet calm and still\n'
            '• Don\'t give food/water unless instructed\n\n'
            'Describe what\'s happening for first aid guidance.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    setState(() {});
    _scrollToBottom();
  }

  void _resetToTextMode() {
    _stopVoiceMode();
    setState(() => _currentMode = ConsultationMode.text);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Switched to text mode')));
  }

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 35,
              backgroundColor: AppColors.primary,
              child: Text(
                _dogName.isNotEmpty ? _dogName[0].toUpperCase() : '🐕',
                style: const TextStyle(fontSize: 28, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _dogName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(_dogBreed, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            _infoRow('Backend', _backendHealthy ? '✅ Connected' : '❌ Offline'),
            _infoRow('Mode', _currentMode.title),
            if (_healthContext.isNotEmpty) ...[
              _infoRow(
                'Weight',
                '${_healthContext['weight'] ?? 'Unknown'} lbs',
              ),
              _infoRow('Age', _healthContext['ageGroup'] ?? 'Unknown'),
              if ((_healthContext['allergies'] as List?)?.isNotEmpty ?? false)
                _infoRow(
                  'Allergies',
                  (_healthContext['allergies'] as List).join(', '),
                ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Mode indicator
          if (_currentMode != ConsultationMode.text) _buildModeIndicator(),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isProcessing && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Disclaimer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: _currentMode == ConsultationMode.emergency
                ? Colors.red.shade50
                : Colors.amber.shade50,
            child: Row(
              children: [
                Icon(
                  _currentMode == ConsultationMode.emergency
                      ? Icons.warning
                      : Icons.info_outline,
                  size: 14,
                  color: _currentMode == ConsultationMode.emergency
                      ? Colors.red
                      : Colors.amber.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _currentMode == ConsultationMode.emergency
                        ? 'For life-threatening emergencies, call your vet immediately!'
                        : 'AI advice isn\'t a substitute for professional vet care',
                    style: TextStyle(
                      fontSize: 11,
                      color: _currentMode == ConsultationMode.emergency
                          ? Colors.red
                          : Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Input
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildModeIndicator() {
    final colors = {
      ConsultationMode.voice: Colors.blue,
      ConsultationMode.video: Colors.pink,
      ConsultationMode.emergency: Colors.red,
    };
    final icons = {
      ConsultationMode.voice: Icons.mic,
      ConsultationMode.video: Icons.videocam,
      ConsultationMode.emergency: Icons.emergency,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colors[_currentMode]?.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icons[_currentMode], color: colors[_currentMode], size: 18),
          const SizedBox(width: 8),
          Text(
            '${_currentMode.title} Active',
            style: TextStyle(
              color: colors[_currentMode],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _resetToTextMode,
            child: Text(
              'Switch to Text',
              style: TextStyle(
                color: colors[_currentMode],
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _currentMode == ConsultationMode.emergency
          ? Colors.red
          : AppColors.primary,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(
              _currentMode == ConsultationMode.emergency
                  ? Icons.emergency
                  : Icons.pets,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentMode == ConsultationMode.emergency
                    ? '🚨 Emergency'
                    : 'AI Vet',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _backendHealthy
                          ? const Color(0xFF4ADE80)
                          : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _backendHealthy ? 'Online • $_dogName' : 'Connecting...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.call,
            color: _currentMode == ConsultationMode.voice
                ? Colors.yellow
                : Colors.white,
            size: 22,
          ),
          onPressed: _startVoiceMode,
          tooltip: 'Voice Mode',
        ),
        IconButton(
          icon: Icon(
            Icons.videocam,
            color: _currentMode == ConsultationMode.video
                ? Colors.yellow
                : Colors.white,
            size: 22,
          ),
          onPressed: _startVideoMode,
          tooltip: 'Video Mode',
        ),
        IconButton(
          icon: Icon(
            Icons.emergency,
            color: _currentMode == ConsultationMode.emergency
                ? Colors.yellow
                : Colors.white,
            size: 22,
          ),
          onPressed: _startEmergencyMode,
          tooltip: 'Emergency',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
          onPressed: _showInfoSheet,
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 6,
          left: isUser ? 50 : 0,
          right: isUser ? 0 : 50,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? (_currentMode == ConsultationMode.emergency
                    ? Colors.red
                    : AppColors.primary)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
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
                  height: 120,
                  width: 180,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, color: Colors.grey, size: 40),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isUser ? Colors.white60 : Colors.black38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6, right: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 400 + index * 150),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    // Voice mode: show mic button
    if (_currentMode == ConsultationMode.voice && _isVoiceConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isRecording
                  ? '🔴 Recording... Release to send'
                  : 'Hold to speak',
              style: TextStyle(
                color: _isRecording ? Colors.red : Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTapDown: (_) => _toggleRecording(),
              onTapUp: (_) => _toggleRecording(),
              onTapCancel: () => _voiceService.stopRecording(),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : Colors.blue)
                          .withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: _isRecording ? 8 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Text/Video/Emergency mode: show text input
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.camera_alt,
              color: _currentMode == ConsultationMode.video
                  ? Colors.pink
                  : AppColors.primary,
            ),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _getInputHint(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isProcessing,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              color: _currentMode == ConsultationMode.emergency
                  ? Colors.red
                  : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, size: 20),
              color: Colors.white,
              onPressed: _isProcessing ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }

  String _getInputHint() {
    switch (_currentMode) {
      case ConsultationMode.emergency:
        return 'Describe the emergency...';
      case ConsultationMode.video:
        return 'Describe what you see...';
      case ConsultationMode.voice:
        return 'Type your question...';
      default:
        return 'Ask about your pet\'s health...';
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $amPm';
  }

  @override
  void dispose() {
    _voiceService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
  });
}
