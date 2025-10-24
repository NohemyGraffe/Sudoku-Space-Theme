import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/sudoku_board.dart';
import '../models/difficulty.dart';
import '../widgets/num_key.dart';
import 'dart:async'; // <-- add this for Timer

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

  Timer? _ticker; // runs once per second
  int elapsed = 0; // seconds
  int mistakes = 0; // counts wrong placements
  bool _paused = false; // pause/resume flag

  // NEW: notes mode switch
  bool notesMode = false;

  @override
  void initState() {
    super.initState();
    model = SudokuModel()..loadRandom(widget.startDifficulty);
    _startTimer(); // <-- start ticking once model exists

    // Check for win after every setState
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWin());
  }

  @override
  void dispose() {
    _ticker?.cancel(); // <-- stop the timer
    super.dispose();
  }

  void _newGame() {
    model.loadRandom(model.currentDifficulty);
    selectedRow = null;
    selectedCol = null;
    elapsed = 0; // <-- reset
    _paused = false; // <-- ensure running
    mistakes = 0; // reset mistakes on new game
    _startTimer(); // <-- restart
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
    // If this was a definitive placement (not a note) check for a conflict
    if (valueOrNumber != null) {
      final conflict = model.isConflict(r, c);
      if (conflict) {
        mistakes++;
        if (mistakes >= 3) {
          _paused = true; // pause timer
          // Use a microtask to ensure UI has updated before showing dialog
          Future.microtask(() {
            showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                title: const Text('Game over'),
                content: const Text(
                  'You made three mistakes. Do you want to start a new game?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx); // close dialog
                      _newGame();
                    },
                    child: const Text('New Game'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx); // close dialog
                      Navigator.pop(context); // return to home
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          });
        }
      }
    }

    // After any move, check if we won
    Future.microtask(() => _checkWin());

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

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused) {
        setState(() => elapsed++);
      }
    });
  }

  void _pauseTimer() => setState(() => _paused = true);
  void _resumeTimer() => setState(() => _paused = false);

  void _checkWin() {
    if (model.isComplete && !_paused) {
      _paused = true; // pause timer when won
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, anim1, anim2) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonLime.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(
                  color: AppColors.neonLime.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated celebration text
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (value * 0.4),
                        child: Opacity(
                          opacity: value,
                          child: const Text(
                            '🎉 Congratulations! 🎉\nPuzzle Completed!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neonLime,
                              height: 1.3,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // close dialog
                          _newGame();
                        },
                        child: const Text(
                          'New Game',
                          style: TextStyle(
                            color: AppColors.neonCyan,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // close dialog
                          Navigator.pop(context); // return to home
                        },
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: AppColors.neonPink,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  String _mmss(int s) {
    final m = s ~/ 60;
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
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
          // MISTAKES UI (decorated to prevent blending / clipping)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.neonPink.withOpacity(0.22)),
              ),
              child: Text(
                'Mistakes: $mistakes/3',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonPink,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          // TIMER UI
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                _mmss(elapsed),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _paused ? 'Resume' : 'Pause',
            icon: Icon(
              _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            ),
            onPressed: () => _paused ? _resumeTimer() : _pauseTimer(),
          ),

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
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),

      // Check for win after state updates
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
