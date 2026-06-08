import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_progress.dart';

class ProgressStorage {
  static const _dateKey = 'progress.today.date';
  static const _completedIdsKey = 'progress.today.completed_ids';
  static const _historyKey = 'progress.history.v1';

  Future<String?> loadSavedDateKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dateKey);
  }

  Future<List<String>> loadCompletedHabitIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_completedIdsKey) ?? [];
  }

  Future<void> saveTodayProgress({
    required String dateKey,
    required List<String> completedHabitIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_dateKey, dateKey);
    await prefs.setStringList(_completedIdsKey, completedHabitIds);

    final history = await loadHistory();
    history[dateKey] = DailyProgress(
      dateKey: dateKey,
      completedHabitIds: List<String>.from(completedHabitIds),
    );

    await saveHistory(history);
  }

  Future<Map<String, DailyProgress>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_historyKey);

    if (rawJson == null || rawJson.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;

    return decoded.map((key, value) {
      return MapEntry(
        key,
        DailyProgress.fromJson(value as Map<String, dynamic>),
      );
    });
  }

  Future<void> saveHistory(Map<String, DailyProgress> history) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonMap = history.map((key, value) {
      return MapEntry(key, value.toJson());
    });

    await prefs.setString(_historyKey, jsonEncode(jsonMap));
  }

  Future<void> clearTodayProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dateKey);
    await prefs.remove(_completedIdsKey);
  }

  Future<void> clearAllProgressHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dateKey);
    await prefs.remove(_completedIdsKey);
    await prefs.remove(_historyKey);
  }
}