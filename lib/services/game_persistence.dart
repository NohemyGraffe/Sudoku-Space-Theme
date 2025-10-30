// lib/services/game_persistence.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/difficulty.dart';
import '../models/sudoku_board.dart';

class GamePersistence {
  static const _version = 'v1';
  static String _key(Difficulty d) => 'saved_game_${_version}_${d.name}';
  static const _totalPointsKey = 'total_points_$_version';

  // Live notifier for total points so UI can update in real time.
  static final ValueNotifier<int> totalPointsNotifier = ValueNotifier<int>(0);

  /// Initialize persistence layer (must be called before building UI).
  /// Loads the current total points into the live notifier.
  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    totalPointsNotifier.value = sp.getInt(_totalPointsKey) ?? 0;
  }

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
  static Future<void> save(
    SudokuModel model, {
    int elapsedSeconds = 0,
    int score = 0,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'elapsed': elapsedSeconds,
      'score': score,
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
      final score = (map['score'] as num?)?.toInt() ?? 0;
      return LoadedGame(model: model, elapsedSeconds: elapsed, score: score);
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

  // =====================
  // Total points (global)
  // =====================
  static Future<int> getTotalPoints() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_totalPointsKey) ?? 0;
  }

  static Future<void> addToTotal(int delta) async {
    if (delta <= 0) return; // only count gains
    final sp = await SharedPreferences.getInstance();
    final current = sp.getInt(_totalPointsKey) ?? totalPointsNotifier.value;
    final updated = current + delta;
    await sp.setInt(_totalPointsKey, updated);
    // Update live notifier so any listeners (e.g., Home) reflect immediately.
    totalPointsNotifier.value = updated;
  }

  /// Refresh the live notifier from storage (rarely needed if [init] is used).
  static Future<void> refreshTotalPoints() async {
    final sp = await SharedPreferences.getInstance();
    totalPointsNotifier.value = sp.getInt(_totalPointsKey) ?? 0;
  }
}

class LoadedGame {
  final SudokuModel model;
  final int elapsedSeconds;
  final int score;
  LoadedGame({
    required this.model,
    required this.elapsedSeconds,
    required this.score,
  });
}
