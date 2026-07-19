import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';

/// Persists the user's habit list to SharedPreferences.
///
/// Key: [_habitsKey]  — stored as a JSON-encoded array of Habit objects.
///
/// First-run detection:
///   [loadHabits] returns `null` when the key is absent (never been written).
///   It returns an empty list `[]` when the key exists but contains an empty
///   JSON array (e.g. after [clearHabits]).
///   HabitProvider (Task 3) uses this distinction to decide whether to seed
///   from [kDefaultCatholicHabitSet] (null → first run) or simply load what
///   is stored (empty list → user deliberately removed all habits).
class HabitStorage {
  static const _habitsKey = 'habits.list.v1';

  /// Loads the persisted habit list.
  ///
  /// Returns:
  ///   - `null`  → key not present; treat as first-run / no data yet.
  ///   - `[]`    → key present but the stored array is empty.
  ///   - `[...]` → one or more habits successfully deserialised.
  ///
  /// Malformed data: if the top-level JSON is not a List, or if any individual
  /// entry fails [Habit.fromJson], that entry is skipped and a debug message
  /// is printed. The remaining valid habits are still returned. This prevents
  /// a single corrupt record from crashing the app.
  Future<List<Habit>?> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_habitsKey);

    // Key absent — signal first run to HabitProvider.
    if (rawJson == null) return null;

    // Key present but empty string — treat as empty list.
    if (rawJson.isEmpty) return [];

    try {
      final decoded = jsonDecode(rawJson);

      if (decoded is! List) {
        // Top-level structure is wrong; return empty so the app doesn't crash.
        assert(false, 'HabitStorage: expected JSON array, got ${decoded.runtimeType}');
        return [];
      }

      final habits = <Habit>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          assert(false, 'HabitStorage: skipping non-object entry: $item');
          continue;
        }
        try {
          habits.add(Habit.fromJson(item));
        } on FormatException catch (e) {
          // Individual entry is malformed — skip it, log in debug.
          assert(false, 'HabitStorage: skipping malformed habit — $e');
        }
      }
      return habits;
    } catch (e) {
      // JSON decode itself failed — return empty rather than crashing.
      assert(false, 'HabitStorage: JSON decode error — $e');
      return [];
    }
  }

  /// Persists [habits] as a JSON array. Overwrites any previously saved list.
  Future<void> saveHabits(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(habits.map((h) => h.toJson()).toList());
    await prefs.setString(_habitsKey, encoded);
  }

  /// Removes the habits key entirely.
  ///
  /// After this call, [loadHabits] will return `null` again, which HabitProvider
  /// treats as first-run / seed from defaults. Use this when resetting the app,
  /// NOT simply to empty the list (for that, call [saveHabits] with `[]`).
  Future<void> clearHabits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_habitsKey);
  }
}
