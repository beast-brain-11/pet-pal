// Live API Service - WebSocket client for real-time voice/video streaming
// Connects to FastAPI backend on HuggingFace Spaces

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

enum LiveConnectionState { disconnected, connecting, connected, error }

class LiveApiService {
  static const String _baseUrl = 'https://priaansh-petpal-ai-backend.hf.space';

  WebSocketChannel? _channel;
  StreamController<Uint8List>? _audioStreamController;
  StreamController<LiveConnectionState>? _stateController;

  LiveConnectionState _state = LiveConnectionState.disconnected;

  // Callbacks
  Function(Uint8List audio)? onAudioReceived;
  Function(String error)? onError;
  Function()? onConnected;
  Function()? onDisconnected;

  LiveConnectionState get state => _state;

  Stream<LiveConnectionState> get stateStream {
    _stateController ??= StreamController<LiveConnectionState>.broadcast();
    return _stateController!.stream;
  }

  /// Start voice-only session
  Future<bool> startVoiceSession(String sessionId) async {
    return _connect('$_baseUrl/ws/voice/$sessionId');
  }

  /// Start video + voice session
  Future<bool> startVideoSession(String sessionId) async {
    return _connect('$_baseUrl/ws/video/$sessionId');
  }

  Future<bool> _connect(String url) async {
    try {
      _updateState(LiveConnectionState.connecting);

      _channel = WebSocketChannel.connect(Uri.parse(url));
      _audioStreamController = StreamController<Uint8List>.broadcast();

      // Listen for messages
      _channel!.stream.listen(
        (data) {
          if (data is String) {
            final message = jsonDecode(data);
            if (message['type'] == 'ready') {
              _updateState(LiveConnectionState.connected);
              onConnected?.call();
            } else if (message['type'] == 'audio') {
              // Decode base64 audio for video mode
              final audioBytes = base64Decode(message['data']);
              onAudioReceived?.call(Uint8List.fromList(audioBytes));
            } else if (message['type'] == 'error') {
              onError?.call(message['message']);
            }
          } else if (data is List<int>) {
            // Raw audio bytes for voice mode
            onAudioReceived?.call(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _updateState(LiveConnectionState.error);
          onError?.call(error.toString());
        },
        onDone: () {
          _updateState(LiveConnectionState.disconnected);
          onDisconnected?.call();
        },
      );

      // Wait for ready signal
      await Future.delayed(const Duration(seconds: 2));
      return _state == LiveConnectionState.connected;
    } catch (e) {
      print('Connection error: $e');
      _updateState(LiveConnectionState.error);
      onError?.call(e.toString());
      return false;
    }
  }

  /// Send audio chunk (16kHz PCM)
  void sendAudio(Uint8List audioData) {
    if (_state != LiveConnectionState.connected) return;

    try {
      _channel?.sink.add(audioData);
    } catch (e) {
      print('Send audio error: $e');
    }
  }

  /// Send video frame (JPEG) + audio
  void sendVideoFrame(Uint8List jpegData, {Uint8List? audioData}) {
    if (_state != LiveConnectionState.connected) return;

    try {
      // Send video frame
      final frameMessage = jsonEncode({
        'type': 'video_frame',
        'data': base64Encode(jpegData),
      });
      _channel?.sink.add(frameMessage);

      // Send audio if provided
      if (audioData != null) {
        final audioMessage = jsonEncode({
          'type': 'audio',
          'data': base64Encode(audioData),
        });
        _channel?.sink.add(audioMessage);
      }
    } catch (e) {
      print('Send video error: $e');
    }
  }

  /// Disconnect session
  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
      _channel = null;
      await _audioStreamController?.close();
      _audioStreamController = null;
      _updateState(LiveConnectionState.disconnected);
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  void _updateState(LiveConnectionState newState) {
    _state = newState;
    _stateController?.add(newState);
  }

  void dispose() {
    disconnect();
    _stateController?.close();
  }
}
