import 'package:flutter/foundation.dart';

import '../models/daily_progress.dart';
import '../models/habit.dart';
import '../services/progress_storage.dart';

class ProgressProvider extends ChangeNotifier {
  ProgressProvider(this._storage);

  final ProgressStorage _storage;

  final List<Habit> habits = const [
    Habit(id: 'morning_prayer', title: 'Morning Prayer'),
    Habit(id: 'bible_reading', title: 'Bible Reading'),
    Habit(id: 'clean_eating', title: 'Clean Eating'),
    Habit(id: 'exercise_30', title: '30-Minute Exercise'),
    Habit(id: 'evening_reflection', title: 'Evening Reflection'),
  ];

  List<String> _completedHabitIds = [];
  Map<String, DailyProgress> _historyByDate = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<String> get completedHabitIds => List.unmodifiable(_completedHabitIds);
  Map<String, DailyProgress> get historyByDate =>
      Map.unmodifiable(_historyByDate);

  int get completedCount => _completedHabitIds.length;
  int get totalCount => habits.length;
  double get completionPercent =>
      habits.isEmpty ? 0 : completedCount / totalCount;

  int currentStreakForHabit(String habitId) {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final key = _dateKeyFor(date);
      final progress = _historyByDate[key];

      final completed = progress?.completedHabitIds.contains(habitId) ?? false;

      if (completed) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int longestStreakForHabit(String habitId) {
    final completedDates =
        _historyByDate.values
            .where((progress) => progress.completedHabitIds.contains(habitId))
            .map((progress) {
              final parts = progress.dateKey.split('-');
              return DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            })
            .toList()
          ..sort();

    if (completedDates.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < completedDates.length; i++) {
      final previous = completedDates[i - 1];
      final currentDate = completedDates[i];
      final difference = currentDate.difference(previous).inDays;

      if (difference == 1) {
        current++;
        if (current > longest) {
          longest = current;
        }
      } else if (difference > 1) {
        current = 1;
      }
    }

    return longest;
  }

  int currentStreakForHabits(List<String> habitIds) {
    if (habitIds.isEmpty) return 0;

    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final key = _dateKeyFor(date);
      final progress = _historyByDate[key];
      final completedIds = progress?.completedHabitIds ?? const <String>[];

      final completedAll = habitIds.every((id) => completedIds.contains(id));

      if (completedAll) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int longestStreakForHabits(List<String> habitIds) {
    if (habitIds.isEmpty) return 0;

    final completedDates =
        _historyByDate.values
            .where(
              (progress) => habitIds.every(
                (id) => progress.completedHabitIds.contains(id),
              ),
            )
            .map((progress) {
              final parts = progress.dateKey.split('-');
              return DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            })
            .toList()
          ..sort();

    if (completedDates.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < completedDates.length; i++) {
      final previous = completedDates[i - 1];
      final currentDate = completedDates[i];
      final difference = currentDate.difference(previous).inDays;

      if (difference == 1) {
        current++;
        if (current > longest) {
          longest = current;
        }
      } else if (difference > 1) {
        current = 1;
      }
    }

    return longest;
  }

  String get todayKey => _dateKeyFor(DateTime.now());
  DateTime _startOfWeekSunday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final daysFromSunday = date.weekday % 7;
    return normalized.subtract(Duration(days: daysFromSunday));
  }

  bool isHabitCompleted(String habitId) {
    return _completedHabitIds.contains(habitId);
  }

  List<bool> get thisWeekCompletion {
    final startOfWeek = _startOfWeekSunday(DateTime.now());

    return List.generate(7, (index) {
      final date = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day + index,
      );
      final key = _dateKeyFor(date);
      final progress = _historyByDate[key];
      return (progress?.completedHabitIds.length ?? 0) > 0;
    });
  }

  int get completedThisWeek {
    final startOfWeek = _startOfWeekSunday(DateTime.now());
    int total = 0;

    for (int i = 0; i < 7; i++) {
      final date = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day + i,
      );
      final key = _dateKeyFor(date);
      total += _historyByDate[key]?.completedHabitIds.length ?? 0;
    }

    return total;
  }

  int get totalThisWeek => habits.length * 7;

  double get weeklyCompletionPercent =>
      totalThisWeek == 0 ? 0 : completedThisWeek / totalThisWeek;

  int get currentStreak {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final key = _dateKeyFor(date);
      final progress = _historyByDate[key];

      if (progress != null && progress.completedHabitIds.isNotEmpty) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int get longestStreak {
    if (_historyByDate.isEmpty) return 0;

    final completedDates =
        _historyByDate.values
            .where((progress) => progress.completedHabitIds.isNotEmpty)
            .map((progress) {
              final parts = progress.dateKey.split('-');
              return DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            })
            .toList()
          ..sort();

    if (completedDates.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < completedDates.length; i++) {
      final previous = completedDates[i - 1];
      final currentDate = completedDates[i];
      final difference = currentDate.difference(previous).inDays;

      if (difference == 1) {
        current++;
        if (current > longest) {
          longest = current;
        }
      } else if (difference > 1) {
        current = 1;
      }
    }

    return longest;
  }

  Future<void> loadTodayProgress() async {
    final savedDate = await _storage.loadSavedDateKey();
    final savedIds = await _storage.loadCompletedHabitIds();
    _historyByDate = await _storage.loadHistory();

    final validHabitIds = habits.map((habit) => habit.id).toSet();

    _historyByDate = {
      for (final entry in _historyByDate.entries)
        entry.key: DailyProgress(
          dateKey: entry.value.dateKey,
          completedHabitIds: entry.value.completedHabitIds
              .where((id) => validHabitIds.contains(id))
              .toSet()
              .toList(),
        ),
    };

    if (savedDate == todayKey) {
      _completedHabitIds = savedIds
          .where((id) => validHabitIds.contains(id))
          .toSet()
          .toList();
    } else {
      _completedHabitIds = [];
    }

    _historyByDate[todayKey] = DailyProgress(
      dateKey: todayKey,
      completedHabitIds: List<String>.from(_completedHabitIds),
    );

    await _storage.saveTodayProgress(
      dateKey: todayKey,
      completedHabitIds: List<String>.from(_completedHabitIds),
    );

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> toggleHabit(String habitId) async {
    if (_completedHabitIds.contains(habitId)) {
      _completedHabitIds.remove(habitId);
    } else {
      _completedHabitIds.add(habitId);
    }

    _completedHabitIds = _completedHabitIds.toSet().toList();

    _historyByDate[todayKey] = DailyProgress(
      dateKey: todayKey,
      completedHabitIds: List<String>.from(_completedHabitIds),
    );

    await _storage.saveTodayProgress(
      dateKey: todayKey,
      completedHabitIds: List<String>.from(_completedHabitIds),
    );

    notifyListeners();
  }

  String _dateKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> clearAllProgress() async {
  _completedHabitIds = [];
  _historyByDate = {};
  await _storage.clearAllProgressHistory();

  _historyByDate[todayKey] = DailyProgress(
    dateKey: todayKey,
    completedHabitIds: [],
  );

  await _storage.saveTodayProgress(
    dateKey: todayKey,
    completedHabitIds: [],
  );

  notifyListeners();
}
}
