// Walk Tracking Service for PetPal
// Combines GPS path tracking for accurate walk verification
// XP is only granted after walk completion with proper verification

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

enum WalkStatus { idle, active, paused, completed }

class WalkTrackingService {
  // Singleton
  static final WalkTrackingService _instance = WalkTrackingService._internal();
  factory WalkTrackingService() => _instance;
  WalkTrackingService._internal();

  // State
  WalkStatus _status = WalkStatus.idle;
  DateTime? _startTime;
  DateTime? _pauseTime;
  Duration _totalPausedDuration = Duration.zero;

  // GPS tracking
  StreamSubscription<Position>? _positionSubscription;
  final List<Position> _positions = [];
  double _totalDistanceMeters = 0;

  // Timer for UI updates
  Timer? _elapsedTimer;
  final _timerController = StreamController<Duration>.broadcast();
  Stream<Duration> get elapsedTimeStream => _timerController.stream;

  // Stream controllers for live updates
  final _distanceController = StreamController<double>.broadcast();
  Stream<double> get distanceStream => _distanceController.stream;

  final _statusController = StreamController<WalkStatus>.broadcast();
  Stream<WalkStatus> get statusStream => _statusController.stream;

  // Getters
  WalkStatus get status => _status;
  bool get isActive => _status == WalkStatus.active;
  bool get isPaused => _status == WalkStatus.paused;
  bool get isIdle => _status == WalkStatus.idle;

  double get distanceMeters => _totalDistanceMeters;
  int get positionCount => _positions.length;

  Duration get elapsedTime {
    if (_startTime == null) return Duration.zero;
    if (_status == WalkStatus.paused && _pauseTime != null) {
      return _pauseTime!.difference(_startTime!) - _totalPausedDuration;
    }
    return DateTime.now().difference(_startTime!) - _totalPausedDuration;
  }

  String get formattedTime {
    final d = elapsedTime;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDistance {
    if (_totalDistanceMeters < 1000) {
      return '${_totalDistanceMeters.toInt()} m';
    }
    return '${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km';
  }

  // Start walk tracking
  Future<bool> startWalk() async {
    if (_status == WalkStatus.active) return true;

    // Check GPS permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    // Reset state
    _positions.clear();
    _totalDistanceMeters = 0;
    _totalPausedDuration = Duration.zero;
    _pauseTime = null;
    _startTime = DateTime.now();
    _status = WalkStatus.active;
    _statusController.add(_status);

    // Start GPS tracking
    _startGPSTracking();

    // Start elapsed timer
    _startElapsedTimer();

    return true;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == WalkStatus.active) {
        _timerController.add(elapsedTime);
      }
    });
  }

  void _startGPSTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters for accurate path tracking
    );

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          if (_status == WalkStatus.active) {
            // Calculate distance from previous position (cumulative path distance)
            if (_positions.isNotEmpty) {
              final lastPos = _positions.last;
              final segmentDistance = Geolocator.distanceBetween(
                lastPos.latitude,
                lastPos.longitude,
                position.latitude,
                position.longitude,
              );
              _totalDistanceMeters += segmentDistance;
              _distanceController.add(_totalDistanceMeters);
            }
            _positions.add(position);
            debugPrint(
              'Walk GPS: ${position.latitude}, ${position.longitude} - Total: ${formattedDistance}',
            );
          }
        });
  }

  // Pause walk
  void pauseWalk() {
    if (_status == WalkStatus.active) {
      _status = WalkStatus.paused;
      _pauseTime = DateTime.now();
      _statusController.add(_status);
    }
  }

  // Resume walk
  void resumeWalk() {
    if (_status == WalkStatus.paused && _pauseTime != null) {
      _totalPausedDuration += DateTime.now().difference(_pauseTime!);
      _pauseTime = null;
      _status = WalkStatus.active;
      _statusController.add(_status);
    }
  }

  // Complete walk and get verification result
  WalkResult? completeWalk() {
    if (_status == WalkStatus.idle) return null;

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    final result = WalkResult(
      distanceMeters: _totalDistanceMeters,
      durationMinutes: elapsedTime.inMinutes,
      durationSeconds: elapsedTime.inSeconds,
      positionCount: _positions.length,
      startTime: _startTime!,
      endTime: DateTime.now(),
    );

    // Reset state
    _status = WalkStatus.idle;
    _statusController.add(_status);
    _startTime = null;
    _pauseTime = null;
    _positions.clear();
    _totalDistanceMeters = 0;
    _totalPausedDuration = Duration.zero;

    return result;
  }

  // Cancel walk without saving
  void cancelWalk() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _status = WalkStatus.idle;
    _statusController.add(_status);
    _startTime = null;
    _pauseTime = null;
    _positions.clear();
    _totalDistanceMeters = 0;
    _totalPausedDuration = Duration.zero;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    _timerController.close();
    _distanceController.close();
    _statusController.close();
  }
}

class WalkResult {
  final double distanceMeters;
  final int durationMinutes;
  final int durationSeconds;
  final int positionCount;
  final DateTime startTime;
  final DateTime endTime;

  WalkResult({
    required this.distanceMeters,
    required this.durationMinutes,
    required this.durationSeconds,
    required this.positionCount,
    required this.startTime,
    required this.endTime,
  });

  // Verification checks
  bool get isVerified {
    // Must have at least some GPS data points
    if (positionCount < 3) return false;
    // Must have moved at least 20 meters
    if (distanceMeters < 20) return false;
    // Must have walked for at least 1 minute
    if (durationSeconds < 60) return false;
    return true;
  }

  // Calculate XP based on verified walk
  int get earnedXP {
    if (!isVerified) return 0;

    // Base XP: 1 per minute walked
    int baseXP = durationMinutes;

    // Distance bonus: 1 XP per 100 meters walked
    int distanceBonus = (distanceMeters / 100).floor();

    // Cap at 100 XP per walk
    return (baseXP + distanceBonus).clamp(0, 100);
  }

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final secs = durationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  Map<String, dynamic> toMap() => {
    'distanceMeters': distanceMeters,
    'durationMinutes': durationMinutes,
    'durationSeconds': durationSeconds,
    'positionCount': positionCount,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'isVerified': isVerified,
    'earnedXP': earnedXP,
  };
}
