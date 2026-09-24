import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Kloudy pairs a calm, welcoming canvas with precise, luminous accents.
const Color kBackground = Color(0xFFF4F5FA);
const Color kCard = Color(0xFFFFFFFF);
const Color kSurface = Color(0xFFEAEDF5);
const Color kInk = Color(0xFF17192D);
const Color kDimText = Color(0xFF737891);
const Color kGold = Color(0xFFE6AD69);
const Color kGoldLight = Color(0xFFFFF0DA);
const Color kBorder = Color(0xFFE1E4EF);

const Color kChipWarm = Color(0xFFF8EEE7);
const Color kChipGold = Color(0xFFFFF0DA);
const Color kChipSage = Color(0xFFE3F3EE);
const Color kChipSlate = Color(0xFFE5EAF8);
const Color kChipBlush = Color(0xFFF8E8EC);
const Color kChipIndigo = Color(0xFFEAE8FF);
const Color kChipMoss = Color(0xFFE8F1E7);

const Color kKloudyBlue = Color(0xFF6873F5);
const Color kKloudyCyan = Color(0xFF58D5D0);
const Color kKloudyNavy = Color(0xFF171A35);

final ThemeData originalThemeData = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: kBackground,
  cardColor: kCard,
  colorScheme: const ColorScheme.light(
    primary: kKloudyBlue,
    onPrimary: Colors.white,
    secondary: kKloudyCyan,
    onSecondary: kInk,
    surface: kCard,
    onSurface: kInk,
    outline: kBorder,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kBackground,
    foregroundColor: kInk,
    elevation: 0,
    centerTitle: false,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  ),
  dividerColor: kBorder,
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: kInk, letterSpacing: -1.4, fontWeight: FontWeight.w800),
    headlineLarge: TextStyle(color: kInk, letterSpacing: -0.8, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(color: kInk, letterSpacing: -0.5, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(color: kInk, letterSpacing: -0.3, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(color: kInk, height: 1.5),
    bodyMedium: TextStyle(color: kInk, height: 1.45),
    bodySmall: TextStyle(color: kDimText, height: 1.4),
    labelSmall: TextStyle(color: kDimText, letterSpacing: 1.0, fontWeight: FontWeight.w700),
  ),
  iconTheme: const IconThemeData(color: kInk),
  inputDecorationTheme: InputDecorationTheme(
    hintStyle: const TextStyle(color: kDimText),
    filled: true,
    fillColor: kSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide.none,
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: kKloudyBlue, width: 1.5),
    ),
  ),
);
