import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Warm Luxury Palette ───────────────────────────────────────────────────────
const Color kBackground = Color(0xFFF4F0EA); // warm cream parchment
const Color kCard       = Color(0xFFFDFBF8); // near-white warm card
const Color kSurface    = Color(0xFFEDE8E0); // warm taupe surface
const Color kInk        = Color(0xFF1C1A16); // rich warm dark (not pure black)
const Color kDimText    = Color(0xFF9A8F82); // warm mid-gray
const Color kGold       = Color(0xFFB08040); // burnished amber gold accent
const Color kGoldLight  = Color(0xFFF5E8C8); // pale gold for icon bgs
const Color kBorder     = Color(0xFFE4DDD4); // warm soft border

// Chip background palette — muted, sophisticated tints
const Color kChipWarm   = Color(0xFFF2EAE0); // warm neutral
const Color kChipGold   = Color(0xFFF5ECD6); // warm gold tint
const Color kChipSage   = Color(0xFFE4EDDF); // muted sage
const Color kChipSlate  = Color(0xFFDDE6EE); // soft slate blue
const Color kChipBlush  = Color(0xFFF0E4E4); // muted blush
const Color kChipIndigo = Color(0xFFE3E1EE); // soft indigo
const Color kChipMoss   = Color(0xFFE0EAE2); // deep sage

final ThemeData originalThemeData = ThemeData(
  useMaterial3: false,
  brightness: Brightness.light,
  scaffoldBackgroundColor: kBackground,
  cardColor: kCard,
  colorScheme: const ColorScheme.light(
    primary: kInk,
    onPrimary: kCard,
    secondary: kGold,
    onSecondary: kCard,
    surface: kSurface,
    onSurface: kInk,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kBackground,
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: kCard,
    selectedItemColor: kInk,
    unselectedItemColor: kDimText,
    elevation: 0,
  ),
  dividerColor: kBorder,
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: kInk, letterSpacing: -1.0, fontWeight: FontWeight.w800),
    headlineLarge: TextStyle(color: kInk, letterSpacing: -0.5, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(color: kInk, letterSpacing: -0.3),
    bodyLarge: TextStyle(color: kInk),
    bodyMedium: TextStyle(color: kInk),
    labelSmall: TextStyle(color: kDimText, letterSpacing: 0.8),
  ),
  iconTheme: const IconThemeData(color: kInk),
  inputDecorationTheme: InputDecorationTheme(
    hintStyle: TextStyle(color: kDimText),
    fillColor: kSurface,
  ),
);
