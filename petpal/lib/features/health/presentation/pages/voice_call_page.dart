// Voice Call Page - Full-screen Gemini Live-style calling interface
// Connects DIRECTLY to Gemini WebSocket API (no backend middleware)

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:petpal/core/constants/app_colors.dart';

/// Transcript message
class TranscriptMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  TranscriptMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Full-screen voice call page - connects directly to Gemini Live API
class VoiceCallPage extends StatefulWidget {
  final String dogId;
  final String dogName;

  const VoiceCallPage({super.key, required this.dogId, required this.dogName});

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage>
    with SingleTickerProviderStateMixin {
  // TODO: Move API key to secure storage in production
  static const String _apiKey = 'AIzaSyDjDq4i2jCN6RwJCc1XgJFWMq9XvVNMVx0';
  static const String _model = 'gemini-2.0-flash-exp';

  // Gemini WebSocket URL
  String get _geminiWsUrl =>
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent'
      '?key=$_apiKey';

  // WebSocket
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  bool _isConnected = false;

  // Audio recording
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _audioStreamSubscription;
  bool _isRecording = false;
  bool _isPaused = false;

  // Audio playback
  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _audioQueue = [];
  bool _isPlaying = false;

  // Transcripts
  final List<TranscriptMessage> _transcripts = [];
  final ScrollController _scrollController = ScrollController();

  // Waveform visualization
  List<double> _waveformBars = List.generate(30, (_) => 0.2);
  Timer? _waveformTimer;

  // Call state
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initCall();
  }

  Future<void> _initCall() async {
    // Request permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    // Connect to Gemini
    await _connectToGemini();

    // Start duration timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });

    // Waveform animation
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_isRecording && !_isPaused && mounted) {
        setState(() {
          _waveformBars = List.generate(30, (i) {
            final base =
                0.2 +
                (0.6 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000);
            return base *
                (0.5 +
                    0.5 * ((i * 7 + DateTime.now().millisecond) % 100) / 100);
          });
        });
      }
    });
  }

  Future<void> _connectToGemini() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_geminiWsUrl));

      _wsSubscription = _channel!.stream.listen(
        _handleGeminiMessage,
        onError: (error) {
          debugPrint('Gemini WebSocket error: $error');
          _addTranscript('Connection error: $error', false);
        },
        onDone: () {
          debugPrint('Gemini WebSocket closed');
          setState(() => _isConnected = false);
        },
      );

      // Send setup message (required first message)
      final setupMessage = {
        "setup": {
          "model": "models/$_model",
          "generation_config": {
            "response_modalities": ["AUDIO"],
            "speech_config": {
              "voice_config": {
                "prebuilt_voice_config": {"voice_name": "Puck"},
              },
            },
          },
          "system_instruction": {
            "parts": [
              {
                "text":
                    "You are a friendly, caring AI veterinary assistant for PetPal. "
                    "You help pet owners with questions about their dog ${widget.dogName}'s health. "
                    "Be warm, reassuring, and professional. "
                    "Always recommend seeing a real vet for serious concerns. "
                    "Keep responses concise for voice - aim for 1-2 sentences when possible.",
              },
            ],
          },
        },
      };

      _channel!.sink.add(jsonEncode(setupMessage));

      // Wait for setup acknowledgment before starting audio
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => _isConnected = true);
      _addTranscript('Connected! I\'m listening...', false);

      // Start audio streaming
      await _startAudioStream();
    } catch (e) {
      debugPrint('Connect error: $e');
      _addTranscript('Failed to connect: $e', false);
    }
  }

  void _handleGeminiMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      debugPrint(
        'Gemini response: ${message.toString().substring(0, message.toString().length.clamp(0, 200))}...',
      );

      // Check for serverContent
      if (data.containsKey('serverContent')) {
        final serverContent = data['serverContent'];

        // Model turn with audio/text
        if (serverContent.containsKey('modelTurn')) {
          final modelTurn = serverContent['modelTurn'];
          if (modelTurn.containsKey('parts')) {
            for (final part in modelTurn['parts']) {
              // Audio response
              if (part.containsKey('inlineData')) {
                final inline = part['inlineData'];
                final mimeType = inline['mimeType'] ?? '';
                if (mimeType.toString().startsWith('audio/')) {
                  final audioData = base64Decode(inline['data']);
                  _queueAudio(Uint8List.fromList(audioData));
                }
              }

              // Text transcript
              if (part.containsKey('text')) {
                _addTranscript(part['text'], false);
              }
            }
          }
        }

        // Turn complete
        if (serverContent['turnComplete'] == true) {
          debugPrint('Turn complete');
        }
      }

      // Setup response
      if (data.containsKey('setupComplete')) {
        debugPrint('Gemini setup complete');
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
  }

  void _queueAudio(Uint8List audioData) {
    _audioQueue.add(audioData);
    _playNextAudio();
  }

  Future<void> _playNextAudio() async {
    if (_isPlaying || _audioQueue.isEmpty) return;
    _isPlaying = true;

    while (_audioQueue.isNotEmpty) {
      final audioData = _audioQueue.removeAt(0);
      try {
        // Create WAV from PCM (24kHz mono 16-bit from Gemini)
        final wavData = _createWavFromPcm(audioData, 24000);
        await _player.setAudioSource(_WavAudioSource(wavData));
        await _player.play();
        await _player.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );
      } catch (e) {
        debugPrint('Playback error: $e');
      }
    }
    _isPlaying = false;
  }

  Uint8List _createWavFromPcm(Uint8List pcmData, int sampleRate) {
    final dataLength = pcmData.length;
    final fileLength = dataLength + 36;
    final header = Uint8List(44);
    final byteData = ByteData.view(header.buffer);

    // RIFF header
    header[0] = 0x52;
    header[1] = 0x49;
    header[2] = 0x46;
    header[3] = 0x46;
    byteData.setUint32(4, fileLength, Endian.little);
    header[8] = 0x57;
    header[9] = 0x41;
    header[10] = 0x56;
    header[11] = 0x45;
    // fmt chunk
    header[12] = 0x66;
    header[13] = 0x6D;
    header[14] = 0x74;
    header[15] = 0x20;
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    // data chunk
    header[36] = 0x64;
    header[37] = 0x61;
    header[38] = 0x74;
    header[39] = 0x61;
    byteData.setUint32(40, dataLength, Endian.little);

    final result = Uint8List(44 + dataLength);
    result.setRange(0, 44, header);
    result.setRange(44, 44 + dataLength, pcmData);
    return result;
  }

  void _addTranscript(String text, bool isUser) {
    setState(() {
      _transcripts.add(TranscriptMessage(text: text, isUser: isUser));
    });

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

  Future<void> _startAudioStream() async {
    if (!await _recorder.hasPermission()) {
      _addTranscript('Microphone permission not granted', false);
      return;
    }

    try {
      // Stream raw PCM 16kHz mono (Gemini input format)
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      setState(() => _isRecording = true);

      // Send audio chunks to Gemini
      _audioStreamSubscription = stream.listen((data) {
        if (_isConnected && _channel != null && !_isPaused) {
          final base64Audio = base64Encode(data);

          // Send in Gemini realtime_input format
          final payload = {
            "realtime_input": {
              "media_chunks": [
                {"data": base64Audio, "mime_type": "audio/pcm"},
              ],
            },
          };

          _channel!.sink.add(jsonEncode(payload));
        }
      });
    } catch (e) {
      debugPrint('Start audio stream error: $e');
      _addTranscript('Failed to start microphone: $e', false);
    }
  }

  Future<void> _stopAudioStream() async {
    await _audioStreamSubscription?.cancel();
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _endCall() async {
    _durationTimer?.cancel();
    _waveformTimer?.cancel();
    await _stopAudioStream();

    await _wsSubscription?.cancel();
    await _channel?.sink.close();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (mounted) {
      Navigator.pop(context, _transcripts);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _waveformTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _recorder.dispose();
    _player.dispose();
    _scrollController.dispose();
    _wsSubscription?.cancel();
    _channel?.sink.close();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildTranscriptArea()),
              _buildWaveformArea(),
              _buildControlBar(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isRecording && !_isPaused ? Icons.mic : Icons.mic_off,
                  color: _isConnected ? Colors.white : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Live' : 'Connecting...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _formatDuration(_callDuration),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.expand_more, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptArea() {
    if (_transcripts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 64, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'AI Vet is listening...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Talk about ${widget.dogName}\'s health',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _transcripts.length,
      itemBuilder: (context, index) {
        final msg = _transcripts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.isUser ? 'You:' : 'AI Vet:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveformArea() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: _isRecording && !_isPaused
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_waveformBars.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: 4,
                    height: 20 + (_waveformBars[index] * 60),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              )
            : Icon(
                _isPaused ? Icons.pause_circle : Icons.mic_off,
                size: 48,
                color: Colors.white.withOpacity(0.3),
              ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.videocam_outlined,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video mode coming soon!')),
              );
            },
          ),
          _buildControlButton(
            icon: _isPaused ? Icons.play_arrow : Icons.pause,
            onTap: _togglePause,
          ),
          _buildControlButton(
            icon: Icons.close,
            isDestructive: true,
            onTap: _endCall,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

/// Custom audio source for in-memory WAV data
class _WavAudioSource extends StreamAudioSource {
  final Uint8List _data;
  _WavAudioSource(this._data);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _data.length;
    return StreamAudioResponse(
      sourceLength: _data.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_data.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
