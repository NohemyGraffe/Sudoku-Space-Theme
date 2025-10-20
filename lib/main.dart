import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() => runApp(const BoringSudokuApp());

class BoringSudokuApp extends StatelessWidget {
  const BoringSudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BoringSudoku',
      debugShowCheckedModeBanner: false,
      theme: neonTheme,
      home: const HomeScreen(),
    );
  }
}
