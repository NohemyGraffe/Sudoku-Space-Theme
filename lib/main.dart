import 'package:flutter/material.dart';

void main() => runApp(const BoringSudokuApp());

class BoringSudokuApp extends StatelessWidget {
  const BoringSudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Neon, happy, stylish color palette
    const bg = Color(0xFF0B0B0F);
    const neonPink = Color(0xFFFF3FA4);
    const neonCyan = Color(0xFF00D1FF);
    const neonLime = Color(0xFFB3FF00);
    const neonViolet = Color(0xFFB266FF);
    const card = Color(0xFF141419);
    const text = Color(0xFFF5F5F5);
    const muted = Color(0xFFB7B7C0);

    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: neonPink,
        secondary: neonCyan,
        surface: card,
        onSurface: text,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        bodyMedium: TextStyle(letterSpacing: 0.2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonPink,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BoringSudoku',
      theme: theme,
      home: GameScreen(
        colors: const SudokuColors(
          bg: bg,
          neonPink: neonPink,
          neonCyan: neonCyan,
          neonLime: neonLime,
          neonViolet: neonViolet,
          card: card,
          text: text,
          muted: muted,
        ),
      ),
    );
  }
}

class SudokuColors {
  final Color bg, neonPink, neonCyan, neonLime, neonViolet, card, text, muted;
  const SudokuColors({
    required this.bg,
    required this.neonPink,
    required this.neonCyan,
    required this.neonLime,
    required this.neonViolet,
    required this.card,
    required this.text,
    required this.muted,
  });
}

/// Tiny Sudoku with:
/// - tap to select cell
/// - number pad input
/// - conflict highlighting
/// - win detection
/// - "New Game" cycles two built-in puzzles
class GameScreen extends StatefulWidget {
  final SudokuColors colors;
  const GameScreen({super.key, required this.colors});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Two sample puzzles; 0 = empty.
  final List<List<List<int>>> puzzles = [
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

  // Immutable initial board + mutable current board
  late List<List<int>> initial;
  late List<List<int>> board;
  int currentPuzzleIndex = 0;
  int? selectedRow;
  int? selectedCol;

  @override
  void initState() {
    super.initState();
    _loadPuzzle(0);
  }

  void _loadPuzzle(int index) {
    currentPuzzleIndex = index % puzzles.length;
    initial = puzzles[currentPuzzleIndex]
        .map((r) => List<int>.from(r))
        .toList();
    board = puzzles[currentPuzzleIndex].map((r) => List<int>.from(r)).toList();
    selectedRow = null;
    selectedCol = null;
    setState(() {});
  }

  bool get _isComplete {
    for (final row in board) {
      if (row.contains(0)) return false;
    }
    return !_hasAnyConflicts();
  }

  bool _isFixed(int r, int c) => initial[r][c] != 0;

  void _onCellTap(int r, int c) {
    if (_isFixed(r, c)) return;
    setState(() {
      selectedRow = r;
      selectedCol = c;
    });
  }

  void _onInput(int? value) {
    if (selectedRow == null || selectedCol == null) return;
    final r = selectedRow!;
    final c = selectedCol!;
    if (_isFixed(r, c)) return;
    setState(() {
      board[r][c] = value ?? 0;
    });
  }

  bool _isConflict(int r, int c) {
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

  bool _hasAnyConflicts() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_isConflict(r, c)) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge!.copyWith(color: c.text, fontSize: 24);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFFFF3FA4), Color(0xFF00D1FF), Color(0xFFB3FF00)],
          ).createShader(rect),
          child: const Text('BoringSudoku'),
        ),
        actions: [
          IconButton(
            tooltip: 'New Game',
            onPressed: () => _loadPuzzle(currentPuzzleIndex + 1),
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
              style: titleStyle.copyWith(fontSize: 14, color: c.muted),
            ),
            const SizedBox(height: 12),

            // Board card
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: c.neonPink.withOpacity(0.12),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: c.neonViolet.withOpacity(0.35),
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

            _buildNumberPad(),
            const SizedBox(height: 12),

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
                        final ok = !_hasAnyConflicts() && !_boardHasZeros();
                        final snack = SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: ok ? c.neonLime : Colors.redAccent,
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
      bottomNavigationBar: _isComplete
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.card,
                boxShadow: [
                  BoxShadow(
                    color: c.neonLime.withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
                border: Border(
                  top: BorderSide(color: c.neonLime.withOpacity(0.6), width: 2),
                ),
              ),
              child: Text(
                '🎉 Completed! You’re glowing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.neonLime,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
            )
          : null,
    );
  }

  bool _boardHasZeros() {
    for (final row in board) {
      if (row.contains(0)) return true;
    }
    return false;
  }

  Widget _buildGrid() {
    final c = widget.colors;
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
        final col = index % 9;

        final selected = (selectedRow == r && selectedCol == col);
        final fixed = _isFixed(r, col);
        final conflict = _isConflict(r, col);

        // Neon borders every 3rd line (subgrid)
        final thickTop = r % 3 == 0;
        final thickLeft = col % 3 == 0;

        Color cellBg = Colors.transparent;
        if (selected) {
          cellBg = widget.colors.neonCyan.withOpacity(0.12);
        }

        return Container(
          decoration: BoxDecoration(
            color: cellBg,
            border: Border(
              top: BorderSide(
                color: thickTop
                    ? c.neonPink.withOpacity(0.8)
                    : c.neonViolet.withOpacity(0.35),
                width: thickTop ? 2 : 1,
              ),
              left: BorderSide(
                color: thickLeft
                    ? c.neonPink.withOpacity(0.8)
                    : c.neonViolet.withOpacity(0.35),
                width: thickLeft ? 2 : 1,
              ),
              right: const BorderSide(color: Colors.transparent, width: 0),
              bottom: const BorderSide(color: Colors.transparent, width: 0),
            ),
          ),
          child: InkWell(
            onTap: () => _onCellTap(r, col),
            borderRadius: BorderRadius.circular(6),
            child: Center(
              child: Text(
                board[r][col] == 0 ? '' : board[r][col].toString(),
                style: TextStyle(
                  fontWeight: fixed ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 18,
                  letterSpacing: 0.5,
                  color: conflict
                      ? Colors.redAccent
                      : (fixed ? Colors.white : widget.colors.neonLime),
                  shadows: [
                    Shadow(
                      color:
                          (conflict
                                  ? Colors.redAccent
                                  : (fixed
                                        ? widget.colors.neonPink
                                        : widget.colors.neonLime))
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

  Widget _buildNumberPad() {
    final numbers = List<int>.generate(9, (i) => i + 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final n in numbers)
            _NumKey(label: n.toString(), onTap: () => _onInput(n)),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.primary.withOpacity(0.65),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.secondary.withOpacity(0.22),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: scheme.secondary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
