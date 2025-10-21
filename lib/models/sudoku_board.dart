import 'dart:math';
import '../data/puzzles.dart';
import 'difficulty.dart';

class SudokuModel {
  late List<List<int>> initial; // 9x9, 0 = empty
  late List<List<int>> board; // 9x9, 0 = empty

  /// Per-cell notes (candidates 1..9)
  late List<List<Set<int>>> notes; // 9x9 of sets

  Difficulty currentDifficulty = Difficulty.easy;
  final _rand = Random();

  /// Default constructor starts a random puzzle (kept as-is for your flows)
  SudokuModel() {
    loadRandom(Difficulty.easy);
  }

  /// Private constructor used by fromMap to avoid calling loadRandom().
  SudokuModel._internal();

  void loadRandom(Difficulty difficulty) {
    currentDifficulty = difficulty;
    final list = puzzlesByDifficulty[difficulty]!;
    final src = list[_rand.nextInt(list.length)];
    initial = src.map((r) => List<int>.from(r)).toList();
    board = src.map((r) => List<int>.from(r)).toList();
    notes = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
  }

  bool isFixed(int r, int c) => initial[r][c] != 0;

  /// Set a definitive value (not a note)
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

  // ============================================================
  //                P E R S I S T E N C E   A P I
  // ============================================================

  /// Serialize full game state to a Map (JSON-safe).
  Map<String, dynamic> toMap() => {
    'difficulty': currentDifficulty.name,
    'initial': initial, // List<List<int>>
    'board': board, // List<List<int>>
    // notes as lists so JSON can encode them
    'notes': notes
        .map(
          (row) => row.map((s) {
            final list = s.toList()..sort();
            return list;
          }).toList(),
        )
        .toList(),
  };

  /// Rebuild a SudokuModel from a previously saved Map.
  /// Safe-guards ensure 9x9 shapes; missing notes are initialized empty.
  factory SudokuModel.fromMap(Map<String, dynamic> m) {
    final model = SudokuModel._internal();

    // Difficulty
    final diffName = (m['difficulty'] as String?) ?? Difficulty.easy.name;
    model.currentDifficulty = Difficulty.values.firstWhere(
      (d) => d.name == diffName,
      orElse: () => Difficulty.easy,
    );

    // Initial & Board
    model.initial = _read9x9IntGrid(m['initial']) ?? _emptyIntGrid();
    model.board = _read9x9IntGrid(m['board']) ?? _cloneIntGrid(model.initial);

    // Notes
    final parsedNotes = _read9x9Notes(m['notes']);
    model.notes = parsedNotes ?? _emptyNotesGrid();

    return model;
  }

  // ---------- Static helpers for fromMap ----------

  static List<List<int>>? _read9x9IntGrid(dynamic src) {
    if (src is! List || src.length != 9) return null;
    final out = <List<int>>[];
    for (final row in src) {
      if (row is! List || row.length != 9) return null;
      out.add(List<int>.from(row.map((e) => (e as num).toInt())));
    }
    return out;
  }

  static List<List<Set<int>>>? _read9x9Notes(dynamic src) {
    if (src == null) return null;
    if (src is! List || src.length != 9) return null;
    final out = <List<Set<int>>>[];
    for (final row in src) {
      if (row is! List || row.length != 9) return null;
      final listRow = <Set<int>>[];
      for (final cell in row) {
        if (cell is List) {
          listRow.add(Set<int>.from(cell.map((e) => (e as num).toInt())));
        } else {
          // If malformed, fallback to empty set
          listRow.add(<int>{});
        }
      }
      out.add(listRow);
    }
    return out;
  }

  static List<List<int>> _emptyIntGrid() =>
      List.generate(9, (_) => List.filled(9, 0));

  static List<List<int>> _cloneIntGrid(List<List<int>> grid) =>
      grid.map((r) => List<int>.from(r)).toList();

  static List<List<Set<int>>> _emptyNotesGrid() =>
      List.generate(9, (_) => List.generate(9, (_) => <int>{}));
}
