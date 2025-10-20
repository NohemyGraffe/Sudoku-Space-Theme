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

  // NEW: notes mode switch
  bool notesMode = false;

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
    setState(() {
      selectedRow = r;
      selectedCol = c;
    });
  }

  void _onInput(int? valueOrNumber) {
    if (selectedRow == null || selectedCol == null) return;
    final r = selectedRow!, c = selectedCol!;

    if (notesMode) {
      debugPrint(
        'NOTES path: r=$r c=$c v=$valueOrNumber fixed=${model.isFixed(r, c)}',
      );
      if (valueOrNumber == null) return;
      if (model.isFixed(r, c)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an empty cell to add notes.')),
        );
        return;
      }
      model.toggleNote(r, c, valueOrNumber);
      debugPrint(
        'After toggle: notes=${model.notesAt(r, c)} board=${model.board[r][c]}',
      );
      setState(() {});
      return;
    }

    model.setCell(r, c, valueOrNumber);
    setState(() {});
  }

  void _erase() {
    if (selectedRow == null || selectedCol == null) return;
    final r = selectedRow!, c = selectedCol!;
    if (notesMode) {
      model.clearNotes(r, c);
    } else {
      model.setCell(r, c, null);
    }
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
          child: Text('${difficultyLabel(model.currentDifficulty)} • Sudoku'),
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
            const SizedBox(height: 12),

            // NEW: Notes toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(notesMode ? Icons.edit_note : Icons.notes),
                      label: Text(notesMode ? 'Notes: ON' : 'Notes: OFF'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: notesMode
                              ? AppColors.neonCyan
                              : AppColors.neonViolet.withOpacity(0.5),
                          width: 1.6,
                        ),
                        foregroundColor: notesMode
                            ? AppColors.neonCyan
                            : AppColors.muted,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => setState(() => notesMode = !notesMode),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

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
                      label: Text(notesMode ? 'Clear Notes' : 'Erase'),
                      onPressed: _erase,
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
        final value = model.board[r][c];
        final isEmpty = (value == 0);
        final hasNotes = model.notesAt(r, c).isNotEmpty; // don't tie to isEmpty

        // Block-edge logic
        final thickTop = r % 3 == 0;
        final thickLeft = c % 3 == 0;

        // Close the outer frame on the last row/col
        final isLastRow = r == 8;
        final isLastCol = c == 8;
        final thickBottom = isLastRow; // outer frame should be thick
        final thickRight = isLastCol; // outer frame should be thick

        Color frameColor(bool thick) => thick
            ? AppColors.neonPink.withOpacity(0.8)
            : AppColors.neonViolet.withOpacity(0.35);

        final top = BorderSide(
          color: frameColor(thickTop),
          width: thickTop ? 2 : 1,
        );
        final left = BorderSide(
          color: frameColor(thickLeft),
          width: thickLeft ? 2 : 1,
        );
        final right = isLastCol
            ? BorderSide(
                color: frameColor(thickRight),
                width: thickRight ? 2 : 1,
              )
            : const BorderSide(color: Colors.transparent, width: 0);
        final bottom = isLastRow
            ? BorderSide(
                color: frameColor(thickBottom),
                width: thickBottom ? 2 : 1,
              )
            : const BorderSide(color: Colors.transparent, width: 0);

        Color cellBg = Colors.transparent;
        if (selected) cellBg = AppColors.neonCyan.withOpacity(0.12);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onCellTap(r, c),
          child: Container(
            decoration: BoxDecoration(
              color: cellBg,
              border: Border(
                top: top,
                left: left,
                right: right,
                bottom: bottom,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: hasNotes
                  ? _NotesGrid(notes: model.notesAt(r, c)) // no FittedBox here
                  : FittedBox(
                      fit: BoxFit.scaleDown, // only for big digits
                      child: Text(
                        isEmpty ? '' : value.toString(),
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
          ),
        );
      },
    );
  }
}

// Renders tiny 1..9 candidates in a 3x3 grid (properly spaced horizontally)
class _NotesGrid extends StatelessWidget {
  final Set<int> notes;
  const _NotesGrid({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0.2), // tighter to cell edges
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FlexColumnWidth(),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        children: List.generate(3, (r) {
          return TableRow(
            children: List.generate(3, (c) {
              final n = r * 3 + c + 1;
              final present = notes.contains(n);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 0.2),
                  child: Text(
                    present ? '$n' : '',
                    strutStyle: const StrutStyle(
                      forceStrutHeight: true,
                      height: 1,
                      fontSize: 7.2,
                    ),
                    style: TextStyle(
                      fontSize: 7.2,
                      fontWeight: FontWeight.w700,
                      color: present
                          ? AppColors.neonCyan.withOpacity(0.9)
                          : Colors.transparent,
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
