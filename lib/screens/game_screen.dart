import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/sudoku_board.dart';
import '../models/difficulty.dart';
import '../widgets/num_key.dart';
import 'dart:async'; // <-- add this for Timer
import 'dart:ui'; // for ImageFilter.blur
import '../services/game_persistence.dart';

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
  int score = 0;

  Timer? _ticker; // runs once per second
  int elapsed = 0; // seconds
  int mistakes = 0; // counts wrong placements
  bool _paused = false; // pause/resume flag
  int _lastSavedElapsed = -1; // throttle periodic autosaves

  // NEW: notes mode switch
  bool notesMode = false;
  // Highlight same-number taps
  int? highlightedNumber;
  // Pressed states for action buttons
  bool _undoPressed = false;
  bool _erasePressed = false;
  bool _notesPressed = false;
  // Track if a modal dialog is open to suppress pause overlay
  bool _modalOpen = false;

  // Undo history: list of board snapshots
  final List<List<List<int>>> _undoHistory = [];
  final List<Map<String, Set<int>>> _undoNotesHistory = [];
  final List<int> _undoScoreHistory = [];

  @override
  void initState() {
    super.initState();
    model = SudokuModel()..loadRandom(widget.startDifficulty);
    _startTimer(); // start ticking once model exists
    // Record that this difficulty is now the last-opened game
    GamePersistence.setLastOpened(widget.startDifficulty, elapsedSeconds: 0);

    // Try loading a previously saved game for this difficulty
    _tryLoadSaved();

    // Check for win after every setState
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWin());
  }

  @override
  void dispose() {
    _ticker?.cancel(); // stop the timer
    // Persist on exit so user can resume
    _persist();
    super.dispose();
  }

  Future<void> _tryLoadSaved() async {
    final loaded = await GamePersistence.load(widget.startDifficulty);
    if (loaded == null) {
      // No saved game yet for this difficulty; persist initial state so Continue can find it
      await _persist();
      return;
    }
    if (!mounted) return;
    setState(() {
      model = loaded.model;
      elapsed = loaded.elapsedSeconds;
      score = loaded.score;
      mistakes = loaded.mistakes;
      // keep other UI state as-is
    });
    // Ensure last-opened points to this resumed game with accurate elapsed
    await GamePersistence.setLastOpened(
      model.currentDifficulty,
      elapsedSeconds: elapsed,
    );
  }

  Future<void> _persist() async {
    await GamePersistence.save(
      model,
      elapsedSeconds: elapsed,
      score: score,
      mistakes: mistakes,
    );
  }

  void _newGame() {
    model.loadRandom(model.currentDifficulty);
    selectedRow = null;
    selectedCol = null;
    elapsed = 0; // <-- reset
    _paused = false; // <-- ensure running
    mistakes = 0; // reset mistakes on new game
    score = 0; // reset score for new game
    _startTimer(); // <-- restart
    highlightedNumber = null;
    _undoHistory.clear();
    _undoNotesHistory.clear();
    _undoScoreHistory.clear();
    setState(() {});
    // Save the new fresh game state
    _persist();
    // Update last-opened to this fresh game
    GamePersistence.setLastOpened(model.currentDifficulty, elapsedSeconds: 0);
  }

  // Reset the current puzzle to its initial state (same puzzle)
  void _resetCurrentPuzzle() {
    // Restore the board to the original initial grid
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        model.board[r][c] = model.initial[r][c];
        model.notes[r][c].clear();
      }
    }
    selectedRow = null;
    selectedCol = null;
    highlightedNumber = null;
    mistakes = 0;
    elapsed = 0;
    score = 0;
    _undoHistory.clear();
    _undoNotesHistory.clear();
    _undoScoreHistory.clear();
    _paused = false;
    _startTimer();
    setState(() {});
    _persist();
    // Keep last-opened pointing to this difficulty and reset elapsed
    GamePersistence.setLastOpened(model.currentDifficulty, elapsedSeconds: 0);
  }

  void _saveState() {
    // Save current board state for undo
    _undoHistory.add(model.board.map((row) => List<int>.from(row)).toList());
    // Save notes state
    final notesSnapshot = <String, Set<int>>{};
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final notes = model.notesAt(r, c);
        if (notes.isNotEmpty) {
          notesSnapshot['$r,$c'] = Set<int>.from(notes);
        }
      }
    }
    _undoNotesHistory.add(notesSnapshot);
    _undoScoreHistory.add(score);
  }

  void _undo() {
    if (_undoHistory.isEmpty) return;

    // Restore previous state
    final prevBoard = _undoHistory.removeLast();
    final prevNotes = _undoNotesHistory.removeLast();
    final prevScore = _undoScoreHistory.removeLast();

    // Restore board
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        model.board[r][c] = prevBoard[r][c];
      }
    }

    // Restore notes - clear all first
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        model.notes[r][c].clear();
      }
    }
    // Then restore saved notes
    prevNotes.forEach((key, notes) {
      final parts = key.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      model.notes[r][c].addAll(notes);
    });

    score = prevScore;
    setState(() {});
  }

  void _onCellTap(int r, int c) {
    if (_paused) return; // <--- add this
    setState(() {
      selectedRow = r;
      selectedCol = c;
      final v = model.board[r][c];
      highlightedNumber = (v != 0) ? v : null;
    });
  }

  void _onInput(int? valueOrNumber) {
    if (_paused) return; // safety: don’t score while paused
    if (selectedRow == null || selectedCol == null) return;
    final r = selectedRow!, c = selectedCol!;
    // If the cell already has a definitive value, prevent selecting a different
    // number at the same time. Require erase first to change it.
    if (!notesMode && model.board[r][c] != 0 && valueOrNumber != null) {
      if (model.board[r][c] == valueOrNumber) {
        // Same number tapped as already in the cell: no-op
        return;
      }
      // Replace any current snackbar so they don't queue up.
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Erase first to change this cell.'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }

    if (notesMode) {
      if (valueOrNumber == null) return;
      if (model.isFixed(r, c)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an empty cell to add notes.')),
        );
        return;
      }
      _saveState(); // Save before modifying
      model.toggleNote(r, c, valueOrNumber);
      setState(() {}); // (no scoring for notes in Option A)
      _persist();
      return;
    }

    // ---- OPTION A SCORING START ----
    // Only score the FIRST time you correctly fill an empty cell.
    final wasEmpty = (model.board[r][c] == 0);

    // If we're about to place a number into an empty cell, get candidate count BEFORE changing the board.
    int candBefore = 0;
    if (valueOrNumber != null && wasEmpty) {
      candBefore = _candidateCount(r, c);
    }
    // ---- OPTION A SCORING END (pre-calc) ----

    _saveState(); // Save before modifying
    model.setCell(r, c, valueOrNumber);

    // Highlight logic (unchanged)
    highlightedNumber = (valueOrNumber != null) ? valueOrNumber : null;

    if (valueOrNumber != null) {
      final conflict = model.isConflict(r, c);
      if (conflict) {
        mistakes++;
        if (mistakes >= 3) {
          _pauseTimer();
          // Mark modal open to suppress pause overlay while dialog is visible
          if (mounted) setState(() => _modalOpen = true);
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
                title: const Text('You ran out of chances!'),
                content: const Text('Select an option:'),
                actions: [
                  TextButton(
                    onPressed: () {
                      // Try again: same puzzle
                      if (mounted) setState(() => _modalOpen = false);
                      Navigator.pop(ctx); // close dialog
                      _resetCurrentPuzzle();
                    },
                    child: const Text('Try Again'),
                  ),
                  TextButton(
                    onPressed: () {
                      // New game: new random in same difficulty
                      if (mounted) setState(() => _modalOpen = false);
                      Navigator.pop(ctx); // close dialog
                      _newGame();
                    },
                    child: const Text('New Game'),
                  ),
                  TextButton(
                    onPressed: () {
                      if (mounted) setState(() => _modalOpen = false);
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
      } else if (wasEmpty) {
        // ---- OPTION A SCORING APPLY ----
        // Harder = fewer candidates => more points.
        // Formula: 20 + (9 - candidateCount) * 5  → ranges ~25..60
        final gain = 20 + (9 - candBefore) * 5;
        score = ((score + gain).clamp(0, 999999)).toInt();
        // Add to all-time total points (fire-and-forget)
        GamePersistence.addToTotal(gain);

        // (Optional) quick feedback:
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('+$gain points!'), duration: Duration(milliseconds: 600)),
        // );
      }
    }

    Future.microtask(() => _checkWin());
    setState(() {});
    _persist();
  }

  void _erase() {
    if (_paused) return; // <--- add this
    if (selectedRow == null || selectedCol == null) return;
    final r = selectedRow!, c = selectedCol!;
    _saveState(); // Save before modifying
    if (notesMode) {
      model.clearNotes(r, c);
    } else {
      model.setCell(r, c, null);
      // clearing a cell should clear number highlights
      highlightedNumber = null;
    }
    setState(() {});
    _persist();
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused) {
        setState(() => elapsed++);
        // Throttled autosave every 5 seconds
        if (elapsed % 5 == 0 && _lastSavedElapsed != elapsed) {
          _lastSavedElapsed = elapsed;
          _persist();
        }
      }
    });
  }

  void _pauseTimer() {
    // stop the periodic ticker to fully suspend time updates
    _ticker?.cancel();
    setState(() => _paused = true);
    _persist();
  }

  void _resumeTimer() {
    // resume ticking and UI
    setState(() => _paused = false);
    _startTimer();
  }

  void _checkWin() {
    if (model.isComplete && !_paused) {
      _pauseTimer(); // pause timer when won
      // Clear saved progress for this difficulty upon completion
      GamePersistence.clear(model.currentDifficulty);
      if (mounted) setState(() => _modalOpen = true);
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
                          if (mounted) setState(() => _modalOpen = false);
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
                          if (mounted) setState(() => _modalOpen = false);
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
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          toolbarHeight: 80, // Further reduced
          title: Stack(
            children: [
              // Centered difficulty label at the very top
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    difficultyLabel(model.currentDifficulty),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.neonCyan,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              // Back arrow in top-left
              Positioned(
                left: 8,
                top: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.neonCyan,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // Game metrics below
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 40, 12, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // LEFT: SCORE
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.neonLime.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            'Score: $score',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.neonLime,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        // CENTER: MISTAKES
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.neonPink.withOpacity(0.25),
                            ),
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

                        // RIGHT: TIMER + BUTTONS
                        Row(
                          children: [
                            Text(
                              _mmss(elapsed),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _paused
                                    ? AppColors.muted
                                    : AppColors.text,
                                fontSize: 14,
                              ),
                            ),
                            IconButton(
                              tooltip: _paused ? 'Resume' : 'Pause',
                              icon: Icon(
                                _paused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                color: AppColors.neonCyan,
                              ),
                              onPressed: () =>
                                  _paused ? _resumeTimer() : _pauseTimer(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false, // Remove top SafeArea padding
          child: Stack(
            children: [
              // Your existing game UI
              Column(
                children: [
                  // Extra space between top widgets and the puzzle board
                  const SizedBox(height: 12),
                  // --- Board area (top-aligned, no extra expansion) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
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
                        ),
                        padding: const EdgeInsets.all(4),
                        child: _buildGrid(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40), // Space between board and actions
                  // --- Actions ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Undo (entire column is clickable: icon + label)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) {
                            if (_undoHistory.isEmpty) return;
                            setState(() => _undoPressed = true);
                          },
                          onTapUp: (_) {
                            if (_undoHistory.isEmpty) return;
                            setState(() => _undoPressed = false);
                          },
                          onTapCancel: () {
                            if (_undoHistory.isEmpty) return;
                            setState(() => _undoPressed = false);
                          },
                          onTap: () {
                            if (_undoHistory.isEmpty) return;
                            _undo();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _undoPressed
                                  ? [
                                      BoxShadow(
                                        color: AppColors.neonCyan.withOpacity(
                                          0.35,
                                        ),
                                        blurRadius: 14,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  scale: _undoPressed ? 0.92 : 1.0,
                                  duration: const Duration(milliseconds: 90),
                                  curve: Curves.easeOut,
                                  child: Icon(
                                    Icons.undo_rounded,
                                    size: 32,
                                    color: _undoHistory.isEmpty
                                        ? AppColors.muted.withOpacity(0.3)
                                        : AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Undo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _undoHistory.isEmpty
                                        ? AppColors.muted.withOpacity(0.3)
                                        : AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        // Erase (entire column is clickable: icon + label)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) =>
                              setState(() => _erasePressed = true),
                          onTapUp: (_) => setState(() => _erasePressed = false),
                          onTapCancel: () =>
                              setState(() => _erasePressed = false),
                          onTap: () {
                            _erase();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _erasePressed
                                  ? [
                                      BoxShadow(
                                        color: AppColors.neonPink.withOpacity(
                                          0.35,
                                        ),
                                        blurRadius: 14,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  scale: _erasePressed ? 0.92 : 1.0,
                                  duration: const Duration(milliseconds: 90),
                                  curve: Curves.easeOut,
                                  child: const Icon(
                                    Icons.auto_fix_high_rounded,
                                    size: 32,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Erase',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        // Notes (entire column is clickable: icon + label)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) =>
                              setState(() => _notesPressed = true),
                          onTapUp: (_) => setState(() => _notesPressed = false),
                          onTapCancel: () =>
                              setState(() => _notesPressed = false),
                          onTap: () {
                            setState(() {
                              notesMode = !notesMode;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _notesPressed
                                  ? [
                                      BoxShadow(
                                        color: AppColors.neonCyan.withOpacity(
                                          0.35,
                                        ),
                                        blurRadius: 14,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  scale: _notesPressed ? 0.92 : 1.0,
                                  duration: const Duration(milliseconds: 90),
                                  curve: Curves.easeOut,
                                  child: Icon(
                                    notesMode
                                        ? Icons.edit
                                        : Icons.mode_edit_outline_outlined,
                                    size: 32,
                                    color: notesMode
                                        ? AppColors.neonCyan
                                        : AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Notes',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: notesMode
                                        ? AppColors.neonCyan
                                        : AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 40,
                  ), // 40px space between actions and keypad
                  // --- Number pad: force-fit single horizontal row ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final available = constraints.maxWidth;

                        // Determine which numbers are still available (not fully placed yet).
                        final allNums = List<int>.generate(9, (i) => i + 1);
                        final completed = _completedNumbers();
                        final nums = [
                          for (final n in allNums)
                            if (!completed.contains(n)) n,
                        ];
                        final keys = nums.length;

                        // Try progressively smaller spacings so keys can fit without scrolling.
                        // Make spacing tighter so keys are visually closer together.
                        final spacingOptions = [4.0, 2.0, 1.0, 0.0];
                        // Slightly increase min width so keys are more visible, but still fit
                        const minKeySize = 30.0;
                        const maxKeySize = 64.0;

                        double chosenSpacing = spacingOptions.first;
                        double computedSize = minKeySize;
                        bool fitted = false;

                        for (final s in spacingOptions) {
                          final totalSpacing = s * (keys - 1);
                          final candidate = (available - totalSpacing) / keys;
                          if (candidate >= minKeySize) {
                            chosenSpacing = s;
                            computedSize = candidate.clamp(
                              minKeySize,
                              maxKeySize,
                            );
                            fitted = true;
                            break;
                          }
                        }

                        // As a fallback, if none of the spacings produced a candidate >= minKeySize,
                        // compute a key size that fits even on very narrow screens.
                        if (!fitted) {
                          chosenSpacing =
                              spacingOptions.last; // tightest spacing
                          final totalSpacing = chosenSpacing * (keys - 1);
                          final candidate = (available - totalSpacing) / keys;
                          // allow going smaller than min to avoid overflow on extreme cases
                          computedSize = candidate.clamp(12.0, maxKeySize);
                        }

                        final keySize = computedSize;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 0; i < nums.length; i++) ...[
                              NumKey(
                                size: keySize,
                                label: '${nums[i]}',
                                onTap: () => _onInput(nums[i]),
                              ),
                              if (i != nums.length - 1)
                                SizedBox(width: chosenSpacing),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ), // Reduced from 12 for compact layout
                  const SizedBox(
                    height: 2,
                  ), // Reduced from 16 for compact layout
                ],
              ),

              // --- Full-screen pause overlay ---
              if (_paused && !_modalOpen)
                Positioned.fill(child: _buildPauseOverlay()),
            ],
          ),
        ),

        // Check for win after state updates
        bottomNavigationBar: model.isComplete
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
      ),
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
        final hasHighlight =
            highlightedNumber != null && !isEmpty && value == highlightedNumber;
        // Highlight full row, column, and 3x3 block for the selected cell
        bool inSelectedRegion = false;
        if (selectedRow != null && selectedCol != null) {
          final sr = selectedRow!, sc = selectedCol!;
          final sameRow = r == sr;
          final sameCol = c == sc;
          final sameBlock = (r ~/ 3 == sr ~/ 3) && (c ~/ 3 == sc ~/ 3);
          inSelectedRegion = (sameRow || sameCol || sameBlock);
        }

        // Prepare subtle glow shadows per state
        List<BoxShadow>? cellShadows;
        if (selected) {
          // Selected cell stands out most (neon pink glow to match theme)
          cellBg = AppColors.neonPink.withOpacity(0.22);
          cellShadows = [
            BoxShadow(
              color: AppColors.neonPink.withOpacity(0.35),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ];
        } else if (hasHighlight) {
          // Same-number highlight across the grid
          cellBg = AppColors.neonPink.withOpacity(0.24);
          cellShadows = [
            BoxShadow(
              color: AppColors.neonPink.withOpacity(0.30),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ];
        } else if (inSelectedRegion) {
          // Subtle region highlight for row/col/block
          cellBg = AppColors.neonViolet.withOpacity(0.14);
          cellShadows = [
            BoxShadow(
              color: AppColors.neonViolet.withOpacity(0.22),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ];
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onCellTap(r, c),
          child: Container(
            decoration: BoxDecoration(
              color: cellBg,
              boxShadow: cellShadows,
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
                          fontSize: 34,
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

  // Count possible candidates for an empty cell (1..9 not present in row/col/box)
  int _candidateCount(int r, int c) {
    // If already filled, treat as no candidates (won’t be scored)
    if (model.board[r][c] != 0) return 0;

    final used = <int>{};

    // row
    for (var cc = 0; cc < 9; cc++) {
      final v = model.board[r][cc];
      if (v != 0) used.add(v);
    }
    // col
    for (var rr = 0; rr < 9; rr++) {
      final v = model.board[rr][c];
      if (v != 0) used.add(v);
    }
    // 3x3 box
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (var rr = br; rr < br + 3; rr++) {
      for (var cc = bc; cc < bc + 3; cc++) {
        final v = model.board[rr][cc];
        if (v != 0) used.add(v);
      }
    }

    // candidates = numbers 1..9 not used
    var cnt = 0;
    for (var n = 1; n <= 9; n++) {
      if (!used.contains(n)) cnt++;
    }
    return cnt;
  }

  // Compute which numbers are fully placed on the board (9 or more occurrences).
  Set<int> _completedNumbers() {
    final counts = List<int>.filled(10, 0); // 1..9
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final v = model.board[r][c];
        if (v >= 1 && v <= 9) counts[v]++;
      }
    }
    final done = <int>{};
    for (var n = 1; n <= 9; n++) {
      if (counts[n] >= 9) done.add(n);
    }
    return done;
  }

  Widget _buildPauseOverlay() {
    // A blur + tinted overlay to completely obscure puzzle details while paused.
    // Use BackdropFilter to blur content behind, plus a semi-opaque tint.
    return Stack(
      children: [
        // Blur and dim the entire background so numbers are indistinguishable
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(color: AppColors.card.withOpacity(0.60)),
            ),
          ),
        ),

        // Foreground pause panel
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonViolet.withOpacity(0.25),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: AppColors.neonViolet.withOpacity(0.6),
                width: 1.6,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pause_circle_filled_rounded,
                  size: 56,
                  color: AppColors.neonPink,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Paused',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neonCyan,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Timer stopped • Board hidden',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _resumeTimer,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Resume'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonLime,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
