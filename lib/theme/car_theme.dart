import 'package:flutter/material.dart';

class CarColors {
  // Ultra-dark palette
  static const Color background = Color(0xFF0A0A0C);
  static const Color cardContainer = Color(0xFF141418);
  static const Color cardBorder = Color(0xFF22222A);
  
  // Neon accents
  static const Color primaryAccent = Color(0xFF00FF88); // Neon Mint/Green
  static const Color secondaryCyan = Color(0xFF00E5FF); // Electric Cyan
  static const Color amberWarning = Color(0xFFFFB300); // Motion lock amber
  static const Color dangerRed = Color(0xFFFF3355); // Exit / emergency red

  // Text colors
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8E8E9F);
  static const Color textMuted = Color(0xFF555566);

  // Official NCS Circle Hues
  static const Color genreTrap = Color(0xFF00FFA3);       // Mint
  static const Color genreHouse = Color(0xFFFFE600);      // Yellow
  static const Color genreDubstep = Color(0xFF00E5FF);    // Cyan/Blue
  static const Color genreChill = Color(0xFFFF9E79);      // Peach
  static const Color genreDnB = Color(0xFFFF2A55);        // Red/Crimson
  static const Color genreSurprise = Color(0xFFFFFFFF);   // White ring
  static const Color genreMelodic = Color(0xFF9D4EDD);    // Purple/Melodic
  static const Color genreDefault = Color(0xFF00FF88);

  static Color getGenreColor(String genre) {
    final lower = genre.toLowerCase();
    if (lower.contains('trap')) return genreTrap;
    if (lower.contains('house')) return genreHouse;
    if (lower.contains('dubstep')) return genreDubstep;
    if (lower.contains('chill')) return genreChill;
    if (lower.contains('dnb') || lower.contains('drum')) return genreDnB;
    if (lower.contains('melodic')) return genreMelodic;
    return genreDefault;
  }
}

