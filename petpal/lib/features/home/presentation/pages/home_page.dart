// Home Page - Main Dashboard (Complete Rebuild with Real Data)
// PetPal's heart - Tamagotchi-style interactive pet care dashboard

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/services/walk_tracking_service.dart';
import 'package:geolocator/geolocator.dart';

// ============================================================================
// COLOR SCHEME (Aligned with AppColors for consistency)
// ============================================================================
class HomeColors {
  // Primary colors - matching AppColors for consistency
  static const primary = Color(0xFF4043F2); // AppColors.primary
  static const primaryLight = Color(0xFF6363F2); // AppColors.primaryLight
  static const secondary = Color(0xFF7579F3); // From AppColors gradient
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const background = Color(0xFFF6F6F8); // AppColors.backgroundLight
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111118); // AppColors.black
  static const textSecondary = Color(0xFF616289); // AppColors.grey

  // Health score gradients
  static const healthGreenStart = Color(0xFF10B981);
  static const healthGreenEnd = Color(0xFF34D399);
  static const healthYellowStart = Color(0xFFF59E0B);
  static const healthYellowEnd = Color(0xFFFBBF24);
  static const healthOrangeStart = Color(0xFFF97316);
  static const healthOrangeEnd = Color(0xFFFB923C);
  static const healthRedStart = Color(0xFFEF4444);
  static const healthRedEnd = Color(0xFFF87171);
}

// ============================================================================
// AVATAR STATE ENUM
// ============================================================================
enum AvatarState {
  sleeping,
  active,
  hungry,
  happy,
  needsAttention,
  celebrating,
}

// ============================================================================
// MAIN HOME PAGE
// ============================================================================
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _avatarBounceController;
  late AnimationController _healthRingController;
  late AnimationController _streakFlameController;
  late Animation<double> _avatarBounceAnimation;
  late Animation<double> _healthRingAnimation;
  late Animation<double> _streakFlameAnimation;

  AvatarState _avatarState = AvatarState.happy;
  String? _currentDogId;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _avatarBounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _avatarBounceAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _avatarBounceController, curve: Curves.easeInOut),
    );

    _healthRingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    _healthRingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _healthRingController,
        curve: Curves.easeOutCubic,
      ),
    );

    _streakFlameController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _streakFlameAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _streakFlameController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _avatarBounceController.dispose();
    _healthRingController.dispose();
    _streakFlameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dogProfiles = ref.watch(dogProfilesProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HomeColors.primary, Color(0xFF818CF8)],
          ),
        ),
        child: SafeArea(
          child: dogProfiles.when(
            data: (dogs) {
              if (dogs.isEmpty) {
                return _buildNoDogState();
              }

              final dog = dogs.first;
              _currentDogId = dog.id;

              return _buildMainContent(dog);
            },
            loading: () => _buildLoadingState(),
            error: (e, _) => _buildErrorState(e.toString()),
          ),
        ),
      ),
      floatingActionButton: _buildQuickActionsBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildNoDogState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🐕', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          const Text(
            'No pet profile found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete onboarding to get started',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.surveyWelcome),
            child: const Text('Add Your Pet'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text('Error: $error', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(dogProfilesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(DogProfile dog) {
    // Watch real-time data for this dog
    final tasksAsync = ref.watch(todayTasksProvider(dog.id));
    final statsAsync = ref.watch(petStatsProvider(dog.id));
    final gamificationAsync = ref.watch(gamificationProvider(dog.id));

    return Column(
      children: [
        _buildAppBar(dog),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: HomeColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Avatar Section with real stats
                  statsAsync.when(
                    data: (stats) => gamificationAsync.when(
                      data: (gamification) =>
                          _buildAvatarSection(dog, stats, gamification),
                      loading: () => _buildAvatarSection(
                        dog,
                        PetStats.empty(),
                        GamificationData.initial(),
                      ),
                      error: (_, __) => _buildAvatarSection(
                        dog,
                        PetStats.empty(),
                        GamificationData.initial(),
                      ),
                    ),
                    loading: () => _buildAvatarSection(
                      dog,
                      PetStats.empty(),
                      GamificationData.initial(),
                    ),
                    error: (_, __) => _buildAvatarSection(
                      dog,
                      PetStats.empty(),
                      GamificationData.initial(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Stats with real data
                  statsAsync.when(
                    data: (stats) => _buildQuickStats(stats),
                    loading: () => _buildQuickStats(PetStats.empty()),
                    error: (_, __) => _buildQuickStats(PetStats.empty()),
                  ),

                  const SizedBox(height: 20),

                  // Calendar + Social section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: 320,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 60,
                            child: tasksAsync.when(
                              data: (tasks) =>
                                  _buildCalendarSection(dog.id, tasks),
                              loading: () => _buildCalendarSection(dog.id, []),
                              error: (_, __) =>
                                  _buildCalendarSection(dog.id, []),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(flex: 40, child: _buildSocialFeed()),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Achievement Section with real data
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: gamificationAsync.when(
                      data: (gamification) =>
                          _buildAchievementSection(gamification),
                      loading: () =>
                          _buildAchievementSection(GamificationData.initial()),
                      error: (_, __) =>
                          _buildAchievementSection(GamificationData.initial()),
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    ref.invalidate(dogProfilesProvider);
    if (_currentDogId != null) {
      ref.invalidate(todayTasksProvider(_currentDogId!));
      ref.invalidate(petStatsProvider(_currentDogId!));
      ref.invalidate(gamificationProvider(_currentDogId!));
    }
    await Future.delayed(const Duration(seconds: 1));
  }

  // ============================================================================
  // APP BAR
  // ============================================================================
  Widget _buildAppBar(DogProfile dog) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PetPal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Hi, ${dog.name}! 👋',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildAppBarButton(Icons.notifications_outlined, () {}),
              const SizedBox(width: 8),
              _buildAppBarButton(Icons.person_outline, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ============================================================================
  // AVATAR SECTION
  // ============================================================================
  Widget _buildAvatarSection(
    DogProfile dog,
    PetStats stats,
    GamificationData gamification,
  ) {
    final healthScore = stats.calculatedHealthScore;

    return GestureDetector(
      onTap: _onAvatarTap,
      onLongPress: _onAvatarLongPress,
      onDoubleTap: () => _showHealthBreakdown(stats),
      child: Column(
        children: [
          _buildStatusBadge(),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _avatarBounceAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -_avatarBounceAnimation.value),
                child: _buildHealthRingAndAvatar(dog, healthScore),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            dog.name.isEmpty ? 'Your Pet' : dog.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dog.breed.isEmpty ? 'Unknown Breed' : dog.breed,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          _buildStreakCounter(gamification.streak),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    String emoji = '😊';
    String text = 'Happy & Healthy';
    Color bgColor = HomeColors.success;

    switch (_avatarState) {
      case AvatarState.active:
        emoji = '🚶';
        text = 'Out for Walk';
        bgColor = HomeColors.secondary;
        break;
      case AvatarState.sleeping:
        emoji = '😴';
        text = 'Resting';
        bgColor = Colors.purple;
        break;
      case AvatarState.hungry:
        emoji = '🍖';
        text = 'Meal Time Soon';
        bgColor = HomeColors.warning;
        break;
      case AvatarState.needsAttention:
        emoji = '🏥';
        text = 'Needs Attention';
        bgColor = HomeColors.danger;
        break;
      case AvatarState.celebrating:
        emoji = '🎉';
        text = 'Celebrating!';
        bgColor = HomeColors.success;
        break;
      case AvatarState.happy:
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRingAndAvatar(DogProfile dog, int healthScore) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _healthRingAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(220, 220),
                painter: HealthRingPainter(
                  progress: _healthRingAnimation.value * (healthScore / 100),
                  healthScore: healthScore,
                ),
              );
            },
          ),
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HomeColors.primary,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
              image: _getAvatarImage(dog.photoUrl),
            ),
            child: _getAvatarImage(dog.photoUrl) == null
                ? const Center(
                    child: Text('🐕', style: TextStyle(fontSize: 70)),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _getHealthColor(healthScore),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _getHealthColor(healthScore).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$healthScore',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DecorationImage? _getAvatarImage(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) {
      // Default placeholder - just show icon instead
      return null;
    }

    // Check if it's a local file path
    if (photoPath.startsWith('/') ||
        photoPath.startsWith('C:') ||
        photoPath.contains('\\')) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return DecorationImage(image: FileImage(file), fit: BoxFit.cover);
      }
    }

    // Check if it's a network URL
    if (photoPath.startsWith('http')) {
      return DecorationImage(image: NetworkImage(photoPath), fit: BoxFit.cover);
    }

    return null;
  }

  Color _getHealthColor(int healthScore) {
    if (healthScore >= 90) return HomeColors.success;
    if (healthScore >= 70) return HomeColors.warning;
    if (healthScore >= 50) return HomeColors.warning;
    return HomeColors.danger;
  }

  Widget _buildStreakCounter(int streakDays) {
    return AnimatedBuilder(
      animation: _streakFlameAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: _streakFlameAnimation.value,
                child: const Text('🔥', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streakDays > 0
                        ? '$streakDays-Day Streak!'
                        : 'Start Your Streak!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    streakDays > 0
                        ? 'Perfect care every day!'
                        : 'Complete all tasks today',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _onAvatarTap() async {
    HapticFeedback.lightImpact();
    if (_currentDogId != null) {
      // Award XP for interaction
      ref.read(firestoreServiceProvider).addXP(_currentDogId!, 5);
    }

    // Show loading indicator first
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Generating a fun fact...'),
          ],
        ),
        backgroundColor: HomeColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );

    // Get the dog profile for context
    final dogs = ref.read(dogProfilesProvider).value;
    final dog = dogs?.isNotEmpty == true ? dogs!.first : null;
    final dogName = dog?.name ?? 'Your dog';
    final breed = dog?.breed ?? 'dog';

    // Generate dynamic fact using AI
    try {
      final gemini = GeminiService();
      final fact = await gemini.generatePetFact(dogName: dogName, breed: breed);

      if (!mounted) return;
      _showFactCard(fact);
    } catch (e) {
      if (!mounted) return;
      // Fallback to static fact
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('🐕 ', style: TextStyle(fontSize: 20)),
              Expanded(child: Text('Dogs dream just like humans!')),
            ],
          ),
          backgroundColor: HomeColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showFactCard(PetFactResult fact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HomeColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🐕', style: TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Did You Know?',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fact.shortFact,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: HomeColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              fact.fullFact,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Implement share functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share feature coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Got it!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HomeColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onAvatarLongPress() {
    HapticFeedback.heavyImpact();
    if (_currentDogId != null) {
      ref.read(firestoreServiceProvider).addXP(_currentDogId!, 10);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Text('❤️ ', style: TextStyle(fontSize: 20)),
            Text('+10 XP for bonding with your pet!'),
          ],
        ),
        backgroundColor: HomeColors.danger.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showHealthBreakdown(PetStats stats) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Health Score Breakdown',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildHealthCategory(
              '🍖 Nutrition',
              stats.nutritionScore,
              25,
              HomeColors.warning,
            ),
            const SizedBox(height: 16),
            _buildHealthCategory(
              '🏃 Exercise',
              stats.exerciseScore,
              25,
              HomeColors.success,
            ),
            const SizedBox(height: 16),
            _buildHealthCategory(
              '💊 Medical',
              stats.medicalScore,
              25,
              HomeColors.success,
            ),
            const SizedBox(height: 16),
            _buildHealthCategory(
              '💧 Hydration',
              stats.hydrationScore,
              25,
              HomeColors.secondary,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HomeColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Total: ${stats.calculatedHealthScore}/100',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: HomeColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCategory(String label, int score, int max, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            Text(
              '$score/$max',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / max,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // QUICK STATS - 2x2 QUAD GRID LAYOUT
  // ============================================================================
  Widget _buildQuickStats(PetStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // First row: Meals & Steps
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  QuickStat(
                    icon: '🍖',
                    label: 'Meals',
                    value: '${stats.mealsLogged}/${stats.mealsPlanned}',
                    color: HomeColors.warning,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  QuickStat(
                    icon: '🐾',
                    label: 'Steps',
                    value: _formatNumber(stats.steps),
                    color: HomeColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row: Water & Meds
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  QuickStat(
                    icon: '💧',
                    label: 'Water',
                    value: '${stats.waterCups}/${stats.waterGoal}',
                    color: const Color(0xFF06B6D4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  QuickStat(
                    icon: '💊',
                    label: 'Meds',
                    value: stats.medsPlanned == 0
                        ? 'N/A'
                        : (stats.medsCompleted == stats.medsPlanned
                              ? 'All ✓'
                              : '${stats.medsCompleted}/${stats.medsPlanned}'),
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return num.toString();
  }

  Widget _buildStatCard(QuickStat stat) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stat.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(stat.icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  stat.label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // CALENDAR SECTION
  // ============================================================================
  Widget _buildCalendarSection(String dogId, List<DailyTask> tasks) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "📅 Today's Schedule",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.mealPlanner),
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWeekDaysRow(),
          const SizedBox(height: 12),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 8),
                        Text(
                          'No tasks yet!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Add your first task',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) =>
                        _buildTaskCard(dogId, tasks[index]),
                  ),
          ),
          _buildAddTaskButton(dogId),
        ],
      ),
    );
  }

  Widget _buildWeekDaysRow() {
    final now = DateTime.now();
    final days = <MapEntry<String, int>>[];
    for (int i = -2; i <= 4; i++) {
      final date = now.add(Duration(days: i));
      final dayName = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][date.weekday - 1];
      days.add(MapEntry(dayName, date.day));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: days.asMap().entries.map((entry) {
          final isToday = entry.key == 2;
          return Container(
            width: 40,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isToday
                  ? Colors.white.withOpacity(0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(color: Colors.white, width: 1.5)
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  entry.value.key,
                  style: TextStyle(
                    color: Colors.white.withOpacity(isToday ? 1 : 0.6),
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.value.value}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isToday ? 16 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskCard(String dogId, DailyTask task) {
    final taskColor = _getTaskColor(task.type);

    return Dismissible(
      key: Key('task_${task.id}'),
      direction: task.isCompleted
          ? DismissDirection.none
          : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && !task.isCompleted) {
          HapticFeedback.mediumImpact();
          await ref.read(firestoreServiceProvider).completeTask(dogId, task.id);
          await ref.read(firestoreServiceProvider).addXP(dogId, 10);
          await ref.read(firestoreServiceProvider).updateStreak(dogId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✅ +10 XP earned!'),
                backgroundColor: HomeColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: HomeColors.success,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: task.isDueNow
              ? HomeColors.danger.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: taskColor, width: 3)),
        ),
        child: Row(
          children: [
            Text(
              task.scheduledTime,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(task.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            Icon(
              task.isCompleted
                  ? Icons.check_circle
                  : (task.isDueNow
                        ? Icons.error
                        : Icons.radio_button_unchecked),
              color: task.isCompleted
                  ? HomeColors.success
                  : (task.isDueNow
                        ? HomeColors.danger
                        : Colors.white.withOpacity(0.5)),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Color _getTaskColor(String type) {
    switch (type) {
      case 'meal':
        return HomeColors.warning;
      case 'walk':
        return HomeColors.secondary;
      case 'medication':
        return Colors.purple;
      case 'play':
        return HomeColors.success;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAddTaskButton(String dogId) {
    return GestureDetector(
      onTap: () => _showAddTaskModal(dogId),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            '+ Add Task',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTaskModal(String dogId) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Task',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildTaskTypeOption(
              dogId,
              'meal',
              '🍖',
              'Add Meal',
              'Schedule feeding time',
            ),
            _buildTaskTypeOption(
              dogId,
              'walk',
              '🚶',
              'Add Walk',
              'Schedule a walk',
            ),
            _buildTaskTypeOption(
              dogId,
              'medication',
              '💊',
              'Add Medication',
              'Set med reminder',
            ),
            _buildTaskTypeOption(
              dogId,
              'play',
              '🎾',
              'Add Playtime',
              'Schedule fun activity',
            ),
            _buildTaskTypeOption(
              dogId,
              'appointment',
              '🏥',
              'Add Vet Visit',
              'Schedule appointment',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTypeOption(
    String dogId,
    String type,
    String emoji,
    String title,
    String subtitle,
  ) {
    final color = _getTaskColor(type);
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: const Icon(Icons.add_circle_outline, color: HomeColors.primary),
      onTap: () {
        Navigator.pop(context);
        _showTaskTimePickerModal(
          dogId,
          type,
          emoji,
          title.replaceAll('Add ', ''),
        );
      },
    );
  }

  void _showTaskTimePickerModal(
    String dogId,
    String type,
    String emoji,
    String title,
  ) async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Set time for $title',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: HomeColors.primary,
              onSurface: HomeColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null) return;

    final now = DateTime.now();
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // If time is in the past, schedule for tomorrow
    final finalDateTime = scheduledDateTime.isBefore(now)
        ? scheduledDateTime.add(const Duration(days: 1))
        : scheduledDateTime;

    final task = DailyTask(
      id: '',
      title: title,
      emoji: emoji,
      type: type,
      scheduledTime:
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
      scheduledDate: finalDateTime,
    );

    try {
      await ref.read(firestoreServiceProvider).addTask(dogId, task);
      if (mounted) {
        final timeStr = selectedTime.format(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$emoji $title scheduled for $timeStr!'),
            backgroundColor: HomeColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding task: $e'),
            backgroundColor: HomeColors.danger,
          ),
        );
      }
    }
  }

  // ============================================================================
  // SOCIAL FEED
  // ============================================================================
  Widget _buildSocialFeed() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  '🐾 Pack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🐕‍🦺', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 4),
                  Text(
                    'Connect with\nnearby pets!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard({
    required String name,
    required String content,
    String? distance,
    required String time,
    bool isAchievement = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isAchievement
                    ? Colors.amber
                    : Colors.white.withOpacity(0.3),
                child: Text(
                  isAchievement ? '🏆' : name[0],
                  style: TextStyle(
                    fontSize: isAchievement ? 12 : 10,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (distance != null)
                Text(
                  distance,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                time,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.favorite_border,
                size: 14,
                color: Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chat_bubble_outline,
                size: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard({required String title, required int likes}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HomeColors.warning.withOpacity(0.3),
            HomeColors.danger.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🔥', style: TextStyle(fontSize: 14)),
              SizedBox(width: 4),
              Text(
                'Trending',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Text(
            '$likes dogs loved this',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ACHIEVEMENT SECTION - ONLY 3 IN-PROGRESS + VIEW ALL
  // ============================================================================
  Widget _buildAchievementSection(GamificationData gamification) {
    // Build list of in-progress achievements (not yet completed)
    final inProgressAchievements = [
      _AchievementData(
        icon: '🔥',
        title: 'Streak Master',
        desc: '${gamification.streak}/30 days',
        unlocked: gamification.streak >= 30,
        progress: (gamification.streak / 30).clamp(0.0, 1.0),
      ),
      _AchievementData(
        icon: '🧑‍🍳',
        title: 'Master Chef',
        desc: '5/20 recipes',
        unlocked: false,
        progress: 0.25,
      ),
      _AchievementData(
        icon: '🏆',
        title: 'Perfect Week',
        desc: 'All tasks done',
        unlocked: gamification.achievements.contains('perfect_week'),
        progress: gamification.achievements.contains('perfect_week')
            ? 1.0
            : 0.7,
      ),
    ];

    // Filter to show only in-progress (not completed)
    final toShow = inProgressAchievements
        .where((a) => !a.unlocked)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🏆 Achievements',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () => _showAllAchievements(gamification),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Show only 3 achievements in a compact list
        ...toShow.map((a) => _buildCompactAchievementCard(a)),
        const SizedBox(height: 16),
        _buildXPBar(gamification),
        const SizedBox(height: 12),
        _buildDailyChallenge(),
        const SizedBox(height: 12),
        _buildLeaderboardRank(),
      ],
    );
  }

  void _showAllAchievements(GamificationData gamification) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '🏆 All Achievements',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildAchievementListItem(
                    '🔥',
                    'Streak Master',
                    '${gamification.streak}/30 days',
                    gamification.streak >= 30,
                  ),
                  _buildAchievementListItem(
                    '🏆',
                    'Perfect Week',
                    'Complete all tasks for 7 days',
                    gamification.achievements.contains('perfect_week'),
                  ),
                  _buildAchievementListItem(
                    '🏃',
                    'Fitness Guru',
                    '10k steps for 3 days',
                    gamification.achievements.contains('fitness_guru'),
                  ),
                  _buildAchievementListItem(
                    '🧑‍🍳',
                    'Master Chef',
                    'Try 20 homemade recipes',
                    false,
                  ),
                  _buildAchievementListItem(
                    '📸',
                    'Photo Star',
                    'Share 50 photos',
                    false,
                  ),
                  _buildAchievementListItem(
                    '💧',
                    'Hydration Hero',
                    'Meet water goal 14 days',
                    false,
                  ),
                  _buildAchievementListItem(
                    '🎯',
                    'Task Champion',
                    'Complete 100 tasks',
                    false,
                  ),
                  _buildAchievementListItem(
                    '🌟',
                    'Level 10',
                    'Reach level 10',
                    gamification.level >= 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementListItem(
    String icon,
    String title,
    String desc,
    bool unlocked,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked
            ? HomeColors.success.withOpacity(0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? HomeColors.success : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Text(
            icon,
            style: TextStyle(
              fontSize: 28,
              color: unlocked ? null : Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: unlocked ? HomeColors.textPrimary : Colors.grey[600],
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: unlocked ? HomeColors.success : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            unlocked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: unlocked ? HomeColors.success : Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAchievementCard(_AchievementData achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(achievement.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: achievement.progress,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(
                      achievement.unlocked
                          ? HomeColors.success
                          : HomeColors.warning,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            achievement.desc,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXPBar(GamificationData gamification) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${gamification.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${gamification.currentXP} / ${gamification.xpForNextLevel} XP',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: gamification.currentXP / gamification.xpForNextLevel,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(HomeColors.success),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChallenge() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HomeColors.secondary.withOpacity(0.3),
            HomeColors.primary.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Challenge',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Complete all tasks for +50 XP',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '0/1',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRank() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            "You're doing great! Keep it up!",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // QUICK ACTIONS - FLOATING + BUTTON ONLY
  // ============================================================================
  Widget _buildQuickActionsBar() {
    return FloatingActionButton(
      onPressed: _showQuickAddMenu,
      backgroundColor: HomeColors.primary,
      elevation: 8,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [HomeColors.primary, Color(0xFF818CF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: HomeColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  void _showQuickAddMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Add',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildQuickAddOption(
              Icons.add_task,
              'Add Task',
              HomeColors.primary,
              onTap: () => _currentDogId != null
                  ? _showAddTaskModal(_currentDogId!)
                  : null,
            ),
            _buildQuickAddOption(
              Icons.restaurant,
              'Log Meal',
              HomeColors.warning,
              onTap: _showLogMealModal,
            ),
            _buildQuickAddOption(
              Icons.directions_walk,
              'Start Walk',
              HomeColors.secondary,
              onTap: _showStartWalkModal,
            ),
            _buildQuickAddOption(
              Icons.photo_camera,
              'Add Photo',
              HomeColors.success,
              onTap: _showTakePhotoModal,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddOption(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) onTap();
      },
    );
  }

  // ============================================================================
  // ACTION MODALS
  // ============================================================================

  void _showLogMealModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('🍖', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'Log Meal',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildMealOption('Breakfast', '🌅'),
            _buildMealOption('Lunch', '☀️'),
            _buildMealOption('Dinner', '🌙'),
            _buildMealOption('Snack', '🦴'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMealOption(String meal, String emoji) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 24)),
      title: Text(meal, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.add_circle_outline, color: HomeColors.primary),
      onTap: () async {
        Navigator.pop(context);
        if (_currentDogId != null) {
          await ref.read(firestoreServiceProvider).addXP(_currentDogId!, 15);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$emoji $meal logged! +15 XP'),
                backgroundColor: HomeColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      },
    );
  }

  void _showStartWalkModal() {
    int selectedMinutes = 30;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('🚶', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Start Walk',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Track your walk with your furry friend!',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HomeColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: HomeColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$selectedMinutes min',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: HomeColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: selectedMinutes.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      activeColor: HomeColors.secondary,
                      inactiveColor: HomeColors.secondary.withOpacity(0.3),
                      label: '$selectedMinutes min',
                      onChanged: (value) {
                        setModalState(() => selectedMinutes = value.round());
                        HapticFeedback.selectionClick();
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '5 min',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '2 hrs',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _startWalk(selectedMinutes);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Start $selectedMinutes min Walk'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _startWalk(int minutes) async {
    HapticFeedback.heavyImpact();

    // Use the walk tracking service for verified walks
    final walkService = WalkTrackingService();
    final started = await walkService.startWalk();

    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '📍 Please enable location services to track walks',
            ),
            backgroundColor: HomeColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => Geolocator.openLocationSettings(),
            ),
          ),
        );
      }
      return;
    }

    // Show walk tracking overlay
    if (mounted) {
      _showWalkTrackingOverlay(walkService, minutes);
    }
  }

  void _showWalkTrackingOverlay(
    WalkTrackingService walkService,
    int targetMinutes,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (context) => _WalkTrackingSheet(
        walkService: walkService,
        targetMinutes: targetMinutes,
        dogId: _currentDogId,
        onComplete: (result) async {
          Navigator.pop(context);
          if (result != null && _currentDogId != null) {
            // Award verified XP based on actual walk
            await ref
                .read(firestoreServiceProvider)
                .addXP(_currentDogId!, result.earnedXP);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🎉 Walk complete! ${result.formattedDistance} in ${result.formattedDuration} (+${result.earnedXP} XP)',
                  ),

                  backgroundColor: HomeColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showTakePhotoModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('📸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'Capture Moment',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HomeColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: HomeColors.primary),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Use camera'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HomeColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: HomeColors.success,
                ),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick existing photo'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // Award XP for taking a photo
        if (_currentDogId != null) {
          await ref
              .read(firestoreServiceProvider)
              .addXP(_currentDogId!, 20, source: 'photo');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? '📸 Photo captured! +20 XP'
                  : '🖼️ Photo selected! +20 XP',
            ),
            backgroundColor: HomeColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: HomeColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ============================================================================
// HEALTH RING PAINTER
// ============================================================================
class HealthRingPainter extends CustomPainter {
  final double progress;
  final int healthScore;

  HealthRingPainter({required this.progress, required this.healthScore});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    if (healthScore >= 90) {
      progressPaint.shader = const LinearGradient(
        colors: [HomeColors.healthGreenStart, HomeColors.healthGreenEnd],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else if (healthScore >= 70) {
      progressPaint.shader = const LinearGradient(
        colors: [HomeColors.healthYellowStart, HomeColors.healthYellowEnd],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else if (healthScore >= 50) {
      progressPaint.shader = const LinearGradient(
        colors: [HomeColors.healthOrangeStart, HomeColors.healthOrangeEnd],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      progressPaint.shader = const LinearGradient(
        colors: [HomeColors.healthRedStart, HomeColors.healthRedEnd],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant HealthRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.healthScore != healthScore;
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================
class QuickStat {
  final String icon;
  final String label;
  final String value;
  final Color color;

  QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _AchievementData {
  final String icon;
  final String title;
  final String desc;
  final bool unlocked;
  final double progress;

  _AchievementData({
    required this.icon,
    required this.title,
    required this.desc,
    required this.unlocked,
    required this.progress,
  });
}

// ============================================================================
// WALK TRACKING SHEET
// ============================================================================
class _WalkTrackingSheet extends StatefulWidget {
  final WalkTrackingService walkService;
  final int targetMinutes;
  final String? dogId;
  final Function(WalkResult?) onComplete;

  const _WalkTrackingSheet({
    required this.walkService,
    required this.targetMinutes,
    required this.dogId,
    required this.onComplete,
  });

  @override
  State<_WalkTrackingSheet> createState() => _WalkTrackingSheetState();
}

class _WalkTrackingSheetState extends State<_WalkTrackingSheet> {
  late StreamSubscription<Duration> _timerSub;
  late StreamSubscription<double> _distanceSub;
  Duration _elapsed = Duration.zero;
  double _distance = 0;

  @override
  void initState() {
    super.initState();
    _timerSub = widget.walkService.elapsedTimeStream.listen((d) {
      if (mounted) setState(() => _elapsed = d);
    });
    _distanceSub = widget.walkService.distanceStream.listen((d) {
      if (mounted) setState(() => _distance = d);
    });
  }

  @override
  void dispose() {
    _timerSub.cancel();
    _distanceSub.cancel();
    super.dispose();
  }

  void _pauseResume() {
    if (widget.walkService.isPaused) {
      widget.walkService.resumeWalk();
    } else {
      widget.walkService.pauseWalk();
    }
    setState(() {});
  }

  Future<void> _completeWalk() async {
    final result = await widget.walkService.completeWalk();
    widget.onComplete(result);
  }

  void _cancelWalk() {
    widget.walkService.cancelWalk();
    widget.onComplete(null);
  }

  String get _formattedTime {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes.remainder(60);
    final seconds = _elapsed.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _formattedDistance {
    if (_distance < 1000) {
      return '${_distance.toInt()} m';
    }
    return '${(_distance / 1000).toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = widget.walkService.isPaused;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isPaused ? '⏸️ Walk Paused' : '🚶 Walk in Progress',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Target: ${widget.targetMinutes} minutes',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          // Timer display
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HomeColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Column(
              children: [
                Text(
                  _formattedTime,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: HomeColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formattedDistance,
                  style: const TextStyle(
                    fontSize: 18,
                    color: HomeColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Control buttons
          Row(
            children: [
              // Pause/Resume button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pauseResume,
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(isPaused ? 'Resume' : 'Pause'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Complete button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _completeWalk,
                  icon: const Icon(Icons.check),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _cancelWalk,
            child: const Text(
              'Cancel Walk',
              style: TextStyle(color: HomeColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
