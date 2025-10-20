class SudokuModel {
  // Two sample puzzles; 0 = empty.
  final List<List<List<int>>> _puzzles = [
    [
      [0, 0, 0, 2, 6, 0, 7, 0, 1],
      [6, 8, 0, 0, 7, 0, 0, 9, 0],
      [1, 9, 0, 0, 0, 4, 5, 0, 0],
      [8, 2, 0, 1, 0, 0, 0, 4, 0],
      [0, 0, 4, 6, 0, 2, 9, 0, 0],
      [0, 5, 0, 0, 0, 3, 0, 2, 8],
      [0, 0, 9, 3, 0, 0, 0, 7, 4],
      [0, 4, 0, 0, 5, 0, 0, 3, 6],
      [7, 0, 3, 0, 1, 8, 0, 0, 0],
    ],
    [
      [2, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 6, 0, 0, 0, 0, 3],
      [0, 7, 4, 0, 8, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 3, 0, 0, 2],
      [0, 8, 0, 0, 4, 0, 0, 1, 0],
      [6, 0, 0, 5, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 1, 0, 7, 8, 0],
      [5, 0, 0, 0, 0, 9, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 4, 0],
    ],
  ];

  late List<List<int>> initial;
  late List<List<int>> board;
  int currentPuzzleIndex = 0;

  SudokuModel() {
    load(0);
  }

  void load(int index) {
    currentPuzzleIndex = index % _puzzles.length;
    initial = _puzzles[currentPuzzleIndex]
        .map((r) => List<int>.from(r))
        .toList();
    board = _puzzles[currentPuzzleIndex].map((r) => List<int>.from(r)).toList();
  }

  bool get isComplete {
    for (final row in board) {
      if (row.contains(0)) return false;
    }
    return !hasAnyConflicts();
  }

  bool isFixed(int r, int c) => initial[r][c] != 0;

  void setCell(int r, int c, int? value) {
    if (isFixed(r, c)) return;
    board[r][c] = value ?? 0;
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

  bool hasAnyConflicts() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (isConflict(r, c)) return true;
      }
    }
    return false;
  }

  bool get hasZeros {
    for (final row in board) {
      if (row.contains(0)) return true;
    }
    return false;
  }
}
