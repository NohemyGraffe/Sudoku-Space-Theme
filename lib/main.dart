import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/game_screen.dart';

void main() => runApp(const BoringSudokuApp());

class BoringSudokuApp extends StatelessWidget {
  const BoringSudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku - Space Theme',
      debugShowCheckedModeBanner: false,
      theme: neonTheme,
      home: const GameScreen(),
    );
  }
}
