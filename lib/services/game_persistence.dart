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
  static const _lastPlayedKey = 'last_played_$_version';
  static const _resumeKey = 'resume_game_$_version';

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
    int mistakes = 0,
  }) async {
    final sp = await SharedPreferences.getInstance();
    // Preserve any existing 'lastLeft' timestamp so autosaves don't wipe it.
    int? lastLeft;
    try {
      final existingRaw = sp.getString(_key(model.currentDifficulty));
      if (existingRaw != null) {
        final existing = jsonDecode(existingRaw) as Map<String, dynamic>;
        lastLeft = (existing['lastLeft'] as num?)?.toInt();
      }
    } catch (_) {
      // ignore corrupt existing data; we'll overwrite
    }

    final data = <String, dynamic>{
      'elapsed': elapsedSeconds,
      'score': score,
      'mistakes': mistakes,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'lastLeft': lastLeft, // may be null; kept for accuracy
      'model': model.toMap(),
    };
    await sp.setString(_key(model.currentDifficulty), jsonEncode(data));
  }

  /// Mark a saved game as last-left/paused at the current (or provided) time.
  /// This updates only the 'lastLeft' timestamp without affecting other fields.
  static Future<void> updateLastLeft(Difficulty d, {int? timestampMs}) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(d));
    if (raw == null) return; // nothing to update
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map['lastLeft'] = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
      await sp.setString(_key(d), jsonEncode(map));
    } catch (_) {
      // ignore
    }
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
      final mistakes = (map['mistakes'] as num?)?.toInt() ?? 0;
      final lastLeft = (map['lastLeft'] as num?)?.toInt();
      return LoadedGame(
        model: model,
        elapsedSeconds: elapsed,
        score: score,
        mistakes: mistakes,
        lastLeftMs: lastLeft,
      );
    } catch (_) {
      // Corrupt/old data — clear it so the app doesn't crash.
      await clear(d);
      return null;
    }
  }

  /// Returns the most recently saved game across all difficulties.
  static Future<LastPlayed?> getLastSaved() async {
    final sp = await SharedPreferences.getInstance();
    int bestTs = -1;
    Difficulty? bestDiff;
    int bestElapsed = 0;
    for (final d in Difficulty.values) {
      final raw = sp.getString(_key(d));
      if (raw == null) continue;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        // Determine the most relevant timestamp: max(ts, lastLeft)
        final ts = (m['ts'] as num?)?.toInt() ?? 0;
        final lastLeft = (m['lastLeft'] as num?)?.toInt() ?? 0;
        final candTs = ts > lastLeft ? ts : lastLeft;
        if (candTs > bestTs) {
          bestTs = candTs;
          bestDiff = d;
          bestElapsed = (m['elapsed'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {
        // ignore bad entries
      }
    }
    if (bestDiff == null) return null;
    return LastPlayed(
      difficulty: bestDiff,
      elapsedSeconds: bestElapsed,
      timestampMs: bestTs >= 0 ? bestTs : null,
    );
  }

  /// Compute and store the most recent "started" game across all difficulties.
  ///
  /// This prefers the explicitly tracked last-opened game (user actually
  /// navigated into it). If that's not available, it falls back to the most
  /// recently saved snapshot across difficulties. The chosen result is then
  /// written into the last-opened metadata so other parts of the app can
  /// resolve it quickly.
  static Future<void> storeMostRecentStarted() async {
    // Prefer the last-opened record (reflects actual user navigation).
    final lastOpened = await getLastPlayed();
    if (lastOpened != null) {
      await setLastOpened(
        lastOpened.difficulty,
        elapsedSeconds: lastOpened.elapsedSeconds,
      );
      return;
    }

    // Fallback: derive from the most recent saved snapshot (max(ts, lastLeft)).
    final lastSaved = await getLastSaved();
    if (lastSaved != null) {
      await setLastOpened(
        lastSaved.difficulty,
        elapsedSeconds: lastSaved.elapsedSeconds,
      );
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
  // Global resume (single slot)
  // =====================
  /// Persist a global resume snapshot, overwriting any previous one.
  static Future<void> saveResume(
    SudokuModel model, {
    int elapsedSeconds = 0,
    int score = 0,
    int mistakes = 0,
    DateTime? lastSavedAt,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final nowIso = (lastSavedAt ?? DateTime.now()).toIso8601String();
    final data = <String, dynamic>{
      'difficulty': model.currentDifficulty.name,
      'elapsed': elapsedSeconds,
      'score': score,
      'mistakes': mistakes,
      'lastSavedAt': nowIso,
      'model': model.toMap(),
    };
    await sp.setString(_resumeKey, jsonEncode(data));
  }

  /// Load the global resume snapshot if present, else null.
  static Future<LoadedResume?> loadResume() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_resumeKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final diffName = map['difficulty'] as String?;
      final difficulty = diffName != null
          ? Difficulty.values.firstWhere(
              (d) => d.name == diffName,
              orElse: () => Difficulty.easy,
            )
          : Difficulty.easy;
      final model = SudokuModel.fromMap(
        Map<String, dynamic>.from(map['model'] as Map),
      );
      final elapsed = (map['elapsed'] as num?)?.toInt() ?? 0;
      final score = (map['score'] as num?)?.toInt() ?? 0;
      final mistakes = (map['mistakes'] as num?)?.toInt() ?? 0;
      final lastSavedAt = map['lastSavedAt'] as String?;
      return LoadedResume(
        model: model,
        elapsedSeconds: elapsed,
        score: score,
        mistakes: mistakes,
        difficulty: difficulty,
        lastSavedAtIso: lastSavedAt,
      );
    } catch (_) {
      await clearResume();
      return null;
    }
  }

  /// Remove the global resume snapshot.
  static Future<void> clearResume() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_resumeKey);
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

  // =====================
  // Last-opened game meta
  // =====================
  /// Explicitly mark a difficulty as the last opened game (e.g., when navigating).
  static Future<void> setLastOpened(
    Difficulty d, {
    int elapsedSeconds = 0,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _lastPlayedKey,
      jsonEncode({
        'difficulty': d.name,
        'elapsed': elapsedSeconds,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Return the most recently opened game.
  /// If nothing was stored yet, falls back to any existing saved difficulty.
  static Future<LastPlayed?> getLastPlayed() async {
    final sp = await SharedPreferences.getInstance();
    try {
      final raw = sp.getString(_lastPlayedKey);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final diffName = m['difficulty'] as String?;
        final elapsed = (m['elapsed'] as num?)?.toInt() ?? 0;
        final ts = (m['ts'] as num?)?.toInt();
        if (diffName != null) {
          final d = Difficulty.values.firstWhere(
            (e) => e.name == diffName,
            orElse: () => Difficulty.easy,
          );
          return LastPlayed(
            difficulty: d,
            elapsedSeconds: elapsed,
            timestampMs: ts,
          );
        }
      }
    } catch (_) {
      // ignore
    }
    // Fallback: pick any saved difficulty and derive elapsed
    final saved = await GamePersistence.listSaved();
    if (saved.isEmpty) return null;
    final d = saved.first;
    final loaded = await GamePersistence.load(d);
    final elapsed = loaded?.elapsedSeconds ?? 0;
    return LastPlayed(
      difficulty: d,
      elapsedSeconds: elapsed,
      timestampMs: null,
    );
  }
}

class LastPlayed {
  final Difficulty difficulty;
  final int elapsedSeconds;
  final int? timestampMs;
  LastPlayed({
    required this.difficulty,
    required this.elapsedSeconds,
    this.timestampMs,
  });
}

// (extension removed; functions are now static on GamePersistence)

class LoadedGame {
  final SudokuModel model;
  final int elapsedSeconds;
  final int score;
  final int mistakes;
  final int? lastLeftMs;
  LoadedGame({
    required this.model,
    required this.elapsedSeconds,
    required this.score,
    required this.mistakes,
    this.lastLeftMs,
  });
}

class LoadedResume {
  final SudokuModel model;
  final int elapsedSeconds;
  final int score;
  final int mistakes;
  final Difficulty difficulty;
  final String? lastSavedAtIso;
  LoadedResume({
    required this.model,
    required this.elapsedSeconds,
    required this.score,
    required this.mistakes,
    required this.difficulty,
    required this.lastSavedAtIso,
  });
}
