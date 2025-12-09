import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'location_service.dart';

final cloudFunctionsServiceProvider = Provider<CloudFunctionsService>((ref) {
  return CloudFunctionsService();
});

/// Service for calling Firebase Cloud Functions with JWT auth
class CloudFunctionsService {
  // Cloud Functions URL for petpal-5707
  static const String _baseUrl =
      'https://us-central1-petpal-5707.cloudfunctions.net/api';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the user's ID token for authentication
  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Create authenticated headers with JWT
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Add XP via Cloud Functions (server-validated)
  Future<XPResult> addXP({
    required String dogId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/addXP'),
        headers: headers,
        body: json.encode({
          'dogId': dogId,
          'action': action,
          'metadata': metadata ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return XPResult(
          success: data['success'] ?? false,
          xpAdded: data['xpAdded'] ?? 0,
          newXP: data['newXP'] ?? 0,
          newLevel: data['newLevel'] ?? 1,
          leveledUp: data['leveledUp'] ?? false,
          dailyRemaining: data['dailyRemaining'] ?? 500,
        );
      } else if (response.statusCode == 429) {
        final data = json.decode(response.body);
        return XPResult(
          success: false,
          error: data['error'] ?? 'Rate limit exceeded',
          limitReached: true,
        );
      } else {
        final data = json.decode(response.body);
        return XPResult(
          success: false,
          error: data['error'] ?? 'Unknown error',
        );
      }
    } catch (e) {
      print('CloudFunctions Error: $e');
      return XPResult(success: false, error: e.toString());
    }
  }

  /// Get XP status and limits
  Future<XPStatus?> getXPStatus(String dogId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/xpStatus/$dogId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return XPStatus(
          level: data['level'] ?? 1,
          currentXP: data['currentXP'] ?? 0,
          xpForNextLevel: data['xpForNextLevel'] ?? 1000,
          totalXP: data['totalXP'] ?? 0,
          dailyXP: data['dailyXP'] ?? 0,
          dailyRemaining: data['dailyRemaining'] ?? 500,
          streak: data['streak'] ?? 0,
        );
      }
      return null;
    } catch (e) {
      print('CloudFunctions Error: $e');
      return null;
    }
  }

  /// Verify walk with GPS data
  Future<WalkVerificationResult> verifyWalk({
    required String dogId,
    required WalkStats walkStats,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/verifyWalk'),
        headers: headers,
        body: json.encode({'dogId': dogId, 'walkData': walkStats.toMap()}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WalkVerificationResult(
          verified: data['verified'] ?? false,
          xpEarned: data['xpEarned'] ?? 0,
          stats: data['stats'],
          checks: data['checks'],
        );
      }
      return WalkVerificationResult(verified: false, xpEarned: 0);
    } catch (e) {
      print('CloudFunctions Error: $e');
      return WalkVerificationResult(verified: false, xpEarned: 0);
    }
  }
}

/// Result from adding XP
class XPResult {
  final bool success;
  final int xpAdded;
  final int newXP;
  final int newLevel;
  final bool leveledUp;
  final int dailyRemaining;
  final String? error;
  final bool limitReached;

  XPResult({
    this.success = false,
    this.xpAdded = 0,
    this.newXP = 0,
    this.newLevel = 1,
    this.leveledUp = false,
    this.dailyRemaining = 500,
    this.error,
    this.limitReached = false,
  });
}

/// Current XP status
class XPStatus {
  final int level;
  final int currentXP;
  final int xpForNextLevel;
  final int totalXP;
  final int dailyXP;
  final int dailyRemaining;
  final int streak;

  XPStatus({
    required this.level,
    required this.currentXP,
    required this.xpForNextLevel,
    required this.totalXP,
    required this.dailyXP,
    required this.dailyRemaining,
    required this.streak,
  });
}

/// Result from walk verification
class WalkVerificationResult {
  final bool verified;
  final int xpEarned;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? checks;

  WalkVerificationResult({
    required this.verified,
    required this.xpEarned,
    this.stats,
    this.checks,
  });
}
