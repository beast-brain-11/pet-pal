// Dog Profile Provider
// Manages dog profile state across the app

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dog Profile Model
class DogProfile {
  final String? id;
  final String name;
  final String? photoPath;
  final String breed;
  final double confidence;
  final String ageGroup;
  final int? ageYears;
  final String size;
  final double weightLbs;
  final String activityLevel;
  final List<String> dietaryPreferences;
  final List<String> allergies;
  final bool isOnboardingComplete;

  DogProfile({
    this.id,
    this.name = '',
    this.photoPath,
    this.breed = '',
    this.confidence = 0.0,
    this.ageGroup = 'adult',
    this.ageYears,
    this.size = 'medium',
    this.weightLbs = 30.0,
    this.activityLevel = 'moderate',
    this.dietaryPreferences = const [],
    this.allergies = const [],
    this.isOnboardingComplete = false,
  });

  DogProfile copyWith({
    String? id,
    String? name,
    String? photoPath,
    String? breed,
    double? confidence,
    String? ageGroup,
    int? ageYears,
    String? size,
    double? weightLbs,
    String? activityLevel,
    List<String>? dietaryPreferences,
    List<String>? allergies,
    bool? isOnboardingComplete,
  }) {
    return DogProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      breed: breed ?? this.breed,
      confidence: confidence ?? this.confidence,
      ageGroup: ageGroup ?? this.ageGroup,
      ageYears: ageYears ?? this.ageYears,
      size: size ?? this.size,
      weightLbs: weightLbs ?? this.weightLbs,
      activityLevel: activityLevel ?? this.activityLevel,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      allergies: allergies ?? this.allergies,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'photoPath': photoPath,
    'breed': breed,
    'confidence': confidence,
    'ageGroup': ageGroup,
    'ageYears': ageYears,
    'size': size,
    'weightLbs': weightLbs,
    'activityLevel': activityLevel,
    'dietaryPreferences': dietaryPreferences,
    'allergies': allergies,
    'isOnboardingComplete': isOnboardingComplete,
  };

  factory DogProfile.fromJson(Map<String, dynamic> json) => DogProfile(
    id: json['id'],
    name: json['name'] ?? '',
    photoPath: json['photoPath'],
    breed: json['breed'] ?? '',
    confidence: (json['confidence'] ?? 0.0).toDouble(),
    ageGroup: json['ageGroup'] ?? 'adult',
    ageYears: json['ageYears'],
    size: json['size'] ?? 'medium',
    weightLbs: (json['weightLbs'] ?? 30.0).toDouble(),
    activityLevel: json['activityLevel'] ?? 'moderate',
    dietaryPreferences: List<String>.from(json['dietaryPreferences'] ?? []),
    allergies: List<String>.from(json['allergies'] ?? []),
    isOnboardingComplete: json['isOnboardingComplete'] ?? false,
  );

  // Helper getters
  String get ageDisplay {
    if (ageYears != null) return '$ageYears years old';
    return ageGroup.replaceFirst(ageGroup[0], ageGroup[0].toUpperCase());
  }

  String get sizeDisplay => size.replaceFirst(size[0], size[0].toUpperCase());

  String get weightDisplay => '${weightLbs.toStringAsFixed(0)} lbs';
}

// Dog Profile Notifier
class DogProfileNotifier extends StateNotifier<DogProfile> {
  DogProfileNotifier() : super(DogProfile());

  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  void updatePhoto(String path) {
    state = state.copyWith(photoPath: path);
  }

  void updateBreed(String breed, double confidence) {
    state = state.copyWith(breed: breed, confidence: confidence);
  }

  void updateAge(String ageGroup, {int? years}) {
    state = state.copyWith(ageGroup: ageGroup, ageYears: years);
  }

  void updateSize(String size) {
    state = state.copyWith(size: size);
  }

  void updateWeight(double weightLbs) {
    state = state.copyWith(weightLbs: weightLbs);
  }

  void updateActivityLevel(String level) {
    state = state.copyWith(activityLevel: level);
  }

  void updateDietaryPreferences(List<String> prefs) {
    state = state.copyWith(dietaryPreferences: prefs);
  }

  void updateAllergies(List<String> allergies) {
    state = state.copyWith(allergies: allergies);
  }

  void completeOnboarding() {
    state = state.copyWith(isOnboardingComplete: true);
  }

  void reset() {
    state = DogProfile();
  }

  // Load from storage (TODO: implement with Hive/Firebase)
  Future<void> loadProfile() async {
    // Will load from Hive/Firebase when integrated
  }

  // Save to storage (TODO: implement with Hive/Firebase)
  Future<void> saveProfile() async {
    // Will save to Hive/Firebase when integrated
  }
}

// Providers
final dogProfileProvider =
    StateNotifierProvider<DogProfileNotifier, DogProfile>(
      (ref) => DogProfileNotifier(),
    );

// Convenience providers
final dogNameProvider = Provider<String>((ref) {
  return ref.watch(dogProfileProvider).name;
});

final dogBreedProvider = Provider<String>((ref) {
  return ref.watch(dogProfileProvider).breed;
});

final isOnboardingCompleteProvider = Provider<bool>((ref) {
  return ref.watch(dogProfileProvider).isOnboardingComplete;
});
