// Live Voice Service - Real-time Speech-to-Speech with Gemini Live API
// Handles audio recording, WebSocket streaming, and audio playback

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

/// Message for chat transcript
class LiveMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  LiveMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

/// Callback types
typedef OnTranscript = void Function(LiveMessage message);
typedef OnError = void Function(String error);
typedef OnConnectionChanged = void Function(bool connected);
typedef OnRecordingChanged = void Function(bool recording);

/// Service for real-time voice streaming with Gemini Live API
class LiveVoiceService {
  static const String _wsBaseUrl = 'wss://priaansh-petpal-ai-backend.hf.space';

  // WebSocket
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // Audio recording
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _recordingSubscription;

  // Audio playback
  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _audioQueue = [];
  bool _isPlaying = false;

  // State
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isCameraEnabled = false;

  // Callbacks
  OnTranscript? onTranscript;
  OnError? onError;
  OnConnectionChanged? onConnectionChanged;
  OnRecordingChanged? onRecordingChanged;

  // Audio config (matches Gemini Live API requirements)
  static const int inputSampleRate = 16000; // 16kHz for input
  static const int outputSampleRate = 24000; // 24kHz for output

  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
  bool get isCameraEnabled => _isCameraEnabled;

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Connect to the live session WebSocket
  Future<bool> connect({required String dogId, required String dogName}) async {
    try {
      // Check permission first
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          onError?.call('Microphone permission denied');
          return false;
        }
      }

      // Connect to WebSocket
      _channel = WebSocketChannel.connect(Uri.parse('$_wsBaseUrl/ws/live'));

      // Listen for messages from backend
      _subscription = _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          debugPrint('WebSocket error: $error');
          onError?.call('Connection error');
          _disconnect();
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _disconnect();
        },
      );

      // Wait a bit for connection
      await Future.delayed(const Duration(milliseconds: 500));

      // Send config
      _channel!.sink.add(
        jsonEncode({'type': 'config', 'dog_id': dogId, 'dog_name': dogName}),
      );

      _isConnected = true;
      onConnectionChanged?.call(true);

      return true;
    } catch (e) {
      debugPrint('Connect error: $e');
      onError?.call('Failed to connect');
      return false;
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final type = data['type'] as String?;

      switch (type) {
        case 'connected':
          debugPrint('Live session connected: ${data['message']}');
          _isConnected = true;
          onConnectionChanged?.call(true);
          break;

        case 'audio':
          // Decode base64 PCM audio and queue for playback
          final audioData = base64Decode(data['data'] as String);
          _queueAudio(Uint8List.fromList(audioData));
          break;

        case 'transcript':
          final role = data['role'] as String?;
          final text = data['text'] as String?;
          if (text != null && text.isNotEmpty) {
            onTranscript?.call(LiveMessage(text: text, isUser: role == 'user'));
          }
          break;

        case 'error':
          onError?.call(data['message'] ?? 'Unknown error');
          break;
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
  }

  /// Queue audio for playback
  void _queueAudio(Uint8List audioData) {
    _audioQueue.add(audioData);
    _playNextAudio();
  }

  /// Play next audio in queue
  Future<void> _playNextAudio() async {
    if (_isPlaying || _audioQueue.isEmpty) return;

    _isPlaying = true;

    while (_audioQueue.isNotEmpty) {
      final audioData = _audioQueue.removeAt(0);

      try {
        // Create a WAV file from PCM data for playback
        final wavData = _createWavFromPcm(audioData, outputSampleRate);

        // Use just_audio to play
        await _player.setAudioSource(MyWavAudioSource(wavData));
        await _player.play();

        // Wait for completion
        await _player.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );
      } catch (e) {
        debugPrint('Playback error: $e');
      }
    }

    _isPlaying = false;
  }

  /// Create WAV header for PCM data
  Uint8List _createWavFromPcm(Uint8List pcmData, int sampleRate) {
    final dataLength = pcmData.length;
    final fileLength = dataLength + 36;

    final header = Uint8List(44);
    final byteData = ByteData.view(header.buffer);

    // RIFF header
    header[0] = 0x52; // R
    header[1] = 0x49; // I
    header[2] = 0x46; // F
    header[3] = 0x46; // F
    byteData.setUint32(4, fileLength, Endian.little);
    header[8] = 0x57; // W
    header[9] = 0x41; // A
    header[10] = 0x56; // V
    header[11] = 0x45; // E

    // fmt chunk
    header[12] = 0x66; // f
    header[13] = 0x6D; // m
    header[14] = 0x74; // t
    header[15] = 0x20; // space
    byteData.setUint32(16, 16, Endian.little); // chunk size
    byteData.setUint16(20, 1, Endian.little); // PCM format
    byteData.setUint16(22, 1, Endian.little); // mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    byteData.setUint16(32, 2, Endian.little); // block align
    byteData.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    header[36] = 0x64; // d
    header[37] = 0x61; // a
    header[38] = 0x74; // t
    header[39] = 0x61; // a
    byteData.setUint32(40, dataLength, Endian.little);

    // Combine header and PCM data
    final result = Uint8List(44 + dataLength);
    result.setRange(0, 44, header);
    result.setRange(44, 44 + dataLength, pcmData);

    return result;
  }

  /// Start recording and streaming audio
  Future<void> startRecording() async {
    if (_isRecording || !_isConnected) return;

    try {
      // Check if can record
      if (!await _recorder.hasPermission()) {
        onError?.call('Microphone permission not granted');
        return;
      }

      // Start recording with PCM format
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: inputSampleRate,
          numChannels: 1,
        ),
      );

      _isRecording = true;
      onRecordingChanged?.call(true);

      // Stream audio to WebSocket
      _recordingSubscription = stream.listen((data) {
        if (_isConnected && _channel != null) {
          final base64Audio = base64Encode(data);
          _channel!.sink.add(
            jsonEncode({'type': 'audio', 'data': base64Audio}),
          );
        }
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
      onError?.call('Failed to start recording');
      _isRecording = false;
      onRecordingChanged?.call(false);
    }
  }

  /// Stop recording
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      await _recordingSubscription?.cancel();
      await _recorder.stop();
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }

    _isRecording = false;
    onRecordingChanged?.call(false);
  }

  /// Toggle camera for video mode
  void toggleCamera(bool enabled) {
    _isCameraEnabled = enabled;
  }

  /// Send video frame (JPEG)
  void sendVideoFrame(Uint8List jpegData) {
    if (!_isConnected || _channel == null || !_isCameraEnabled) return;

    final base64Image = base64Encode(jpegData);
    _channel!.sink.add(jsonEncode({'type': 'video', 'data': base64Image}));
  }

  void _disconnect() {
    _isConnected = false;
    onConnectionChanged?.call(false);
  }

  /// Disconnect from the live session
  Future<void> disconnect() async {
    await stopRecording();
    _isCameraEnabled = false;
    _audioQueue.clear();

    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'stop'}));
      } catch (_) {}

      await _subscription?.cancel();
      await _channel!.sink.close();
      _channel = null;
    }

    _disconnect();
  }

  /// Cleanup
  Future<void> dispose() async {
    await disconnect();
    await _recorder.dispose();
    await _player.dispose();
  }
}

/// Custom audio source for in-memory WAV data
class MyWavAudioSource extends StreamAudioSource {
  final Uint8List _data;

  MyWavAudioSource(this._data);

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
