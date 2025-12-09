// Firestore Service for Pet Profile Data Storage
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  // Dog Profile Collection Reference
  CollectionReference<Map<String, dynamic>> get _dogsCollection =>
      _db.collection('users').doc(userId).collection('dogs');

  // Save dog profile
  Future<String> saveDogProfile(Map<String, dynamic> dogData) async {
    if (userId == null) throw Exception('User not logged in');

    dogData['createdAt'] = FieldValue.serverTimestamp();
    dogData['updatedAt'] = FieldValue.serverTimestamp();

    final doc = await _dogsCollection.add(dogData);
    return doc.id;
  }

  // Update dog profile
  Future<void> updateDogProfile(
    String dogId,
    Map<String, dynamic> dogData,
  ) async {
    if (userId == null) throw Exception('User not logged in');

    dogData['updatedAt'] = FieldValue.serverTimestamp();
    await _dogsCollection.doc(dogId).update(dogData);
  }

  // Get all dogs for user
  Stream<List<DogProfile>> getDogProfiles() {
    if (userId == null) return Stream.value([]);

    return _dogsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return DogProfile.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  // Get single dog profile
  Future<DogProfile?> getDogProfile(String dogId) async {
    if (userId == null) return null;

    final doc = await _dogsCollection.doc(dogId).get();
    if (doc.exists) {
      return DogProfile.fromFirestore(doc.id, doc.data()!);
    }
    return null;
  }

  // Delete dog profile
  Future<void> deleteDogProfile(String dogId) async {
    if (userId == null) throw Exception('User not logged in');
    await _dogsCollection.doc(dogId).delete();
  }

  // Save onboarding progress (partial data)
  Future<void> saveOnboardingProgress(Map<String, dynamic> data) async {
    if (userId == null) throw Exception('User not logged in');

    await _db.collection('users').doc(userId).set({
      'onboardingData': data,
      'onboardingComplete': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get onboarding progress
  Future<Map<String, dynamic>?> getOnboardingProgress() async {
    if (userId == null) return null;

    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists && doc.data()?['onboardingData'] != null) {
      return Map<String, dynamic>.from(doc.data()!['onboardingData']);
    }
    return null;
  }

  // Complete onboarding (move data to dog profile)
  Future<String> completeOnboarding() async {
    if (userId == null) throw Exception('User not logged in');

    final progress = await getOnboardingProgress();
    if (progress == null) throw Exception('No onboarding data found');

    // Save as dog profile
    final dogId = await saveDogProfile(progress);

    // Mark onboarding complete
    await _db.collection('users').doc(userId).update({
      'onboardingComplete': true,
      'currentDogId': dogId,
    });

    return dogId;
  }

  // Check if user completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    // Wait briefly to ensure Firebase Auth is fully initialized
    if (userId == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (userId == null) return false;
    }

    try {
      // First check the flag on user document
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?['onboardingComplete'] == true) {
        return true;
      }

      // Fallback: Check if user has any dog profiles (data exists even if flag wasn't set)
      // This handles cases where the flag didn't get set properly or after reinstall
      final dogsSnapshot = await _dogsCollection.limit(1).get();
      if (dogsSnapshot.docs.isNotEmpty) {
        // User has dog profiles, mark onboarding as complete for future
        await _db.collection('users').doc(userId).set({
          'onboardingComplete': true,
        }, SetOptions(merge: true));
        return true;
      }

      return false;
    } catch (e) {
      print('Error checking onboarding status: $e');
      // On network error, try a second time after delay
      try {
        await Future.delayed(const Duration(milliseconds: 1000));
        final dogsSnapshot = await _dogsCollection.limit(1).get();
        return dogsSnapshot.docs.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  // ============================================================================
  // DAILY TASKS
  // ============================================================================

  CollectionReference<Map<String, dynamic>> _tasksCollection(String dogId) =>
      _dogsCollection.doc(dogId).collection('tasks');

  // Get today's tasks for a dog
  Stream<List<DailyTask>> getTodayTasks(String dogId) {
    if (userId == null) return Stream.value([]);

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _tasksCollection(dogId)
        .where(
          'scheduledDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('scheduledDate')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DailyTask.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  // Add a task
  Future<String> addTask(String dogId, DailyTask task) async {
    if (userId == null) throw Exception('User not logged in');
    final doc = await _tasksCollection(dogId).add(task.toMap());
    return doc.id;
  }

  // Mark task as completed
  Future<void> completeTask(String dogId, String taskId) async {
    if (userId == null) throw Exception('User not logged in');
    await _tasksCollection(dogId).doc(taskId).update({
      'isCompleted': true,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // Initialize default daily tasks for a new dog
  Future<void> initializeDefaultTasks(String dogId, String dogName) async {
    if (userId == null) throw Exception('User not logged in');

    final today = DateTime.now();
    final tasks = [
      DailyTask(
        id: '',
        title: 'Breakfast',
        emoji: '🍖',
        type: 'meal',
        scheduledTime: '07:00 AM',
        scheduledDate: DateTime(today.year, today.month, today.day, 7, 0),
      ),
      DailyTask(
        id: '',
        title: 'Morning Walk',
        emoji: '🚶',
        type: 'walk',
        scheduledTime: '08:30 AM',
        scheduledDate: DateTime(today.year, today.month, today.day, 8, 30),
      ),
      DailyTask(
        id: '',
        title: 'Playtime',
        emoji: '🎾',
        type: 'play',
        scheduledTime: '11:00 AM',
        scheduledDate: DateTime(today.year, today.month, today.day, 11, 0),
      ),
      DailyTask(
        id: '',
        title: 'Lunch',
        emoji: '🍖',
        type: 'meal',
        scheduledTime: '01:00 PM',
        scheduledDate: DateTime(today.year, today.month, today.day, 13, 0),
      ),
      DailyTask(
        id: '',
        title: 'Evening Walk',
        emoji: '🚶',
        type: 'walk',
        scheduledTime: '06:00 PM',
        scheduledDate: DateTime(today.year, today.month, today.day, 18, 0),
      ),
      DailyTask(
        id: '',
        title: 'Dinner',
        emoji: '🍖',
        type: 'meal',
        scheduledTime: '08:00 PM',
        scheduledDate: DateTime(today.year, today.month, today.day, 20, 0),
      ),
    ];

    for (final task in tasks) {
      await addTask(dogId, task);
    }
  }

  // ============================================================================
  // PET STATS (Health Score, Steps, Water, etc.)
  // ============================================================================

  DocumentReference<Map<String, dynamic>> _statsDoc(String dogId) =>
      _dogsCollection.doc(dogId).collection('stats').doc('current');

  // Get pet stats
  Stream<PetStats> getPetStats(String dogId) {
    if (userId == null) return Stream.value(PetStats.empty());

    return _statsDoc(dogId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return PetStats.fromFirestore(doc.data()!);
      }
      return PetStats.empty();
    });
  }

  // Update pet stats
  Future<void> updatePetStats(String dogId, PetStats stats) async {
    if (userId == null) throw Exception('User not logged in');
    await _statsDoc(dogId).set(stats.toMap(), SetOptions(merge: true));
  }

  // Initialize default stats for new dog
  Future<void> initializeDefaultStats(String dogId) async {
    if (userId == null) throw Exception('User not logged in');
    await _statsDoc(dogId).set(PetStats.empty().toMap());
  }

  // ============================================================================
  // GAMIFICATION (XP, Level, Streak, Achievements)
  // ============================================================================

  DocumentReference<Map<String, dynamic>> _gamificationDoc(String dogId) =>
      _dogsCollection.doc(dogId).collection('gamification').doc('progress');

  // Get gamification data
  Stream<GamificationData> getGamificationData(String dogId) {
    if (userId == null) return Stream.value(GamificationData.initial());

    return _gamificationDoc(dogId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return GamificationData.fromFirestore(doc.data()!);
      }
      return GamificationData.initial();
    });
  }

  // Add XP with anti-cheat protections
  Future<bool> addXP(String dogId, int xp, {String source = 'action'}) async {
    if (userId == null) throw Exception('User not logged in');
    if (xp <= 0 || xp > 100) return false; // Max 100 XP per action

    final doc = await _gamificationDoc(dogId).get();
    final current = doc.exists
        ? GamificationData.fromFirestore(doc.data()!)
        : GamificationData.initial();

    // Anti-cheat: Check daily limits
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    final data = doc.data() ?? {};
    final lastXPDate = data['lastXPDate'] as String?;
    int dailyXP = data['dailyXP'] as int? ?? 0;
    int dailyMeals = data['dailyMeals'] as int? ?? 0;
    int dailyWalks = data['dailyWalks'] as int? ?? 0;
    int dailyPhotos = data['dailyPhotos'] as int? ?? 0;

    if (lastXPDate != todayString) {
      // New day, reset all counters
      dailyXP = 0;
      dailyMeals = 0;
      dailyWalks = 0;
      dailyPhotos = 0;
    }

    // Check action-specific limits
    if (source == 'meal' && dailyMeals >= 10) {
      return false; // Max 10 meals per day
    }
    if (source == 'walk' && dailyWalks >= 5) {
      return false; // Max 5 walks per day
    }
    if (source == 'photo' && dailyPhotos >= 20) {
      return false; // Max 20 photos per day
    }

    if (dailyXP >= 500) {
      // Max daily XP reached
      return false;
    }

    // Cap XP to not exceed daily limit
    final actualXP = (dailyXP + xp) > 500 ? (500 - dailyXP) : xp;
    if (actualXP <= 0) return false;

    int newXP = current.currentXP + actualXP;
    int newLevel = current.level;
    int xpForNextLevel = current.xpForNextLevel;

    // Level up if needed
    while (newXP >= xpForNextLevel) {
      newXP -= xpForNextLevel;
      newLevel++;
      xpForNextLevel = 1000 + (newLevel * 200); // Increase XP needed per level
    }

    // Update counters based on source
    if (source == 'meal') dailyMeals++;
    if (source == 'walk') dailyWalks++;
    if (source == 'photo') dailyPhotos++;

    await _gamificationDoc(dogId).set({
      'level': newLevel,
      'currentXP': newXP,
      'xpForNextLevel': xpForNextLevel,
      'totalXP': current.totalXP + actualXP,
      'dailyXP': dailyXP + actualXP,
      'dailyMeals': dailyMeals,
      'dailyWalks': dailyWalks,
      'dailyPhotos': dailyPhotos,
      'lastXPDate': todayString,
      'lastXPSource': source,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  // Update streak
  Future<void> updateStreak(String dogId) async {
    if (userId == null) throw Exception('User not logged in');

    final doc = await _gamificationDoc(dogId).get();
    final data = doc.exists ? doc.data() : null;

    final lastStreakDate = data?['lastStreakDate'] != null
        ? (data!['lastStreakDate'] as Timestamp).toDate()
        : null;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    int currentStreak = data?['streak'] ?? 0;

    if (lastStreakDate != null) {
      final lastDate = DateTime(
        lastStreakDate.year,
        lastStreakDate.month,
        lastStreakDate.day,
      );
      final difference = todayDate.difference(lastDate).inDays;

      if (difference == 0) {
        // Already updated today
        return;
      } else if (difference == 1) {
        // Consecutive day
        currentStreak++;
      } else {
        // Streak broken
        currentStreak = 1;
      }
    } else {
      currentStreak = 1;
    }

    await _gamificationDoc(dogId).set({
      'streak': currentStreak,
      'lastStreakDate': Timestamp.fromDate(todayDate),
      'longestStreak': currentStreak > (data?['longestStreak'] ?? 0)
          ? currentStreak
          : (data?['longestStreak'] ?? 0),
    }, SetOptions(merge: true));
  }

  // Unlock achievement
  Future<void> unlockAchievement(String dogId, String achievementId) async {
    if (userId == null) throw Exception('User not logged in');

    await _gamificationDoc(dogId).set({
      'achievements': FieldValue.arrayUnion([achievementId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Initialize gamification for new dog
  Future<void> initializeGamification(String dogId) async {
    if (userId == null) throw Exception('User not logged in');
    await _gamificationDoc(dogId).set(GamificationData.initial().toMap());
  }

  // Get current dog ID
  Future<String?> getCurrentDogId() async {
    if (userId == null) return null;
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['currentDogId'];
  }

  // ============================================================================
  // SAVED RECIPES
  // ============================================================================

  CollectionReference<Map<String, dynamic>> get _recipesCollection =>
      _db.collection('users').doc(userId).collection('recipes');

  // Save a recipe
  Future<String> saveRecipe(Map<String, dynamic> recipeData) async {
    if (userId == null) throw Exception('User not logged in');

    recipeData['savedAt'] = FieldValue.serverTimestamp();

    // Use the recipe ID if provided, otherwise generate one
    final recipeId =
        recipeData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    await _recipesCollection.doc(recipeId).set(recipeData);
    return recipeId;
  }

  // Get all saved recipes
  Stream<List<Map<String, dynamic>>> getSavedRecipes() {
    if (userId == null) return Stream.value([]);

    return _recipesCollection
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  // Get saved recipes once (Future)
  Future<List<Map<String, dynamic>>> getSavedRecipesOnce() async {
    if (userId == null) return [];

    try {
      final snapshot = await _recipesCollection
          .orderBy('savedAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting saved recipes: $e');
      return [];
    }
  }

  // Delete a recipe
  Future<void> deleteRecipe(String recipeId) async {
    if (userId == null) throw Exception('User not logged in');
    await _recipesCollection.doc(recipeId).delete();
  }

  // Check if recipe is saved
  Future<bool> isRecipeSaved(String recipeId) async {
    if (userId == null) return false;
    final doc = await _recipesCollection.doc(recipeId).get();
    return doc.exists;
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

// Daily Task Model
class DailyTask {
  final String id;
  final String title;
  final String emoji;
  final String type; // meal, walk, medication, play, appointment
  final String scheduledTime;
  final DateTime scheduledDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? notes;

  DailyTask({
    required this.id,
    required this.title,
    required this.emoji,
    required this.type,
    required this.scheduledTime,
    required this.scheduledDate,
    this.isCompleted = false,
    this.completedAt,
    this.notes,
  });

  factory DailyTask.fromFirestore(String id, Map<String, dynamic> data) {
    return DailyTask(
      id: id,
      title: data['title'] ?? '',
      emoji: data['emoji'] ?? '📋',
      type: data['type'] ?? 'other',
      scheduledTime: data['scheduledTime'] ?? '',
      scheduledDate:
          (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCompleted: data['isCompleted'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'emoji': emoji,
    'type': type,
    'scheduledTime': scheduledTime,
    'scheduledDate': Timestamp.fromDate(scheduledDate),
    'isCompleted': isCompleted,
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!)
        : null,
    'notes': notes,
  };

  bool get isDueNow {
    final now = DateTime.now();
    final diff = scheduledDate.difference(now).inMinutes;
    return !isCompleted && diff <= 30 && diff >= -30;
  }

  DailyTask copyWith({bool? isCompleted, DateTime? completedAt}) {
    return DailyTask(
      id: id,
      title: title,
      emoji: emoji,
      type: type,
      scheduledTime: scheduledTime,
      scheduledDate: scheduledDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      notes: notes,
    );
  }
}

// Pet Stats Model
class PetStats {
  final int mealsLogged;
  final int mealsPlanned;
  final int steps;
  final int stepsGoal;
  final int waterCups;
  final int waterGoal;
  final int medsCompleted;
  final int medsPlanned;
  final DateTime? lastUpdated;

  PetStats({
    required this.mealsLogged,
    required this.mealsPlanned,
    required this.steps,
    required this.stepsGoal,
    required this.waterCups,
    required this.waterGoal,
    required this.medsCompleted,
    required this.medsPlanned,
    this.lastUpdated,
  });

  factory PetStats.empty() => PetStats(
    mealsLogged: 0,
    mealsPlanned: 3,
    steps: 0,
    stepsGoal: 10000,
    waterCups: 0,
    waterGoal: 8,
    medsCompleted: 0,
    medsPlanned: 0,
  );

  factory PetStats.fromFirestore(Map<String, dynamic> data) {
    return PetStats(
      mealsLogged: data['mealsLogged'] ?? 0,
      mealsPlanned: data['mealsPlanned'] ?? 3,
      steps: data['steps'] ?? 0,
      stepsGoal: data['stepsGoal'] ?? 10000,
      waterCups: data['waterCups'] ?? 0,
      waterGoal: data['waterGoal'] ?? 8,
      medsCompleted: data['medsCompleted'] ?? 0,
      medsPlanned: data['medsPlanned'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'mealsLogged': mealsLogged,
    'mealsPlanned': mealsPlanned,
    'steps': steps,
    'stepsGoal': stepsGoal,
    'waterCups': waterCups,
    'waterGoal': waterGoal,
    'medsCompleted': medsCompleted,
    'medsPlanned': medsPlanned,
    'lastUpdated': FieldValue.serverTimestamp(),
  };

  // Calculate dynamic health scores based on actual activity
  int get nutritionScore {
    if (mealsPlanned == 0) return 0;
    return ((mealsLogged / mealsPlanned) * 25).clamp(0, 25).round();
  }

  int get exerciseScore {
    if (stepsGoal == 0) return 0;
    return ((steps / stepsGoal) * 25).clamp(0, 25).round();
  }

  int get hydrationScore {
    if (waterGoal == 0) return 0;
    return ((waterCups / waterGoal) * 25).clamp(0, 25).round();
  }

  int get medicalScore {
    if (medsPlanned == 0) return 25; // Full score if no meds needed
    return ((medsCompleted / medsPlanned) * 25).clamp(0, 25).round();
  }

  // Total health score (0-100)
  int get calculatedHealthScore =>
      nutritionScore + exerciseScore + hydrationScore + medicalScore;
}

// Gamification Data Model
class GamificationData {
  final int level;
  final int currentXP;
  final int xpForNextLevel;
  final int totalXP;
  final int streak;
  final int longestStreak;
  final DateTime? lastStreakDate;
  final List<String> achievements;

  GamificationData({
    required this.level,
    required this.currentXP,
    required this.xpForNextLevel,
    required this.totalXP,
    required this.streak,
    required this.longestStreak,
    this.lastStreakDate,
    required this.achievements,
  });

  factory GamificationData.initial() => GamificationData(
    level: 1,
    currentXP: 0,
    xpForNextLevel: 1000,
    totalXP: 0,
    streak: 0,
    longestStreak: 0,
    achievements: [],
  );

  factory GamificationData.fromFirestore(Map<String, dynamic> data) {
    return GamificationData(
      level: data['level'] ?? 1,
      currentXP: data['currentXP'] ?? 0,
      xpForNextLevel: data['xpForNextLevel'] ?? 1000,
      totalXP: data['totalXP'] ?? 0,
      streak: data['streak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      lastStreakDate: (data['lastStreakDate'] as Timestamp?)?.toDate(),
      achievements: List<String>.from(data['achievements'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'level': level,
    'currentXP': currentXP,
    'xpForNextLevel': xpForNextLevel,
    'totalXP': totalXP,
    'streak': streak,
    'longestStreak': longestStreak,
    'lastStreakDate': lastStreakDate != null
        ? Timestamp.fromDate(lastStreakDate!)
        : null,
    'achievements': achievements,
  };
}

// Dog Profile Model
class DogProfile {
  final String id;
  final String name;
  final String? photoUrl;
  final String breed;
  final double breedConfidence;
  final String ageGroup;
  final int? ageYears;
  final String size;
  final double weight;
  final String activityLevel;
  final List<String> dietaryPreferences;
  final List<String> allergies;
  final DateTime? createdAt;

  DogProfile({
    required this.id,
    required this.name,
    this.photoUrl,
    this.breed = '',
    this.breedConfidence = 0.0,
    this.ageGroup = 'adult',
    this.ageYears,
    this.size = 'medium',
    this.weight = 0.0,
    this.activityLevel = 'moderate',
    this.dietaryPreferences = const [],
    this.allergies = const [],
    this.createdAt,
  });

  factory DogProfile.fromFirestore(String id, Map<String, dynamic> data) {
    // Try photoUrl first, then fallback to photoPath (from onboarding)
    final photo = data['photoUrl'] ?? data['photoPath'];

    return DogProfile(
      id: id,
      name: data['name'] ?? '',
      photoUrl: photo,
      breed: data['breed'] ?? '',
      breedConfidence: (data['breedConfidence'] ?? 0.0).toDouble(),
      ageGroup: data['ageGroup'] ?? 'adult',
      ageYears: data['ageYears'],
      size: data['size'] ?? 'medium',
      weight: (data['weight'] ?? 0.0).toDouble(),
      activityLevel: data['activityLevel'] ?? 'moderate',
      dietaryPreferences: List<String>.from(data['dietaryPreferences'] ?? []),
      allergies: List<String>.from(data['allergies'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'photoUrl': photoUrl,
    'breed': breed,
    'breedConfidence': breedConfidence,
    'ageGroup': ageGroup,
    'ageYears': ageYears,
    'size': size,
    'weight': weight,
    'activityLevel': activityLevel,
    'dietaryPreferences': dietaryPreferences,
    'allergies': allergies,
  };
}

// ============================================================================
// HEALTH CONSULTATIONS
// ============================================================================

extension FirestoreServiceConsultations on FirestoreService {
  CollectionReference<Map<String, dynamic>> _consultationsCollection(
    String dogId,
  ) => _dogsCollection.doc(dogId).collection('consultations');

  /// Save a consultation session to Firestore
  Future<String> saveConsultation(Map<String, dynamic> consultationData) async {
    if (userId == null) throw Exception('User not logged in');

    final dogId = consultationData['dogId'] as String?;
    if (dogId == null) throw Exception('Dog ID required');

    consultationData['savedAt'] = FieldValue.serverTimestamp();

    final consultationId =
        consultationData['id'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString();

    await _consultationsCollection(
      dogId,
    ).doc(consultationId).set(consultationData);
    return consultationId;
  }

  /// Get consultation history for a dog
  Future<List<Map<String, dynamic>>> getConsultationHistory(
    String dogId,
  ) async {
    if (userId == null) return [];

    try {
      final snapshot = await _consultationsCollection(
        dogId,
      ).orderBy('startedAt', descending: true).limit(20).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting consultation history: $e');
      return [];
    }
  }

  /// Get complete dog health context for AI prompts
  /// Includes profile, medical history, vaccinations, medications from onboarding
  Future<Map<String, dynamic>> getDogHealthContext(String dogId) async {
    if (userId == null) return {};

    try {
      // Get dog profile
      final dogDoc = await _dogsCollection.doc(dogId).get();
      if (!dogDoc.exists) return {};

      final profile = dogDoc.data()!;

      // Get recent consultations for context
      final recentConsultations = await getConsultationHistory(dogId);
      final lastConsultation = recentConsultations.isNotEmpty
          ? recentConsultations.first
          : null;

      return {
        // Basic profile
        'name': profile['name'] ?? '',
        'breed': profile['breed'] ?? '',
        'ageGroup': profile['ageGroup'] ?? 'adult',
        'ageYears': profile['ageYears'],
        'size': profile['size'] ?? 'medium',
        'weight': profile['weight'] ?? 0.0,
        'activityLevel': profile['activityLevel'] ?? 'moderate',

        // Medical info (from onboarding)
        'allergies': List<String>.from(profile['allergies'] ?? []),
        'dietaryPreferences': List<String>.from(
          profile['dietaryPreferences'] ?? [],
        ),
        'medicalConditions': List<String>.from(
          profile['medicalConditions'] ?? [],
        ),
        'medications': List<String>.from(profile['medications'] ?? []),
        'surgeryHistory': List<String>.from(profile['surgeryHistory'] ?? []),
        'vaccinations': profile['vaccinations'] ?? [],

        // Vet & Insurance
        'vetClinicName': profile['vetClinicName'],
        'vetPhone': profile['vetPhone'],
        'emergencyContact': profile['emergencyContact'],

        // Recent consultation
        'lastConsultation': lastConsultation != null
            ? {
                'date': lastConsultation['startedAt'],
                'summary': lastConsultation['summary'],
              }
            : null,
      };
    } catch (e) {
      print('Error getting dog health context: $e');
      return {};
    }
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

final dogProfilesProvider = StreamProvider<List<DogProfile>>((ref) {
  return ref.watch(firestoreServiceProvider).getDogProfiles();
});

final hasCompletedOnboardingProvider = FutureProvider<bool>((ref) {
  return ref.watch(firestoreServiceProvider).hasCompletedOnboarding();
});

final currentDogIdProvider = FutureProvider<String?>((ref) {
  return ref.watch(firestoreServiceProvider).getCurrentDogId();
});

// Provider for today's tasks - requires dogId
final todayTasksProvider = StreamProvider.family<List<DailyTask>, String>((
  ref,
  dogId,
) {
  return ref.watch(firestoreServiceProvider).getTodayTasks(dogId);
});

// Provider for pet stats - requires dogId
final petStatsProvider = StreamProvider.family<PetStats, String>((ref, dogId) {
  return ref.watch(firestoreServiceProvider).getPetStats(dogId);
});

// Provider for gamification data - requires dogId
final gamificationProvider = StreamProvider.family<GamificationData, String>((
  ref,
  dogId,
) {
  return ref.watch(firestoreServiceProvider).getGamificationData(dogId);
});
