import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/difficulty.dart';
import 'game_screen.dart';
import '../theme/app_theme.dart';
import '../services/game_persistence.dart';

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

    final size = MediaQuery.sizeOf(context);
    final isShort = size.height < 720; // phones with less vertical space
    final isVeryShort = size.height < 640; // even tighter (small/landscape)

    // Make items relatively taller on short screens by lowering the aspect ratio.
    final gridAspect = isVeryShort ? 0.75 : (isShort ? 0.85 : 1.0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              AppColors.neonPink,
              AppColors.neonCyan,
              AppColors.neonLime,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
          child: const Text('', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.4, -0.9),
            radius: 1.2,
            colors: [Color(0x3315FFE0), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              const _Header(),
              const SizedBox(height: 6),
              const _TotalPoints(),
              const SizedBox(height: 8),
              // Continue strip removed per request
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  'Pick a difficulty level and vibe',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, letterSpacing: 0.2),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: gridAspect,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final d = items[i];
                      return FutureBuilder<bool>(
                        future: GamePersistence.hasSaved(d),
                        builder: (context, snap) {
                          final hasSaved = snap.data == true;
                          // Always show only the difficulty name, even if a save exists.
                          final label = difficultyLabel(d);
                          return _DifficultyCard(
                            label: label,
                            subtitle: _subtitleFor(d, hasSaved),
                            icon: _iconFor(d),
                            accent: _colorFor(d),
                            compact: isShort, // <— shrink content if needed
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final nav = Navigator.of(context);
                              final exists = await GamePersistence.hasSaved(d);
                              if (exists) {
                                final choice = await showDialog<int>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppColors.card,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    title: const Text('Continue game?'),
                                    content: Text(
                                      'A saved ${difficultyLabel(d)} game was found. What would you like to do?',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, 0),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, 2),
                                        child: const Text('New Game'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, 1),
                                        child: const Text('Resume'),
                                      ),
                                    ],
                                  ),
                                );
                                if (choice == 1) {
                                  await nav.push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GameScreen(startDifficulty: d),
                                    ),
                                  );
                                  if (!context.mounted) return;
                                  (context as Element).markNeedsBuild();
                                  return;
                                } else if (choice == 2) {
                                  await GamePersistence.clear(d);
                                  await nav.push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GameScreen(startDifficulty: d),
                                    ),
                                  );
                                  if (!context.mounted) return;
                                  (context as Element).markNeedsBuild();
                                  return;
                                } else {
                                  return; // canceled
                                }
                              }

                              await nav.push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GameScreen(startDifficulty: d),
                                ),
                              );
                              if (!context.mounted) return;
                              (context as Element).markNeedsBuild();
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalPoints extends StatelessWidget {
  const _TotalPoints();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: GamePersistence.totalPointsNotifier,
      builder: (context, total, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neonCyan.withOpacity(0.25)),
              color: AppColors.card.withOpacity(0.30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars_rounded, color: AppColors.neonLime),
                const SizedBox(width: 8),
                Text(
                  'Total points: $total',
                  style: const TextStyle(
                    color: AppColors.neonCyan,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _NeonTitle(text: 'Sudoku - Neon Edition'),
        SizedBox(height: 6),
      ],
    );
  }
}

// Saved strip and Continue chips removed per request.

class _NeonTitle extends StatelessWidget {
  final String text;
  const _NeonTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [AppColors.neonPink, AppColors.neonViolet, AppColors.neonLime],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool compact;
  final VoidCallback onTap;

  const _DifficultyCard({
    Key? key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.compact = false,
  }) : super(key: key);

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.compact ? 36.0 : 42.0;
    final titleSize = widget.compact ? 18.0 : 20.0;
    final subSize = widget.compact ? 11.0 : 12.0;
    final pad = widget.compact ? 12.0 : 16.0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      scale: _pressed ? 0.98 : 1.0,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.accent.withOpacity(0.45),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withOpacity(0.18),
                blurRadius: 18,
                spreadRadius: 1.2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.card.withOpacity(0.58),
                        AppColors.card.withOpacity(0.36),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: const SizedBox.expand(),
                ),
                Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch, // Add this line
                    mainAxisSize: MainAxisSize.min, // <— don’t stretch
                    children: [
                      Icon(widget.icon, size: iconSize, color: widget.accent),
                      const SizedBox(height: 10),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.neonCyan,
                          fontWeight: FontWeight.w900,
                          fontSize: titleSize,
                          letterSpacing: 0.4,
                          shadows: const [Shadow(blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Opacity(
                        opacity: 0.85,
                        child: Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: subSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.8,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.copyright_rounded, size: 14, color: Colors.white60),
            SizedBox(width: 6),
            Text(
              'Sudoku • v1.0',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- helpers ----------
IconData _iconFor(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return Icons.emoji_emotions_rounded;
    case Difficulty.medium:
      return Icons.sentiment_satisfied_alt_rounded;
    case Difficulty.hard:
      return Icons.local_fire_department_rounded;
    case Difficulty.expert:
      return Icons.whatshot_rounded; // safe fallback
  }
}

Color _colorFor(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return AppColors.neonLime;
    case Difficulty.medium:
      return AppColors.neonCyan;
    case Difficulty.hard:
      return AppColors.neonPink;
    case Difficulty.expert:
      return AppColors.neonViolet;
  }
}

String _subtitleFor(Difficulty d, bool hasSaved) {
  switch (d) {
    case Difficulty.easy:
      return 'Warm up';
    case Difficulty.medium:
      return 'Flow state';
    case Difficulty.hard:
      return 'Challenge';
    case Difficulty.expert:
      return 'Brutal';
  }
}
