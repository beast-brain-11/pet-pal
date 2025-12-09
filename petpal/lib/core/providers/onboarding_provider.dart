// Onboarding State Provider
// Manages survey data across all onboarding screens
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class OnboardingData {
  final String name;
  final String? photoPath;
  final String breed;
  final double breedConfidence;
  final String ageGroup;
  final int? ageYears;
  final String size;
  final double weight;
  final String activityLevel;
  final List<String> dietaryPreferences;
  final List<String> allergies;

  // Vaccination History
  final List<VaccinationRecord> vaccinations;
  final DateTime? lastVetVisit;

  // Medical History
  final List<String> medicalConditions;
  final List<String> medications;
  final List<String> surgeryHistory;

  // Vet & Insurance
  final String? vetClinicName;
  final String? vetPhone;
  final String? insuranceProvider;
  final String? policyNumber;
  final String? emergencyContact;

  // Documents
  final List<String> documentPaths;

  final int currentStep;

  OnboardingData({
    this.name = '',
    this.photoPath,
    this.breed = '',
    this.breedConfidence = 0.0,
    this.ageGroup = 'adult',
    this.ageYears,
    this.size = 'medium',
    this.weight = 30.0,
    this.activityLevel = 'moderate',
    this.dietaryPreferences = const [],
    this.allergies = const [],
    this.vaccinations = const [],
    this.lastVetVisit,
    this.medicalConditions = const [],
    this.medications = const [],
    this.surgeryHistory = const [],
    this.vetClinicName,
    this.vetPhone,
    this.insuranceProvider,
    this.policyNumber,
    this.emergencyContact,
    this.documentPaths = const [],
    this.currentStep = 0,
  });

  OnboardingData copyWith({
    String? name,
    String? photoPath,
    String? breed,
    double? breedConfidence,
    String? ageGroup,
    int? ageYears,
    String? size,
    double? weight,
    String? activityLevel,
    List<String>? dietaryPreferences,
    List<String>? allergies,
    List<VaccinationRecord>? vaccinations,
    DateTime? lastVetVisit,
    List<String>? medicalConditions,
    List<String>? medications,
    List<String>? surgeryHistory,
    String? vetClinicName,
    String? vetPhone,
    String? insuranceProvider,
    String? policyNumber,
    String? emergencyContact,
    List<String>? documentPaths,
    int? currentStep,
  }) {
    return OnboardingData(
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      breed: breed ?? this.breed,
      breedConfidence: breedConfidence ?? this.breedConfidence,
      ageGroup: ageGroup ?? this.ageGroup,
      ageYears: ageYears ?? this.ageYears,
      size: size ?? this.size,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      allergies: allergies ?? this.allergies,
      vaccinations: vaccinations ?? this.vaccinations,
      lastVetVisit: lastVetVisit ?? this.lastVetVisit,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      medications: medications ?? this.medications,
      surgeryHistory: surgeryHistory ?? this.surgeryHistory,
      vetClinicName: vetClinicName ?? this.vetClinicName,
      vetPhone: vetPhone ?? this.vetPhone,
      insuranceProvider: insuranceProvider ?? this.insuranceProvider,
      policyNumber: policyNumber ?? this.policyNumber,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      documentPaths: documentPaths ?? this.documentPaths,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'photoPath': photoPath,
    'photoUrl': photoPath, // Also save as photoUrl for compatibility
    'breed': breed,
    'breedConfidence': breedConfidence,
    'ageGroup': ageGroup,
    'ageYears': ageYears,
    'size': size,
    'weight': weight,
    'activityLevel': activityLevel,
    'dietaryPreferences': dietaryPreferences,
    'allergies': allergies,
    'vaccinations': vaccinations.map((v) => v.toMap()).toList(),
    'lastVetVisit': lastVetVisit?.toIso8601String(),
    'medicalConditions': medicalConditions,
    'medications': medications,
    'surgeryHistory': surgeryHistory,
    'vetClinicName': vetClinicName,
    'vetPhone': vetPhone,
    'insuranceProvider': insuranceProvider,
    'policyNumber': policyNumber,
    'emergencyContact': emergencyContact,
    'documentPaths': documentPaths,
  };
}

class VaccinationRecord {
  final String name;
  final DateTime? date;
  final DateTime? nextDue;
  final bool isCompleted;

  VaccinationRecord({
    required this.name,
    this.date,
    this.nextDue,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'date': date?.toIso8601String(),
    'nextDue': nextDue?.toIso8601String(),
    'isCompleted': isCompleted,
  };
}

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  final FirestoreService _firestoreService;

  OnboardingNotifier(this._firestoreService) : super(OnboardingData());

  void updateName(String name) {
    state = state.copyWith(name: name);
    _saveProgress();
  }

  void updatePhoto(String path) {
    state = state.copyWith(photoPath: path);
    _saveProgress();
  }

  void updateBreed(String breed, double confidence) {
    state = state.copyWith(breed: breed, breedConfidence: confidence);
    _saveProgress();
  }

  void updateAge(String ageGroup, {int? years}) {
    state = state.copyWith(ageGroup: ageGroup, ageYears: years);
    _saveProgress();
  }

  void updateSize(String size) {
    state = state.copyWith(size: size);
    _saveProgress();
  }

  void updateWeight(double weight) {
    state = state.copyWith(weight: weight);
    _saveProgress();
  }

  void updateActivityLevel(String level) {
    state = state.copyWith(activityLevel: level);
    _saveProgress();
  }

  void updateDietaryPreferences(List<String> prefs) {
    state = state.copyWith(dietaryPreferences: prefs);
    _saveProgress();
  }

  void updateAllergies(List<String> allergies) {
    state = state.copyWith(allergies: allergies);
    _saveProgress();
  }

  void updateVaccinations(List<VaccinationRecord> vaccinations) {
    state = state.copyWith(vaccinations: vaccinations);
    _saveProgress();
  }

  void updateLastVetVisit(DateTime? date) {
    state = state.copyWith(lastVetVisit: date);
    _saveProgress();
  }

  void updateMedicalConditions(List<String> conditions) {
    state = state.copyWith(medicalConditions: conditions);
    _saveProgress();
  }

  void updateMedications(List<String> medications) {
    state = state.copyWith(medications: medications);
    _saveProgress();
  }

  void updateSurgeryHistory(List<String> surgeries) {
    state = state.copyWith(surgeryHistory: surgeries);
    _saveProgress();
  }

  void updateVetInfo({String? clinicName, String? phone}) {
    state = state.copyWith(vetClinicName: clinicName, vetPhone: phone);
    _saveProgress();
  }

  void updateInsurance({String? provider, String? policyNumber}) {
    state = state.copyWith(
      insuranceProvider: provider,
      policyNumber: policyNumber,
    );
    _saveProgress();
  }

  void updateEmergencyContact(String contact) {
    state = state.copyWith(emergencyContact: contact);
    _saveProgress();
  }

  void addDocument(String path) {
    state = state.copyWith(documentPaths: [...state.documentPaths, path]);
    _saveProgress();
  }

  void removeDocument(String path) {
    state = state.copyWith(
      documentPaths: state.documentPaths.where((p) => p != path).toList(),
    );
    _saveProgress();
  }

  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  Future<void> _saveProgress() async {
    try {
      await _firestoreService.saveOnboardingProgress(state.toMap());
    } catch (e) {
      // Silently fail - data will still be in memory
    }
  }

  Future<String> completeOnboarding() async {
    // Upload photo to Firebase Storage if exists
    String? photoUrl;
    if (state.photoPath != null && state.photoPath!.isNotEmpty) {
      try {
        final storageService = StorageService();
        photoUrl = await storageService.uploadDogPhoto(state.photoPath!);
        if (photoUrl != null) {
          // Update state with the cloud URL
          state = state.copyWith(photoPath: photoUrl);
          await _saveProgress();
        }
      } catch (e) {
        print('Error uploading photo: $e');
        // Continue without photo upload
      }
    }

    final dogId = await _firestoreService.completeOnboarding();

    // Initialize default data for the new dog
    try {
      await _firestoreService.initializeDefaultTasks(dogId, state.name);
      await _firestoreService.initializeDefaultStats(dogId);
      await _firestoreService.initializeGamification(dogId);
    } catch (e) {
      // Silent fail - core data is saved, extras are optional
      print('Error initializing default data: $e');
    }

    return dogId;
  }

  void reset() {
    state = OnboardingData();
  }
}

// Provider
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>((ref) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return OnboardingNotifier(firestoreService);
    });
