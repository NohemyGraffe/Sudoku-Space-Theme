import 'dart:math';
import '../data/puzzles.dart';
import 'difficulty.dart';

class SudokuModel {
  late List<List<int>> initial;
  late List<List<int>> board;
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
  }

  void setCell(int r, int c, int? value) {
    if (isFixed(r, c)) return;
    board[r][c] = value ?? 0;
  }

  bool isFixed(int r, int c) => initial[r][c] != 0;

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
    for (var i = 0; i < 9; i++) {
      if (board[i][c] == v) colCount++;
    }
    if (colCount > 1) return true;
    // Box
    final br = (r ~/ 3) * 3;
    final bc = (c ~/ 3) * 3;
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
}
