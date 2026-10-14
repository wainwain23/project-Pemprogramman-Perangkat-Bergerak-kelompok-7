import 'package:flutter/material.dart';

const Color kNavy = Color(0xFF12263A);
const Color kRed = Color(0xFFE4572E);
const Color kTeal = Color(0xFF2A9D8F);
const Color kYellow = Color(0xFFF4B428);
const Color kBlue = Color(0xFF3468B4);
const Color kPurple = Color(0xFF8C5AAA);
const Color kLight = Color(0xFFF4F6F8);
const Color kGray = Color(0xFF6E7882);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kRed, primary: kRed),
    scaffoldBackgroundColor: kLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
