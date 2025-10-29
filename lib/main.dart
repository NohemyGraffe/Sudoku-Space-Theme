import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() => runApp(const SudokuApp());

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      // Hide platform scrollbars globally (desktop/web)
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      theme: neonTheme,
      home: const HomeScreen(),
    );
  }
}


//flutter run -d RFCT329XGDZ