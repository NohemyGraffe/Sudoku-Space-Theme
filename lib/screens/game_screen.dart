import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/sudoku_board.dart';
import '../models/difficulty.dart';
import '../widgets/num_key.dart';

class GameScreen extends StatefulWidget {
  final Difficulty startDifficulty;
  const GameScreen({super.key, this.startDifficulty = Difficulty.easy});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late SudokuModel model;
  int? selectedRow;
  int? selectedCol;

  @override
  void initState() {
    super.initState();
    model = SudokuModel()..loadRandom(widget.startDifficulty);
  }

  void _newGame() {
    model.loadRandom(model.currentDifficulty);
    selectedRow = null;
    selectedCol = null;
    setState(() {});
  }

  void _onCellTap(int r, int c) {
    if (model.isFixed(r, c)) return;
    setState(() {
      selectedRow = r;
      selectedCol = c;
    });
  }

  void _onInput(int? value) {
    if (selectedRow == null || selectedCol == null) return;
    model.setCell(selectedRow!, selectedCol!, value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge!.copyWith(color: AppColors.text, fontSize: 24);

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
          child: Text(
            '${difficultyLabel(model.currentDifficulty)} • BoringSudoku',
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New Game',
            onPressed: _newGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'Neon Mode • Have fun ✨',
              style: titleStyle.copyWith(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 12),

            // Board
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPink.withOpacity(0.12),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.neonViolet.withOpacity(0.35),
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: _buildGrid(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Number pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in List<int>.generate(9, (i) => i + 1))
                    NumKey(label: '$n', onTap: () => _onInput(n)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Erase'),
                      onPressed: () => _onInput(null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Check'),
                      onPressed: () {
                        final ok = !model.hasAnyConflicts() && !model.hasZeros;
                        final snack = SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: ok
                              ? AppColors.neonLime
                              : Colors.redAccent,
                          content: Text(
                            ok
                                ? 'Looks great! ✅'
                                : 'There are conflicts or empty cells.',
                            style: TextStyle(
                              color: ok ? Colors.black : Colors.white,
                            ),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(snack);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),

      // Win banner
      bottomNavigationBar: model.isComplete
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonLime.withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
                border: const Border(
                  top: BorderSide(color: AppColors.neonLime, width: 2),
                ),
              ),
              child: const Text(
                '🎉 Completed! You’re glowing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.neonLime,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 81,
      itemBuilder: (context, index) {
        final r = index ~/ 9;
        final c = index % 9;
        final selected = (selectedRow == r && selectedCol == c);
        final fixed = model.isFixed(r, c);
        final conflict = model.isConflict(r, c);

        final thickTop = r % 3 == 0;
        final thickLeft = c % 3 == 0;

        Color cellBg = Colors.transparent;
        if (selected) cellBg = AppColors.neonCyan.withOpacity(0.12);

        return Container(
          decoration: BoxDecoration(
            color: cellBg,
            border: Border(
              top: BorderSide(
                color: thickTop
                    ? AppColors.neonPink.withOpacity(0.8)
                    : AppColors.neonViolet.withOpacity(0.35),
                width: thickTop ? 2 : 1,
              ),
              left: BorderSide(
                color: thickLeft
                    ? AppColors.neonPink.withOpacity(0.8)
                    : AppColors.neonViolet.withOpacity(0.35),
                width: thickLeft ? 2 : 1,
              ),
              right: const BorderSide(color: Colors.transparent, width: 0),
              bottom: const BorderSide(color: Colors.transparent, width: 0),
            ),
          ),
          child: InkWell(
            onTap: () => _onCellTap(r, c),
            borderRadius: BorderRadius.circular(6),
            child: Center(
              child: Text(
                model.board[r][c] == 0 ? '' : model.board[r][c].toString(),
                style: TextStyle(
                  fontWeight: fixed ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 18,
                  letterSpacing: 0.5,
                  color: conflict
                      ? Colors.redAccent
                      : (fixed ? Colors.white : AppColors.neonLime),
                  shadows: [
                    Shadow(
                      color:
                          (conflict
                                  ? Colors.redAccent
                                  : (fixed
                                        ? AppColors.neonPink
                                        : AppColors.neonLime))
                              .withOpacity(0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
