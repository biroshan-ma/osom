import 'package:flutter/material.dart';

/// App color palette — semantic tokens used throughout the app.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFF5F7FA); // very light grey

  // Primary brand color (teal/cyan)
  static const Color primary = Color(0xFF27B0C8); // requested teal-ish

  // Text
  static const Color textPrimary = Color(0xFF0B1724); // dark navy
  static const Color textSecondary = Color(0xFF6E7A86);

  // Inputs
  static const Color inputFill = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFDFE7EE);

  // Misc
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFB00020);
  static const Color disabled = Color(0xFFB9C3D2);
}
