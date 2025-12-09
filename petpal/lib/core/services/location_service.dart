import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final List<Position> _walkPositions = [];
  DateTime? _walkStartTime;

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      );
    } catch (e) {
      print('LocationService: Error getting position: $e');
      return null;
    }
  }

  /// Start tracking a walk
  Future<bool> startWalkTracking() async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) return false;

    _walkPositions.clear();
    _walkStartTime = DateTime.now();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Track every 5 meters
    );

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          _walkPositions.add(position);
          print(
            'LocationService: Position update - lat: ${position.latitude}, lng: ${position.longitude}',
          );
        });

    return true;
  }

  /// Stop tracking and return walk stats
  WalkStats? stopWalkTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    if (_walkPositions.isEmpty || _walkStartTime == null) {
      return null;
    }

    // Calculate total distance
    double totalDistance = 0;
    for (int i = 1; i < _walkPositions.length; i++) {
      totalDistance += Geolocator.distanceBetween(
        _walkPositions[i - 1].latitude,
        _walkPositions[i - 1].longitude,
        _walkPositions[i].latitude,
        _walkPositions[i].longitude,
      );
    }

    final duration = DateTime.now().difference(_walkStartTime!);

    final stats = WalkStats(
      distanceMeters: totalDistance,
      durationMinutes: duration.inMinutes,
      positionCount: _walkPositions.length,
      startTime: _walkStartTime!,
      endTime: DateTime.now(),
      isVerified:
          _walkPositions.length >= 3 &&
          totalDistance > 50, // At least 3 points and 50 meters
    );

    _walkPositions.clear();
    _walkStartTime = null;

    return stats;
  }

  /// Verify if a claimed walk duration is reasonable based on GPS data
  bool verifyWalk(int claimedMinutes, WalkStats stats) {
    // Check if GPS tracking was active
    if (!stats.isVerified) return false;

    // Duration should be within 20% of claimed (to account for timing differences)
    final durationDiff = (claimedMinutes - stats.durationMinutes).abs();
    if (durationDiff > claimedMinutes * 0.3) return false;

    // Should have moved at least 20 meters per minute on average
    final minExpectedDistance =
        claimedMinutes * 20.0; // 20 meters/min = very slow walk
    if (stats.distanceMeters < minExpectedDistance * 0.5) return false;

    // Max walking speed is about 100 meters/min (fast jog/run)
    final maxExpectedDistance = claimedMinutes * 100.0;
    if (stats.distanceMeters > maxExpectedDistance) return false;

    return true;
  }

  /// Calculate XP based on verified walk data
  int calculateWalkXP(WalkStats stats) {
    if (!stats.isVerified) {
      return 0; // No XP for unverified walks
    }

    // Base XP: 1 per minute, bonus for distance
    int baseXP = stats.durationMinutes;
    int distanceBonus = (stats.distanceMeters / 100).floor(); // +1 XP per 100m

    // Cap at 100 XP per walk
    return (baseXP + distanceBonus).clamp(0, 100);
  }
}

class WalkStats {
  final double distanceMeters;
  final int durationMinutes;
  final int positionCount;
  final DateTime startTime;
  final DateTime endTime;
  final bool isVerified;

  WalkStats({
    required this.distanceMeters,
    required this.durationMinutes,
    required this.positionCount,
    required this.startTime,
    required this.endTime,
    required this.isVerified,
  });

  Map<String, dynamic> toMap() {
    return {
      'distanceMeters': distanceMeters,
      'durationMinutes': durationMinutes,
      'positionCount': positionCount,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'isVerified': isVerified,
    };
  }
}
