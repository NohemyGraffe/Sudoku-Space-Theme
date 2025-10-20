import 'dart:math';
import '../data/puzzles.dart';
import 'difficulty.dart';

class SudokuModel {
  late List<List<int>> initial;
  late List<List<int>> board;

  // NEW: per-cell notes (candidates 1..9)
  late List<List<Set<int>>> notes;

  Difficulty currentDifficulty = Difficulty.easy;
  final _rand = Random();

  SudokuModel() {
    loadRandom(Difficulty.easy);
  }

  void loadRandom(Difficulty difficulty) {
    currentDifficulty = difficulty;
    final list = puzzlesByDifficulty[difficulty]!;
    final src = list[_rand.nextInt(list.length)];
    initial = src.map((r) => List<int>.from(r)).toList();
    board = src.map((r) => List<int>.from(r)).toList();
    notes = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
  }

  bool isFixed(int r, int c) => initial[r][c] != 0;

  // Set a definitive value (not a note)
  void setCell(int r, int c, int? value) {
    if (isFixed(r, c)) return;
    board[r][c] = value ?? 0;
    // Clear notes in this cell whenever the value changes
    notes[r][c].clear();

    // If we placed a value, remove that candidate from peers (row/col/box)
    final v = board[r][c];
    if (v != 0) {
      for (final p in _peersOf(r, c)) {
        notes[p.$1][p.$2].remove(v);
      }
    }
  }

  // NOTES API
  Set<int> notesAt(int r, int c) => notes[r][c];

  void toggleNote(int r, int c, int n) {
    if (isFixed(r, c)) return;

    // Make sure we can always attach notes to this editable cell.
    // If somehow a value exists, clear it so notes can show.
    if (board[r][c] != 0) {
      board[r][c] = 0;
    }

    final s = notes[r][c];
    if (!s.remove(n)) {
      s.add(n);
    }
  }

  void clearNotes(int r, int c) {
    notes[r][c].clear();
  }

  bool get isComplete {
    for (final row in board) {
      if (row.contains(0)) return false;
    }
    return !hasAnyConflicts();
  }

  bool hasAnyConflicts() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (isConflict(r, c)) return true;
      }
    }
    return false;
  }

  bool isConflict(int r, int c) {
    final v = board[r][c];
    if (v == 0) return false;
    // Row
    if (board[r].where((x) => x == v).length > 1) return true;
    // Col
    int colCount = 0;
    for (var i = 0; i < 9; i++) if (board[i][c] == v) colCount++;
    if (colCount > 1) return true;
    // Box
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    int boxCount = 0;
    for (int i = br; i < br + 3; i++) {
      for (int j = bc; j < bc + 3; j++) {
        if (board[i][j] == v) boxCount++;
      }
    }
    return boxCount > 1;
  }

  bool get hasZeros {
    for (final row in board) {
      if (row.contains(0)) return true;
    }
    return false;
  }

  // Helpers
  Iterable<(int, int)> _peersOf(int r, int c) sync* {
    // Row peers
    for (int j = 0; j < 9; j++) {
      if (j != c) yield (r, j);
    }
    // Col peers
    for (int i = 0; i < 9; i++) {
      if (i != r) yield (i, c);
    }
    // Box peers
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (int i = br; i < br + 3; i++) {
      for (int j = bc; j < bc + 3; j++) {
        if (i == r && j == c) continue;
        yield (i, j);
      }
    }
  }
}
