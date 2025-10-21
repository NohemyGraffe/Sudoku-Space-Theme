// lib/services/game_persistence.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/difficulty.dart';
import '../models/sudoku_board.dart';

class GamePersistence {
  static const _version = 'v1';
  static String _key(Difficulty d) => 'saved_game_${_version}_${d.name}';

  /// Does a saved game exist for this difficulty?
  static Future<bool> hasSaved(Difficulty d) async {
    final sp = await SharedPreferences.getInstance();
    return sp.containsKey(_key(d));
  }

  /// What difficulties currently have a saved game?
  static Future<List<Difficulty>> listSaved() async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys();
    return [
      for (final d in Difficulty.values)
        if (keys.contains(_key(d))) d,
    ];
  }

  /// Save snapshot (call after moves or on dispose).
  static Future<void> save(SudokuModel model, {int elapsedSeconds = 0}) async {
    final sp = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'elapsed': elapsedSeconds,
      'model': model.toMap(),
    };
    await sp.setString(_key(model.currentDifficulty), jsonEncode(data));
  }

  /// Load snapshot for a difficulty.
  static Future<LoadedGame?> load(Difficulty d) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(d));
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final model = SudokuModel.fromMap(
        Map<String, dynamic>.from(map['model'] as Map),
      );
      final elapsed = (map['elapsed'] as num?)?.toInt() ?? 0;
      return LoadedGame(model: model, elapsedSeconds: elapsed);
    } catch (_) {
      // Corrupt/old data — clear it so the app doesn't crash.
      await clear(d);
      return null;
    }
  }

  /// Clear a saved game for a given difficulty.
  static Future<void> clear(Difficulty d) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key(d));
  }

  /// Clear all saved games (all difficulties).
  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    for (final d in Difficulty.values) {
      await sp.remove(_key(d));
    }
  }
}

class LoadedGame {
  final SudokuModel model;
  final int elapsedSeconds;
  LoadedGame({required this.model, required this.elapsedSeconds});
}
