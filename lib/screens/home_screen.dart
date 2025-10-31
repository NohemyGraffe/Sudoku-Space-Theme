import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/difficulty.dart';
import 'game_screen.dart';
import '../theme/app_theme.dart';
import '../services/game_persistence.dart';
import '../models/sudoku_board.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LoadedResume? _resume;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadResume();
  }

  Future<void> _loadResume() async {
    final r = await GamePersistence.loadResume();
    if (!mounted) return;
    setState(() {
      _resume = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isShort = size.height < 720; // phones with less vertical space
    return Scaffold(
      backgroundColor: AppColors.bg,
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
      body: Stack(
        children: [
          // Background: deep violet -> near black
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF130F1A), AppColors.bg],
                ),
              ),
            ),
          ),
          // Corner glows to match board neon
          Positioned(
            top: -80,
            left: -60,
            child: _CornerGlow(
              color: AppColors.neonPink.withOpacity(0.25),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            child: _CornerGlow(
              color: AppColors.neonCyan.withOpacity(0.22),
              size: 260,
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    const SizedBox(height: 8), // tighter top padding
                    const _Header(),
                    const SizedBox(height: 30),
                    const _AllTimeScoreBanner(),
                    const SizedBox(height: 45),

                    // ============== Two primary actions ==============
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 270,
                            child: _NeonContinueButton(
                              enabled: !_loading && _resume != null,
                              subtitle: _resume == null
                                  ? 'No saved game'
                                  : '${difficultyLabel(_resume!.difficulty).toUpperCase()} • ${formatElapsed(_resume!.elapsedSeconds)}',
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final snap = await GamePersistence.loadResume();
                                if (snap == null) return; // nothing to resume
                                final nav = Navigator.of(context);
                                nav
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) => GameScreen(
                                          initialModel: snap.model,
                                          initialElapsed: snap.elapsedSeconds,
                                          initialScore: snap.score,
                                          initialMistakes: snap.mistakes,
                                        ),
                                      ),
                                    )
                                    .then((_) {
                                      if (mounted) _loadResume();
                                    });
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 270,
                            child: _NeonNewGameButton(
                              onTap: () =>
                                  _openNewGamePicker(context, compact: isShort),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),
                    const SizedBox(height: 0),
                    const _Footer(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNewGamePicker(
    BuildContext context, {
    required bool compact,
  }) async {
    final choice = await showModalBottomSheet<Difficulty>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose Difficulty',
                style: TextStyle(
                  color: AppColors.neonCyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              for (final d in Difficulty.values)
                ListTile(
                  leading: Icon(_iconFor(d), color: _colorFor(d)),
                  title: Text(
                    difficultyLabel(d),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(ctx, d),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
    if (choice == null) return;

    // Create a fresh model for the chosen difficulty
    final model = SudokuModel()..loadRandom(choice);
    // Immediately persist to the global resume slot
    await GamePersistence.saveResume(
      model,
      elapsedSeconds: 0,
      score: 0,
      mistakes: 0,
      lastSavedAt: DateTime.now(),
    );

    if (!mounted) return;
    final nav = Navigator.of(context);
    nav
        .push(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              initialModel: model,
              initialElapsed: 0,
              initialScore: 0,
              initialMistakes: 0,
            ),
          ),
        )
        .then((_) {
          if (mounted) _loadResume();
        });
  }
}

class _AllTimeScoreBanner extends StatefulWidget {
  const _AllTimeScoreBanner();

  @override
  State<_AllTimeScoreBanner> createState() => _AllTimeScoreBannerState();
}

class _AllTimeScoreBannerState extends State<_AllTimeScoreBanner> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: GamePersistence.totalPointsNotifier,
      builder: (context, total, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.card.withOpacity(0.46),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.neonLime.withOpacity(0.45),
                width: 1.6,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Big neon trophy
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.card.withOpacity(0.35),
                    border: Border.all(
                      color: AppColors.neonLime.withOpacity(0.55),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.neonLime,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'All-Time Score',
                  style: TextStyle(
                    color: AppColors.neonLime,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                // Neon capsule with total (bigger)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.neonLime,
                  ),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(total),
                    tween: Tween(begin: 0.9, end: 1.0),
                    duration: const Duration(milliseconds: 280),
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.2,
                      ),
                    ),
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
    return const _NeonTitle(text: 'Sudoku - Neon Edition');
  }
}

// Saved strip and Continue chips removed per request.

class _NeonTitle extends StatelessWidget {
  final String text;
  const _NeonTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          colors: [AppColors.neonPink, AppColors.neonCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.25,
            shadows: [
              Shadow(color: AppColors.neonPink, blurRadius: 12),
              Shadow(color: AppColors.neonCyan, blurRadius: 18),
            ],
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
        padding: const EdgeInsets.only(bottom: 0),
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

String timeAgoFromIso(String? iso) {
  if (iso == null) return 'Just now';
  DateTime? t;
  try {
    t = DateTime.parse(iso).toLocal();
  } catch (_) {
    return 'Just now';
  }
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inSeconds < 10) return 'Just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

String formatElapsed(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ===== UI pieces for buttons =====
class _NeonContinueButton extends StatefulWidget {
  final bool enabled;
  final String? subtitle;
  final VoidCallback onTap;
  const _NeonContinueButton({
    required this.enabled,
    required this.onTap,
    this.subtitle,
  });

  @override
  State<_NeonContinueButton> createState() => _NeonContinueButtonState();
}

class _NeonContinueButtonState extends State<_NeonContinueButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: _pressed ? 0.98 : 1.0,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.6,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            splashColor: Colors.white.withOpacity(0.18),
            onHighlightChanged: (h) => setState(() => _pressed = h),
            onTap: widget.enabled ? widget.onTap : null,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), AppColors.neonCyan],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonCyan.withOpacity(0.25),
                    blurRadius: 16,
                    spreadRadius: 1.2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.black),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Continue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonNewGameButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NeonNewGameButton({required this.onTap});

  @override
  State<_NeonNewGameButton> createState() => _NeonNewGameButtonState();
}

class _NeonNewGameButtonState extends State<_NeonNewGameButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: _pressed ? 0.98 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          splashColor: AppColors.neonPink.withOpacity(0.20),
          onHighlightChanged: (h) => setState(() => _pressed = h),
          onTap: widget.onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xE6FF1493), // deep hot pink @ ~90% alpha
                  AppColors.neonPink.withOpacity(0.78),
                  Color(0x99FF7FCB), // lighter pink @ ~60% alpha
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonPink.withOpacity(0.25),
                  blurRadius: 16,
                  spreadRadius: 1.2,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, color: Colors.black),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'New Game',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Glow blob for corners
class _CornerGlow extends StatelessWidget {
  final Color color;
  final double size;
  const _CornerGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
