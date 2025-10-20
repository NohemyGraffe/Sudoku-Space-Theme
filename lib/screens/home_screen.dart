import 'package:flutter/material.dart';
import '../models/difficulty.dart';
import 'game_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      Difficulty.easy,
      Difficulty.medium,
      Difficulty.hard,
      Difficulty.expert,
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              AppColors.neonPink,
              AppColors.neonCyan,
              AppColors.neonLime,
            ],
          ).createShader(rect),
          child: const Text('Sudoku - Neon Theme'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final d = items[i];
            return _DifficultyCard(
              label: difficultyLabel(d),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameScreen(startDifficulty: d),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DifficultyCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.neonViolet.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonPink.withOpacity(0.12),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.neonCyan,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: 0.6,
              shadows: [Shadow(blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}
