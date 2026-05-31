import 'package:flutter/material.dart';

class ThemePalette {
  const ThemePalette({
    required this.appBar,
    required this.timeBg,
    required this.timeBorder,
    required this.timeText,
    required this.dateBg,
    required this.dateBorder,
    required this.cardBg,
    required this.cardBorder,
    required this.tileNameBg,
    required this.tileNameBorder,
    required this.tileTimeBg,
    required this.tileTimeBorder,
    required this.countdownBg,
    required this.countdownBorder,
    required this.dialogBg,
    required this.dialogHeaderBg,
  });

  final Color appBar;
  final Color timeBg;
  final Color timeBorder;
  final Color timeText;
  final Color dateBg;
  final Color dateBorder;
  final Color cardBg;
  final Color cardBorder;
  final Color tileNameBg;
  final Color tileNameBorder;
  final Color tileTimeBg;
  final Color tileTimeBorder;
  final Color countdownBg;
  final Color countdownBorder;
  final Color dialogBg;
  final Color dialogHeaderBg;
}

class AppTheme {
  const AppTheme({required this.name, required this.data, required this.palette});
  final String name;
  final ThemeData data;
  final ThemePalette palette;
}

class AppThemes {
  static final List<AppTheme> themes = [
    AppTheme(
      name: 'الافتراضي',
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      palette: const ThemePalette(
        appBar: Color(0xFF009688),
        timeBg: Color(0xFFFFCDD2),
        timeBorder: Color(0xFFFBC02D),
        timeText: Color(0xFFD32F2F),
        dateBg: Color(0xFFFFF9C4),
        dateBorder: Color(0xFFD32F2F),
        cardBg: Color(0xFFCCFFCC),
        cardBorder: Color(0xFFFF9800),
        tileNameBg: Color(0xFFFFFDE7),
        tileNameBorder: Color(0xFFFF9800),
        tileTimeBg: Color(0xFFFFFDE7),
        tileTimeBorder: Color(0xFFFF9800),
        countdownBg: Color(0xFFFFF9C4),
        countdownBorder: Color(0xFFFF9800),
        dialogBg: Color(0xFFFFFDE7),
        dialogHeaderBg: Color(0xFFFFF9C4),
      ),
    ),
    AppTheme(
      name: 'بحري',
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      palette: const ThemePalette(
        appBar: Color(0xFF1565C0),
        timeBg: Color(0xFFBBDEFB),
        timeBorder: Color(0xFF0D47A1),
        timeText: Color(0xFF0D47A1),
        dateBg: Color(0xFFE3F2FD),
        dateBorder: Color(0xFF1E88E5),
        cardBg: Color(0xFFB3E5FC),
        cardBorder: Color(0xFF1E88E5),
        tileNameBg: Color(0xFFE3F2FD),
        tileNameBorder: Color(0xFF1E88E5),
        tileTimeBg: Color(0xFFE3F2FD),
        tileTimeBorder: Color(0xFF1E88E5),
        countdownBg: Color(0xFFE3F2FD),
        countdownBorder: Color(0xFF1E88E5),
        dialogBg: Color(0xFFE3F2FD),
        dialogHeaderBg: Color(0xFFBBDEFB),
      ),
    ),
    AppTheme(
      name: 'ليلي',
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      palette: const ThemePalette(
        appBar: Color(0xFF303F9F),
        timeBg: Color(0xFFC5CAE9),
        timeBorder: Color(0xFF1A237E),
        timeText: Color(0xFF1A237E),
        dateBg: Color(0xFFE8EAF6),
        dateBorder: Color(0xFF3F51B5),
        cardBg: Color(0xFFD1C4E9),
        cardBorder: Color(0xFF5E35B1),
        tileNameBg: Color(0xFFEDE7F6),
        tileNameBorder: Color(0xFF5E35B1),
        tileTimeBg: Color(0xFFEDE7F6),
        tileTimeBorder: Color(0xFF5E35B1),
        countdownBg: Color(0xFFEDE7F6),
        countdownBorder: Color(0xFF5E35B1),
        dialogBg: Color(0xFFEDE7F6),
        dialogHeaderBg: Color(0xFFC5CAE9),
      ),
    ),
    AppTheme(
      name: 'رملي',
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      palette: const ThemePalette(
        appBar: Color(0xFF6D4C41),
        timeBg: Color(0xFFFFE0B2),
        timeBorder: Color(0xFF8D6E63),
        timeText: Color(0xFF5D4037),
        dateBg: Color(0xFFFFF3E0),
        dateBorder: Color(0xFF8D6E63),
        cardBg: Color(0xFFFFE0B2),
        cardBorder: Color(0xFF8D6E63),
        tileNameBg: Color(0xFFFFF3E0),
        tileNameBorder: Color(0xFF8D6E63),
        tileTimeBg: Color(0xFFFFF3E0),
        tileTimeBorder: Color(0xFF8D6E63),
        countdownBg: Color(0xFFFFF3E0),
        countdownBorder: Color(0xFF8D6E63),
        dialogBg: Color(0xFFFFF3E0),
        dialogHeaderBg: Color(0xFFFFE0B2),
      ),
    ),
  ];
}
