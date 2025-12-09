// PetPal App Colors
// Based on UI designs from PetPalUI folder

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF4043F2);
  static const Color primaryLight = Color(0xFF6363F2);
  static const Color primaryDark = Color(0xFF4A4DB5);

  // Background Colors
  static const Color backgroundLight = Color(0xFFF6F6F8);
  static const Color backgroundDark = Color(0xFF101022);

  // Health Score Colors
  static const Color healthGreen = Color(0xFF4ADE80);
  static const Color healthYellow = Color(0xFFFACC15);
  static const Color healthRed = Color(0xFFF87171);

  // Task Colors
  static const Color mealColor = Color(0xFFFB923C);
  static const Color walkColor = Color(0xFF60A5FA);
  static const Color medsColor = Color(0xFFF87171);
  static const Color appointmentColor = Color(0xFFC084FC);
  static const Color playColor = Color(0xFFFACC15);

  // Neutral Colors
  static const Color white = Colors.white;
  static const Color black = Color(0xFF111118);
  static const Color grey = Color(0xFF616289);
  static const Color greyLight = Color(0xFFE5E7EB);

  // Glassmorphism
  static Color glassWhite = Colors.white.withValues(alpha: 0.2);
  static Color glassBorder = Colors.white.withValues(alpha: 0.3);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFA8B2E4), Color(0xFF7579F3), Color(0xFF4043F2)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4043F2), Color(0xFF4144D9)],
  );

  static const LinearGradient healthGoodGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
  );

  static const LinearGradient healthModerateGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
  );

  static const LinearGradient healthPoorGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFF87171)],
  );
}
